// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {EventToken} from "../src/EventToken.sol";

/**
 * @title EventTokenTest
 * @dev Production-ready test suite for EventToken contract
 * @dev Focuses on security, core functionality, and critical edge cases
 * @dev Organized for easy maintenance and human readability
 */
contract EventTokenTest is Test {
    EventToken public eventToken;

    // Test addresses
    address public organizer = address(0x123);
    address public user1 = address(0x456);
    address public user2 = address(0x789);
    address public owner = address(this);

    // Test parameters
    string public constant EVENT_NAME = "Test Concert";
    string public constant TOKEN_SYMBOL = "TEST";
    uint256 public eventDate;
    uint256 public vestingStartTime;

    // Token amounts
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10 ** 18; // 1B tokens
    uint256 public constant ORGANIZER_AMOUNT = (TOTAL_SUPPLY * 40) / 100; // 400M tokens
    uint256 public constant CONTRACT_AMOUNT = (TOTAL_SUPPLY * 60) / 100; // 600M tokens

    function setUp() public {
        eventDate = block.timestamp + 30 days; // Event in 30 days
        vestingStartTime = block.timestamp;

        eventToken = new EventToken(
            EVENT_NAME,
            TOKEN_SYMBOL,
            eventDate,
            organizer
        );
    }

    // ============ CONSTRUCTOR & VALIDATION TESTS ============
    // Tests: 3 | Purpose: Ensure contract deploys correctly with valid parameters

    function test_Constructor_ValidParameters() public view {
        assertEq(eventToken.eventName(), EVENT_NAME);
        assertEq(eventToken.symbol(), TOKEN_SYMBOL);
        assertEq(eventToken.eventDate(), eventDate);
        assertEq(eventToken.organizer(), organizer);
        assertEq(eventToken.owner(), owner);

        // Check token distribution
        assertEq(eventToken.balanceOf(organizer), ORGANIZER_AMOUNT);
        assertEq(eventToken.balanceOf(address(eventToken)), CONTRACT_AMOUNT);
        assertEq(eventToken.totalSupply(), TOTAL_SUPPLY);

        // Check vesting parameters
        assertEq(eventToken.vestingStartTime(), vestingStartTime);
        assertEq(eventToken.organizerBalance(), ORGANIZER_AMOUNT);
    }

    function test_Constructor_InvalidEventDate() public {
        uint256 pastDate = 1; // Use a fixed past timestamp to avoid underflow
        vm.expectRevert("Event date must be in the future");
        new EventToken(EVENT_NAME, TOKEN_SYMBOL, pastDate, organizer);
    }

    function test_Constructor_InvalidOrganizer() public {
        vm.expectRevert("Invalid organizer address");
        new EventToken(EVENT_NAME, TOKEN_SYMBOL, eventDate, address(0));
    }

    // ============ VESTING CORE FUNCTIONALITY TESTS ============
    // Tests: 3 | Purpose: Verify vesting calculation formula works correctly

    function test_VestingCalculation_AtStart() public view {
        uint256 transferable = eventToken.organizerTransferableAmount();
        assertEq(transferable, 0, "Should start with 0 transferable tokens");
    }

    function test_VestingCalculation_AtEventDate() public {
        vm.warp(eventDate);
        uint256 transferable = eventToken.organizerTransferableAmount();
        assertEq(
            transferable,
            ORGANIZER_AMOUNT,
            "Should have all tokens at event date"
        );
    }

    function test_VestingCalculation_Formula() public {
        // Test vesting formula at 50% of period
        vm.warp(block.timestamp + 15 days);
        uint256 transferable = eventToken.organizerTransferableAmount();
        uint256 expected = (ORGANIZER_AMOUNT * 50) / 100;

        assertApproxEqRel(
            transferable,
            expected,
            0.01e18,
            "Should have ~50% tokens"
        );
    }

    // ============ SECURITY: TRANSFER RESTRICTIONS TESTS ============
    // Tests: 4 | Purpose: Ensure organizer cannot bypass vesting limits

    function test_Transfer_OrganizerCannotTransferMoreThanVested() public {
        vm.warp(block.timestamp + 7.5 days); // 25% of vesting
        uint256 transferable = eventToken.organizerTransferableAmount();
        uint256 tooMuch = transferable + 1 ether;

        vm.expectRevert();
        vm.prank(organizer);
        eventToken.transfer(user1, tooMuch);
    }

    function test_Transfer_OrganizerCanTransferExactVestedAmount() public {
        vm.warp(block.timestamp + 7.5 days);
        uint256 transferable = eventToken.organizerTransferableAmount();

        vm.prank(organizer);
        bool success = eventToken.transfer(user1, transferable);

        assertTrue(success, "Transfer should succeed");
        assertEq(
            eventToken.balanceOf(user1),
            transferable,
            "User1 should receive tokens"
        );
    }

    function test_TransferFrom_OrganizerCannotTransferFromMoreThanVested()
        public
    {
        vm.warp(block.timestamp + 7.5 days);
        uint256 transferable = eventToken.organizerTransferableAmount();

        // First approve the exact amount
        vm.prank(organizer);
        eventToken.approve(user1, transferable);

        // This should succeed
        vm.prank(user1);
        bool success = eventToken.transferFrom(organizer, user2, transferable);
        assertTrue(success, "Transfer of exact amount should succeed");

        // Now try to transfer more (should fail)
        vm.expectRevert();
        vm.prank(user1);
        eventToken.transferFrom(organizer, user2, 1 ether); // Try to transfer 1 more token
    }

    function test_TransferFrom_OrganizerCanTransferFromExactVestedAmount()
        public
    {
        vm.warp(block.timestamp + 7.5 days);
        uint256 transferable = eventToken.organizerTransferableAmount();

        vm.prank(organizer);
        eventToken.approve(user1, transferable);

        vm.prank(user1);
        bool success = eventToken.transferFrom(organizer, user2, transferable);

        assertTrue(success, "TransferFrom should succeed");
        assertEq(
            eventToken.balanceOf(user2),
            transferable,
            "User2 should receive tokens"
        );
    }

    // ============ SECURITY: APPROVAL RESTRICTIONS TESTS ============
    // Tests: 3 | Purpose: Ensure organizer cannot approve more than vested

    function test_Approve_OrganizerCannotApproveMoreThanVested() public {
        vm.warp(block.timestamp + 7.5 days);
        uint256 transferable = eventToken.organizerTransferableAmount();
        uint256 tooMuch = transferable + 1 ether;

        vm.expectRevert();
        vm.prank(organizer);
        eventToken.approve(user1, tooMuch);
    }

    function test_Approve_OrganizerCanApproveExactVestedAmount() public {
        vm.warp(block.timestamp + 7.5 days);
        uint256 transferable = eventToken.organizerTransferableAmount();

        vm.prank(organizer);
        bool success = eventToken.approve(user1, transferable);

        assertTrue(success, "Approve should succeed");
        assertEq(
            eventToken.allowance(organizer, user1),
            transferable,
            "Allowance should be set"
        );
    }

    function test_Approve_NonOrganizerCanApproveNormally() public {
        vm.prank(user1);
        bool success = eventToken.approve(user2, 1000 * 10 ** 18);

        assertTrue(success, "Non-organizer approve should succeed");
        assertEq(
            eventToken.allowance(user1, user2),
            1000 * 10 ** 18,
            "Allowance should be set"
        );
    }

    // ============ ERC20 STANDARD FUNCTIONALITY TESTS ============
    // Tests: 2 | Purpose: Verify ERC20 inheritance and standard functions

    function test_ERC20StandardFunctions() public view {
        assertEq(eventToken.name(), EVENT_NAME, "Name should match");
        assertEq(eventToken.symbol(), TOKEN_SYMBOL, "Symbol should match");
        assertEq(eventToken.decimals(), 18, "Decimals should be 18");
    }

    function test_Transfer_NonOrganizerCanTransferNormally() public {
        // Give tokens to user1 from contract (which has tokens)
        uint256 testAmount = 1000 * 10 ** 18;
        vm.prank(address(eventToken));
        eventToken.transfer(user1, testAmount);

        // User1 can transfer normally
        vm.prank(user1);
        bool success = eventToken.transfer(user2, testAmount / 2);

        assertTrue(success, "Non-organizer transfer should succeed");
        assertEq(
            eventToken.balanceOf(user2),
            testAmount / 2,
            "User2 should receive tokens"
        );
    }

    // ============ VESTING INFORMATION TESTS ============
    // Tests: 2 | Purpose: Verify vesting info and progress functions

    function test_GetVestingInfo() public view {
        (
            uint256 startTime,
            uint256 endTime,
            uint256 totalAmount,
            uint256 transferable,
            uint256 remaining
        ) = eventToken.getVestingInfo();

        assertEq(startTime, vestingStartTime, "Start time should match");
        assertEq(endTime, eventDate, "End time should match");
        assertEq(totalAmount, ORGANIZER_AMOUNT, "Total amount should match");
        assertEq(transferable, 0, "Transferable should be 0 at start");
        assertEq(
            remaining,
            ORGANIZER_AMOUNT,
            "Remaining should be total at start"
        );
    }

    function test_GetVestingProgress() public {
        vm.warp(block.timestamp + 15 days); // 50% of vesting
        uint256 progress = eventToken.getVestingProgress();
        assertApproxEqRel(progress, 50, 0.01e18, "Progress should be ~50%");
    }

    // ============ SETHOOK SECURITY TESTS ============
    // Tests: 4 | Purpose: Ensure setHook function is secure and works correctly

    function test_SetHook_OnlyOwner() public {
        address hookAddress = address(0x999);

        // Organizer should not be able to call setHook
        vm.expectRevert();
        vm.prank(organizer);
        eventToken.setHook(hookAddress);

        // Owner should be able to call setHook
        eventToken.setHook(hookAddress);
        assertEq(eventToken.eventHook(), hookAddress, "Hook should be set");
    }

    function test_SetHook_TransferTokens() public {
        address hookAddress = address(0x999);
        uint256 initialContractBalance = eventToken.balanceOf(
            address(eventToken)
        );

        eventToken.setHook(hookAddress);

        // Verify hook received tokens
        uint256 hookBalance = eventToken.balanceOf(hookAddress);
        assertEq(
            hookBalance,
            initialContractBalance,
            "Hook should receive all tokens"
        );

        // Verify contract has no tokens left
        uint256 contractBalance = eventToken.balanceOf(address(eventToken));
        assertEq(contractBalance, 0, "Contract should have no tokens left");
    }

    function test_SetHook_AlreadySet() public {
        address hookAddress1 = address(0x999);
        address hookAddress2 = address(0x888);

        eventToken.setHook(hookAddress1);
        assertEq(
            eventToken.eventHook(),
            hookAddress1,
            "First hook should be set"
        );

        // Try to set hook again - should fail
        vm.expectRevert("Hook already set");
        eventToken.setHook(hookAddress2);
    }

    function test_SetHook_InvalidAddress() public {
        vm.expectRevert("Invalid hook address");
        eventToken.setHook(address(0));
    }

    // ============ INTEGRATION & EDGE CASES TESTS ============
    // Tests: 2 | Purpose: Verify complete functionality and handle edge cases

    function test_Integration_BasicVestingCycle() public {
        // 1. Start: 0 tokens available
        assertEq(
            eventToken.organizerTransferableAmount(),
            0,
            "Should start with 0 tokens"
        );

        // 2. 25% through: Transfer some tokens
        vm.warp(block.timestamp + 7.5 days);
        uint256 transferable25 = eventToken.organizerTransferableAmount();
        uint256 transferAmount25 = transferable25 / 2;

        vm.prank(organizer);
        eventToken.transfer(user1, transferAmount25);

        assertEq(
            eventToken.balanceOf(user1),
            transferAmount25,
            "User1 should receive tokens"
        );
        assertEq(
            eventToken.organizerBalance(),
            ORGANIZER_AMOUNT - transferAmount25,
            "Organizer balance should decrease"
        );

        // 3. Event date: All remaining tokens available
        vm.warp(eventDate);
        uint256 transferable100 = eventToken.organizerTransferableAmount();
        assertEq(
            transferable100,
            eventToken.organizerBalance(),
            "All remaining tokens should be available"
        );
    }

    function test_EdgeCase_ShortVestingPeriod() public {
        // Create token with short vesting (1 day)
        uint256 shortEventDate = block.timestamp + 1 days;
        EventToken shortToken = new EventToken(
            "Short Event",
            "SHORT",
            shortEventDate,
            organizer
        );

        // Move to 50% of vesting period (12 hours)
        vm.warp(block.timestamp + 12 hours);

        uint256 transferable = shortToken.organizerTransferableAmount();
        uint256 expected = (ORGANIZER_AMOUNT * 50) / 100;

        assertApproxEqRel(
            transferable,
            expected,
            0.01e18,
            "Short vesting should work correctly"
        );
    }
}
