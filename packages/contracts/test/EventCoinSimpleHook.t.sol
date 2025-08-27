// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// ============================================================================
// FOUNDRY TEST FRAMEWORK
// ============================================================================
import "forge-std/Test.sol";
import "forge-std/console.sol";

// ============================================================================
// CONTRACT UNDER TEST
// ============================================================================
import {EventCoinSimpleHook} from "../src/EventCoinSimpleHook.sol";
import {EventToken} from "../src/EventToken.sol";

// ============================================================================
// MOCK CONTRACTS
// ============================================================================
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

// ============================================================================
// UNISWAP V4 IMPORTS
// ============================================================================
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {LiquidityAmounts} from "v4-periphery/src/libraries/LiquidityAmounts.sol";
import {FullMath} from "v4-core/libraries/FullMath.sol";

// ============================================================================
// UNISWAP V4 TEST UTILITIES
// ============================================================================
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";

// ============================================================================
// CUSTOM TEST UTILITIES
// ============================================================================
import {EventCoinHookTestUtils} from "./utils/EventCoinHookTestUtils.sol";

/**
 * @title EventCoinSimpleHookTest
 * @notice Comprehensive test suite for EventCoinSimpleHook
 * @dev Tests focus on liquidity bootstrapping functionality with generic backing asset support
 *
 * ## Test Categories
 * - ✅ Error cases and access control
 * - ✅ Generic backing asset support (different decimals)
 * - ✅ Complete end-to-end integration flow
 * - ✅ Edge cases and fallback mechanisms
 *
 * ## Test Philosophy
 * - Each test is self-contained and well-documented
 * - Comprehensive logging for debugging and understanding
 * - Both positive and negative test cases
 * - Real-world scenario simulation
 *
 * @author UniFans Protocol Team
 * @custom:version 2.0.0 - Generic backing asset support
 */
contract EventCoinSimpleHookTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;
    using EventCoinHookTestUtils for *;

    // ============================================================================
    // TEST CONTRACT INSTANCES
    // ============================================================================

    EventCoinSimpleHook hook;
    EventToken eventToken;
    MockERC20 backingAsset;

    // ============================================================================
    // TEST CONSTANTS
    // ============================================================================

    /// @notice Event details for testing
    string constant EVENT_NAME = "Rock Festival 2025";
    string constant TOKEN_SYMBOL = "ROCK25";
    uint256 constant EVENT_DATE = 1735689600; // Future timestamp

    /// @notice Test addresses and amounts
    address constant ORGANIZER = address(0x1234);
    uint256 constant BACKING_AMOUNT = 10_000; // 10,000 units (before decimals)
    uint256 constant TOKEN_AMOUNT = 600_000_000 ether; // 600M tokens (18 decimals)

    /// @notice Pool configuration
    PoolKey poolKey;
    PoolId poolId;

    // ============================================================================
    // TEST SETUP
    // ============================================================================

    /**
     * @notice Set up test environment with Uniswap V4 infrastructure and contracts
     * @dev Creates a complete testing environment with:
     *      - Uniswap V4 PoolManager and routers
     *      - MockERC20 backing asset (USDC-like, 6 decimals)
     *      - EventToken with organizer configuration
     *      - EventCoinSimpleHook with proper permissions
     *      - Pool key with correct currency ordering
     */
    function setUp() public {
        // Deploy Uniswap V4 infrastructure
        deployFreshManagerAndRouters();

        // Deploy backing asset (USDC mock with 6 decimals)
        backingAsset = new MockERC20("USD Coin", "USDC", 6);

        // Deploy EventToken with organizer configuration
        eventToken = new EventToken(
            EVENT_NAME,
            TOKEN_SYMBOL,
            EVENT_DATE,
            ORGANIZER
        );

        // Deploy EventCoinSimpleHook using deployCodeTo for proper address flags
        uint160 flags = uint160(Hooks.AFTER_INITIALIZE_FLAG);
        address hookAddress = address(uint160(flags));
        deployCodeTo(
            "EventCoinSimpleHook.sol:EventCoinSimpleHook",
            abi.encode(
                address(manager),
                ORGANIZER,
                address(eventToken),
                address(backingAsset)
            ),
            hookAddress
        );
        hook = EventCoinSimpleHook(hookAddress);

        // Setup pool key with proper currency ordering (Uniswap V4 requirement)
        (Currency currency0, Currency currency1) = address(backingAsset) <
            address(eventToken)
            ? (
                Currency.wrap(address(backingAsset)),
                Currency.wrap(address(eventToken))
            )
            : (
                Currency.wrap(address(eventToken)),
                Currency.wrap(address(backingAsset))
            );

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000, // 0.3% fee tier
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        poolId = poolKey.toId();

        // Provide organizer with backing asset for testing
        backingAsset.mint(ORGANIZER, backingAmount());

        _logSetup();
    }

    // ============================================================================
    // ERROR CASES AND ACCESS CONTROL TESTS
    // ============================================================================

    /**
     * @notice Test that double deposit is properly prevented
     * @dev Verifies the BackingAssetAlreadyDeposited error is thrown on second deposit
     */
    function test_RevertWhen_DepositTwice() public {
        console.log("\n=== Test: Deposit Twice Prevention ===");

        vm.startPrank(ORGANIZER);
        backingAsset.approve(address(hook), backingAmount() * 2);

        // First deposit should succeed
        hook.depositBackingAsset(backingAmount());
        assertEq(hook.initialBackingAmount(), backingAmount());
        assertTrue(hook.backingAssetDeposited());
        uint256 balHookAfter1 = backingAsset.balanceOf(address(hook));

        // Second deposit should revert with specific error
        vm.expectRevert(
            EventCoinSimpleHook.BackingAssetAlreadyDeposited.selector
        );
        hook.depositBackingAsset(1);

        // Verify state is unchanged after revert
        assertEq(backingAsset.balanceOf(address(hook)), balHookAfter1);
        assertEq(hook.initialBackingAmount(), backingAmount());
        assertTrue(hook.backingAssetDeposited());

        vm.stopPrank();

        console.log("Correctly prevents double deposit");
    }

    /**
     * @notice Test that manual bootstrap twice is properly prevented
     * @dev Verifies that manual bootstrap fails when liquidity already exists
     */
    function test_RevertWhen_ManualBootstrapTwice() public {
        console.log("\n=== Test: Manual Bootstrap Twice Prevention ===");

        // Setup: deposit backing asset and initialize pool (auto bootstrap)
        eventToken.setHook(address(hook));
        vm.startPrank(ORGANIZER);
        backingAsset.approve(address(hook), backingAmount());
        hook.depositBackingAsset(backingAmount());
        vm.stopPrank();

        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(0);
        manager.initialize(poolKey, sqrtPriceX96);

        // Verify auto bootstrap worked
        uint128 liq = manager.getLiquidity(poolId);
        assertGt(liq, 0, "Expected liquidity after auto bootstrap");

        // Manual bootstrap should fail
        vm.startPrank(ORGANIZER);
        vm.expectRevert("Liquidity already bootstrapped");
        hook.bootstrapInitialLiquidity(poolKey);
        vm.stopPrank();

        console.log("Correctly prevents double bootstrap");
    }

    /**
     * @notice Test that only organizer can deposit backing asset
     * @dev Verifies OnlyOrganizer error for unauthorized callers
     */
    function test_RevertWhen_DepositByNonOrganizer() public {
        address notOrganizer = address(0xBEEF);
        vm.startPrank(notOrganizer);
        vm.expectRevert(EventCoinSimpleHook.OnlyOrganizer.selector);
        hook.depositBackingAsset(1);
        vm.stopPrank();
    }

    /**
     * @notice Test that zero amount deposits are rejected
     * @dev Verifies ZeroAmounts error for zero deposit attempts
     */
    function test_RevertWhen_DepositZero() public {
        vm.startPrank(ORGANIZER);
        vm.expectRevert(EventCoinSimpleHook.ZeroAmounts.selector);
        hook.depositBackingAsset(0);
        vm.stopPrank();
    }

    /**
     * @notice Test that automatic bootstrap doesn't occur without backing asset
     * @dev Verifies no liquidity is added when backing asset isn't deposited
     */
    function test_NoAutoBootstrap_WithoutBacking() public {
        _initAtDesiredPrice();
        uint128 liq = manager.getLiquidity(poolId);
        assertEq(liq, 0, "No liquidity should exist without backing asset");
    }

    /**
     * @notice Test that manual bootstrap fails without backing asset deposit
     * @dev Verifies NoBackingAssetDeposited error for manual bootstrap without deposit
     */
    function test_Revert_ManualBootstrap_NoBacking() public {
        eventToken.setHook(address(hook));
        vm.startPrank(ORGANIZER);
        vm.expectRevert(EventCoinSimpleHook.NoBackingAssetDeposited.selector);
        hook.bootstrapInitialLiquidity(poolKey);
        vm.stopPrank();
    }

    /**
     * @notice Test that backing asset deposit emits correct events
     * @dev Verifies both ERC20 Transfer and BackingAssetDeposited events
     */
    function test_Emits_BackingAssetDeposited() public {
        vm.startPrank(ORGANIZER);

        backingAsset.approve(address(hook), backingAmount());

        // Expect ERC20 Transfer event
        vm.expectEmit(true, true, false, true, address(backingAsset));
        emit Transfer(ORGANIZER, address(hook), backingAmount());

        // Expect BackingAssetDeposited event
        vm.expectEmit(true, false, false, true, address(hook));
        emit EventCoinSimpleHook.BackingAssetDeposited(
            ORGANIZER,
            backingAmount()
        );

        hook.depositBackingAsset(backingAmount());

        vm.stopPrank();
    }

    // ============================================================================
    // GENERIC BACKING ASSET TESTS (DIFFERENT DECIMALS)
    // ============================================================================

    /**
     * @notice Test hook functionality with 18 decimal backing asset
     * @dev Verifies hook works with high-decimal tokens like ETH
     */
    function test_Decimals_18() public {
        _runScenarioWithDecimals(18);
    }

    /**
     * @notice Test hook functionality with 6 decimal backing asset
     * @dev Verifies hook works with standard stablecoin decimals like USDC
     */
    function test_Decimals_6() public {
        _runScenarioWithDecimals(6);
    }

    /**
     * @notice Test hook functionality with 8 decimal backing asset
     * @dev Verifies hook works with Bitcoin-like decimal precision
     */
    function test_Decimals_8() public {
        _runScenarioWithDecimals(8);
    }

    /**
     * @notice Test hook functionality with 0 decimal backing asset
     * @dev Verifies hook works with integer-only tokens (edge case)
     */
    function test_Decimals_0() public {
        _runScenarioWithDecimals(0);
    }

    /**
     * @notice Internal helper to test hook with different backing asset decimals
     * @dev Creates a complete scenario with custom decimal backing asset
     * @param decimals Number of decimals for the backing asset (0-24)
     */
    function _runScenarioWithDecimals(uint8 decimals) internal {
        // Bound decimals to reasonable range
        decimals = uint8(bound(decimals, 0, 24));

        // Deploy custom backing asset with specified decimals
        MockERC20 customBacking = new MockERC20("CUSTOM", "CUSTOM", decimals);

        // Deploy hook with custom backing asset
        uint160 flags = uint160(Hooks.AFTER_INITIALIZE_FLAG);
        address hookAddress = address(uint160(flags));
        deployCodeTo(
            "EventCoinSimpleHook.sol:EventCoinSimpleHook",
            abi.encode(
                address(manager),
                ORGANIZER,
                address(eventToken),
                address(customBacking)
            ),
            hookAddress
        );
        EventCoinSimpleHook customHook = EventCoinSimpleHook(hookAddress);

        // Setup pool key with proper currency ordering
        (Currency c0, Currency c1) = address(customBacking) <
            address(eventToken)
            ? (
                Currency.wrap(address(customBacking)),
                Currency.wrap(address(eventToken))
            )
            : (
                Currency.wrap(address(eventToken)),
                Currency.wrap(address(customBacking))
            );

        PoolKey memory customKey = PoolKey({
            currency0: c0,
            currency1: c1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(customHook))
        });

        // Calculate amounts based on decimals
        uint256 unit = 10 ** decimals;
        uint256 customBackingAmount = BACKING_AMOUNT * unit;

        // Setup test scenario
        customBacking.mint(ORGANIZER, customBackingAmount);

        vm.startPrank(ORGANIZER);
        customBacking.approve(address(customHook), customBackingAmount);
        customHook.depositBackingAsset(customBackingAmount);
        vm.stopPrank();

        eventToken.setHook(address(customHook));
        assertEq(eventToken.balanceOf(address(customHook)), TOKEN_AMOUNT);

        // Calculate price based on currency order
        address addr0 = Currency.unwrap(c0);
        address addr1 = Currency.unwrap(c1);
        uint256 amount0Raw = addr0 == address(customBacking)
            ? customBackingAmount
            : TOKEN_AMOUNT;
        uint256 amount1Raw = addr1 == address(customBacking)
            ? customBackingAmount
            : TOKEN_AMOUNT;

        uint160 sqrtPrice = EventCoinHookTestUtils.priceToSqrtPriceX96_RAW(
            amount1Raw,
            amount0Raw
        );
        manager.initialize(customKey, sqrtPrice);

        // Verify bootstrap success
        uint128 liquidity = manager.getLiquidity(customKey.toId());
        assertGt(liquidity, 0, "Liquidity should exist after bootstrap");

        uint256 spentBacking = customBackingAmount -
            customBacking.balanceOf(address(customHook));
        uint256 spentEvent = TOKEN_AMOUNT -
            eventToken.balanceOf(address(customHook));

        assertGt(spentBacking, 0, "Backing asset should be consumed");
        assertGt(spentEvent, 0, "Event tokens should be consumed");
    }

    // ============================================================================
    // INTEGRATION TEST - COMPLETE END-TO-END FLOW
    // ============================================================================

    /**
     * @notice Comprehensive end-to-end test of the complete hook functionality
     * @dev Tests the full organizer journey from deployment to active trading pool
     *
     * ## Test Flow
     * 1. Initial state verification
     * 2. Event token transfer to hook
     * 3. Organizer backing asset deposit
     * 4. Pool initialization (triggers automatic bootstrap)
     * 5. Final state verification and assertions
     *
     * ## Logging
     * Comprehensive logging at each step for debugging and understanding
     */
    function test_CompleteFlowEndToEnd() public {
        console.log("=== COMPLETE FLOW END-TO-END TEST ===");
        console.log("");

        // Log initial state
        _logFundingState("FUNDING & APPROVALS - BEFORE");

        // Step 1: Transfer event tokens to hook (simulates EventToken.setHook())
        eventToken.setHook(address(hook));
        assertEq(eventToken.balanceOf(address(hook)), TOKEN_AMOUNT);

        // Step 2: Organizer deposits backing asset
        vm.startPrank(ORGANIZER);
        backingAsset.approve(address(hook), backingAmount());
        hook.depositBackingAsset(backingAmount());
        vm.stopPrank();
        assertEq(backingAsset.balanceOf(address(hook)), backingAmount());

        // Log state after funding
        _logFundingState("FUNDING & APPROVALS - AFTER");
        console.log("--------------------------------------------");
        console.log("");

        // Step 3: Initialize pool (triggers automatic bootstrap)
        _initAtDesiredPrice();

        // Step 4: Verify final state
        uint128 finalLiquidity = manager.getLiquidity(poolId);
        assertTrue(
            finalLiquidity > 0,
            "Pool must have liquidity after bootstrap"
        );

        // Calculate consumed amounts
        uint256 hookTokensAfter = eventToken.balanceOf(address(hook));
        uint256 hookUsdcAfter = backingAsset.balanceOf(address(hook));

        // Log bootstrap results
        _logBootstrapResults(finalLiquidity, hookUsdcAfter, hookTokensAfter);
        console.log("--------------------------------------------");
        console.log("");

        // Log final balances
        _logFinalBalances(hookUsdcAfter, hookTokensAfter);

        // Verify significant amounts were consumed for liquidity
        assertLt(hookTokensAfter, TOKEN_AMOUNT, "Should consume some tokens");
        assertLt(hookUsdcAfter, backingAmount(), "Should consume some USDC");

        // Verify exact amounts consumed
        uint256 usdcSpent = backingAmount() - hookUsdcAfter;
        uint256 evtSpent = TOKEN_AMOUNT - hookTokensAfter;

        console.log("USDC spent:", usdcSpent / backingUnit());
        EventCoinHookTestUtils.log18("ROCK25 spent:", evtSpent);

        // Verify USDC consumption is approximately complete
        assertApproxEqAbs(
            usdcSpent,
            backingAmount(),
            1,
            "USDC mismatch (end-to-end)"
        );
    }

    // ============================================================================
    // INTERNAL HELPER FUNCTIONS
    // ============================================================================

    /**
     * @notice Initialize pool at desired price for testing
     * @dev Calculates optimal price based on backing asset and event token amounts
     *      and initializes the pool with that price
     */
    function _initAtDesiredPrice() internal {
        address c0 = Currency.unwrap(poolKey.currency0);
        address c1 = Currency.unwrap(poolKey.currency1);

        uint256 amount0Raw;
        uint256 amount1Raw;

        // Determine amounts based on currency order
        if (c0 == address(backingAsset) && c1 == address(eventToken)) {
            // currency0 = USDC, currency1 = EVENT
            amount0Raw = backingAmount();
            amount1Raw = TOKEN_AMOUNT;
        } else if (c0 == address(eventToken) && c1 == address(backingAsset)) {
            // currency0 = EVENT, currency1 = USDC
            amount0Raw = TOKEN_AMOUNT;
            amount1Raw = backingAmount();
        } else {
            revert("Pool must contain backing & event");
        }

        // Calculate optimal price for liquidity
        uint160 sqrtPriceX96 = EventCoinHookTestUtils.priceToSqrtPriceX96_RAW(
            amount1Raw,
            amount0Raw
        );

        // Log pool initialization details
        _logPoolInitialization(amount0Raw, amount1Raw, sqrtPriceX96);

        // Initialize pool with calculated price
        manager.initialize(poolKey, sqrtPriceX96);
    }

    /**
     * @notice Log comprehensive setup information
     * @dev Provides detailed information about deployed contracts and pool configuration
     */
    function _logSetup() internal view {
        console.log("=== SETUP ===");
        console.log("PoolManager:                ", address(manager));
        console.log("BackingAsset (USDC):        ", address(backingAsset));
        console.log("EventToken (ROCK25):        ", address(eventToken));
        console.log("Hook:                       ", address(hook));
        console.log("");

        console.log("=== POOL KEY ===");
        string memory c0Type = Currency.unwrap(poolKey.currency0) ==
            address(backingAsset)
            ? "(USDC, 6d)"
            : "(ROCK25, 18d)";
        string memory c1Type = Currency.unwrap(poolKey.currency1) ==
            address(backingAsset)
            ? "(USDC, 6d)"
            : "(ROCK25, 18d)";
        console.log(
            "currency0:                  ",
            Currency.unwrap(poolKey.currency0),
            c0Type
        );
        console.log(
            "currency1:                  ",
            Currency.unwrap(poolKey.currency1),
            c1Type
        );
        console.log("fee:                        ", poolKey.fee);
        console.log(
            "tickSpacing:                ",
            uint256(uint24(poolKey.tickSpacing))
        );
        console.log("");

        console.log("=== INITIAL BALANCES ===");
        console.log(
            "Organizer USDC:             ",
            backingAsset.balanceOf(ORGANIZER) / backingUnit(),
            "USDC"
        );
        console.log(
            "Organizer ROCK25:            ",
            eventToken.balanceOf(ORGANIZER) / 1e18,
            "tokens"
        );
        console.log(
            "Hook USDC:                  ",
            backingAsset.balanceOf(address(hook)) / backingUnit(),
            "USDC"
        );
        console.log(
            "Hook ROCK25:                 ",
            eventToken.balanceOf(address(hook)) / 1e18,
            "tokens (locked in EventToken contract)"
        );
        console.log("");
        console.log("--------------------------------------------");
        console.log("");
    }

    /**
     * @notice Log funding state at different stages
     * @param stage Description of the current funding stage
     */
    function _logFundingState(string memory stage) internal view {
        console.log("=== ", stage, " ===");
        console.log(
            "Organizer USDC:             ",
            backingAsset.balanceOf(ORGANIZER) / backingUnit(),
            "USDC"
        );
        console.log(
            "Organizer ROCK25:            ",
            eventToken.balanceOf(ORGANIZER) / 1e18,
            "tokens"
        );
        console.log(
            "Hook USDC:                  ",
            backingAsset.balanceOf(address(hook)) / backingUnit(),
            "USDC"
        );
        console.log(
            "Hook ROCK25:                 ",
            eventToken.balanceOf(address(hook)) / 1e18,
            "tokens"
        );
        console.log("");
    }

    /**
     * @notice Log pool initialization details
     * @param amount0Raw Raw amount for currency0
     * @param amount1Raw Raw amount for currency1
     * @param sqrtPriceX96 Square root price in X96 format
     */
    function _logPoolInitialization(
        uint256 amount0Raw,
        uint256 amount1Raw,
        uint160 sqrtPriceX96
    ) internal view {
        console.log("=== POOL INIT ===");
        console.log("amount0Raw:                 ", amount0Raw, "(USDC, 6d)");
        console.log(
            "amount1Raw:                 ",
            amount1Raw,
            "(ROCK25, 18d)"
        );
        console.log("sqrtPriceX96:               ", sqrtPriceX96);

        uint8 dBacking = backingAsset.decimals();
        uint8 dEvent = eventToken.decimals();

        uint256 priceRaw = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) >>
            192;
        console.log("price RAW (t1/t0):          ", priceRaw);

        uint256 humanPrice;
        if (dEvent >= dBacking) {
            humanPrice = priceRaw / (10 ** (dEvent - dBacking));
        } else {
            humanPrice = priceRaw * (10 ** (dBacking - dEvent));
        }
        console.log(
            "price HUMAN (t1/t0):        ",
            humanPrice,
            "ROCK25 per 1 USDC"
        );

        console.log("");
        console.log("--------------------------------------------");
        console.log("");
    }

    /**
     * @notice Log bootstrap results and consumption amounts
     * @param finalLiquidity Final liquidity in the pool
     * @param hookUsdcAfter USDC remaining in hook after bootstrap
     * @param hookTokensAfter Event tokens remaining in hook after bootstrap
     */
    function _logBootstrapResults(
        uint128 finalLiquidity,
        uint256 hookUsdcAfter,
        uint256 hookTokensAfter
    ) internal view {
        console.log("=== BOOTSTRAP RESULTS ===");
        console.log("Pool liquidity:             ", finalLiquidity);
        console.log(
            "USDC consumed:              ",
            (backingAmount() - hookUsdcAfter) / backingUnit()
        );
        console.log(
            "ROCK25 consumed:             ",
            (TOKEN_AMOUNT - hookTokensAfter) / 1e18
        );
        console.log(
            "Hook USDC remaining:        ",
            hookUsdcAfter / backingUnit()
        );
        console.log("Hook ROCK25 remaining:       ", hookTokensAfter / 1e18);
        console.log("");
    }

    /**
     * @notice Log final balances after bootstrap
     * @param hookUsdcAfter USDC remaining in hook
     * @param hookTokensAfter Event tokens remaining in hook
     */
    function _logFinalBalances(
        uint256 hookUsdcAfter,
        uint256 hookTokensAfter
    ) internal view {
        console.log("=== FINAL BALANCES ===");
        console.log(
            "Organizer USDC:             ",
            backingAsset.balanceOf(ORGANIZER) / backingUnit(),
            "USDC"
        );
        console.log(
            "Organizer ROCK25:            ",
            eventToken.balanceOf(ORGANIZER) / 1e18,
            "tokens"
        );
        console.log(
            "Hook USDC:                  ",
            hookUsdcAfter / backingUnit(),
            "USDC"
        );
        console.log(
            "Hook ROCK25:                 ",
            hookTokensAfter / 1e18,
            "tokens"
        );
    }

    // ============================================================================
    // UTILITY FUNCTIONS
    // ============================================================================

    /**
     * @notice Helper to get current pool liquidity for assertions
     * @return liquidity Current liquidity in the pool
     */
    function _getCurrentLiquidity() internal view returns (uint128 liquidity) {
        return manager.getLiquidity(poolId);
    }

    /**
     * @notice Helper to check if hook has sufficient tokens for bootstrap
     * @return hasTokens True if hook has at least 600M event tokens
     */
    function _hookHasSufficientTokens() internal view returns (bool hasTokens) {
        return eventToken.balanceOf(address(hook)) >= TOKEN_AMOUNT;
    }

    /**
     * @notice Calculate the unit value for the backing asset
     * @return unit The smallest unit of the backing asset (e.g., 1e6 for USDC)
     */
    function backingUnit() internal view returns (uint256) {
        return 10 ** backingAsset.decimals();
    }

    /**
     * @notice Calculate the actual backing amount with decimals
     * @return amount The backing amount in raw units (e.g., 10,000 * 1e6 = 10,000,000,000)
     */
    function backingAmount() internal view returns (uint256) {
        return BACKING_AMOUNT * backingUnit();
    }

    // ============================================================================
    // EVENTS
    // ============================================================================

    event Transfer(address indexed from, address indexed to, uint256 amount);
}
