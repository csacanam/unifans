// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {EventCoinSimpleHook} from "../src/EventCoinSimpleHook.sol";
import {EventToken} from "../src/EventToken.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {LiquidityAmounts} from "v4-periphery/src/libraries/LiquidityAmounts.sol";
import {FullMath} from "v4-core/libraries/FullMath.sol";
import {EventCoinHookTestUtils} from "./utils/EventCoinHookTestUtils.sol";

/**
 * @title EventCoinSimpleHookTest
 * @notice Test suite for EventCoinSimpleHook - focuses only on liquidity bootstrapping
 * @dev Tests the complete flow from deployment to liquidity addition
 */
contract EventCoinSimpleHookTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;
    using EventCoinHookTestUtils for *;

    // ============================================================================
    // TEST CONTRACTS
    // ============================================================================

    EventCoinSimpleHook hook;
    EventToken eventToken;
    MockERC20 backingAsset;

    // ============================================================================
    // TEST CONSTANTS
    // ============================================================================

    string constant EVENT_NAME = "Rock Festival 2025";
    string constant TOKEN_SYMBOL = "ROCK25";
    uint256 constant EVENT_DATE = 1735689600; // Future timestamp

    address constant ORGANIZER = address(0x1234);
    uint256 constant BACKING_AMOUNT = 10_000 * 1e6; // 10,000 USDC (6 decimals)
    uint256 constant TOKEN_AMOUNT = 600_000_000 ether; // 600M tokens

    PoolKey poolKey;
    PoolId poolId;

    // ============================================================================
    // SETUP
    // ============================================================================

    function setUp() public {
        // Deploy Uniswap V4 infrastructure
        deployFreshManagerAndRouters();

        // Deploy backing asset (USDC mock)
        backingAsset = new MockERC20("USD Coin", "USDC", 6);

        // Deploy EventToken
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

        // Setup pool key (currencies ordered by address)
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
            fee: 3000, // 0.3%
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        poolId = poolKey.toId();

        // Give organizer some backing asset
        backingAsset.mint(ORGANIZER, BACKING_AMOUNT);

        _logSetup();
    }

    // ============================================================================
    // TESTS - ERROR CASES
    // ============================================================================

    function test_RevertWhen_DepositTwice() public {
        console.log("\n=== Test: Deposit Twice ===");

        vm.startPrank(ORGANIZER);
        backingAsset.approve(address(hook), BACKING_AMOUNT * 2);

        // First deposit should work
        hook.depositBackingAsset(BACKING_AMOUNT);
        assertEq(hook.initialBackingAmount(), BACKING_AMOUNT);
        assertTrue(hook.backingAssetDeposited());
        uint256 balHookAfter1 = backingAsset.balanceOf(address(hook));

        // Second deposit should revert
        vm.expectRevert(
            EventCoinSimpleHook.BackingAssetAlreadyDeposited.selector
        );
        hook.depositBackingAsset(BACKING_AMOUNT);

        // State unchanged after revert
        assertEq(backingAsset.balanceOf(address(hook)), balHookAfter1);
        assertEq(hook.initialBackingAmount(), BACKING_AMOUNT);
        assertTrue(hook.backingAssetDeposited());

        vm.stopPrank();

        console.log("Correctly prevents double deposit");
    }

    function test_RevertWhen_ManualBootstrapTwice() public {
        console.log("\n=== Test: Manual Bootstrap Twice ===");

        eventToken.setHook(address(hook));
        vm.startPrank(ORGANIZER);
        backingAsset.approve(address(hook), BACKING_AMOUNT);
        hook.depositBackingAsset(BACKING_AMOUNT);
        vm.stopPrank();

        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(0);
        manager.initialize(poolKey, sqrtPriceX96);

        uint128 liq = manager.getLiquidity(poolId);
        assertGt(liq, 0, "Expected liquidity after auto bootstrap");

        vm.startPrank(ORGANIZER);
        vm.expectRevert("Liquidity already bootstrapped");
        hook.bootstrapInitialLiquidity(poolKey);
        vm.stopPrank();

        console.log("Correctly prevents double bootstrap");
    }

    function test_RevertWhen_DepositByNonOrganizer() public {
        address notOrg = address(0xBEEF);
        vm.startPrank(notOrg);
        vm.expectRevert(EventCoinSimpleHook.OnlyOrganizer.selector);
        hook.depositBackingAsset(1);
        vm.stopPrank();
    }

    function test_RevertWhen_DepositZero() public {
        vm.startPrank(ORGANIZER);
        vm.expectRevert(EventCoinSimpleHook.ZeroAmounts.selector);
        hook.depositBackingAsset(0);
        vm.stopPrank();
    }

    function test_NoAutoBootstrap_WithoutBacking() public {
        _initAtDesiredPrice();
        uint128 liq = manager.getLiquidity(poolId);
        assertEq(liq, 0, "No Liquidity because there is No Backing Assets");
    }

    function test_Revert_ManualBootstrap_NoBacking() public {
        eventToken.setHook(address(hook));
        vm.startPrank(ORGANIZER);
        vm.expectRevert(EventCoinSimpleHook.NoBackingAssetDeposited.selector);
        hook.bootstrapInitialLiquidity(poolKey);
        vm.stopPrank();
    }

    event Transfer(address indexed from, address indexed to, uint256 amount);

    function test_Emits_BackingAssetDeposited() public {
        vm.startPrank(ORGANIZER);

        backingAsset.approve(address(hook), BACKING_AMOUNT);

        vm.expectEmit(true, true, false, true, address(backingAsset));
        emit Transfer(ORGANIZER, address(hook), BACKING_AMOUNT);

        vm.expectEmit(true, false, false, true, address(hook));
        emit EventCoinSimpleHook.BackingAssetDeposited(
            ORGANIZER,
            BACKING_AMOUNT
        );

        hook.depositBackingAsset(BACKING_AMOUNT);

        vm.stopPrank();
    }

    // ============================================================================
    // INTEGRATION TEST - COMPLETE FLOW
    // ============================================================================

    function test_CompleteFlowEndToEnd() public {
        console.log("=== COMPLETE FLOW END-TO-END TEST ===");
        console.log("");

        // Log funding before
        console.log("=== FUNDING & APPROVALS - BEFORE ===");
        console.log(
            "Organizer USDC:             ",
            backingAsset.balanceOf(ORGANIZER) / 1e6,
            "USDC"
        );
        console.log(
            "Organizer ROCK25:            ",
            eventToken.balanceOf(ORGANIZER) / 1e18,
            "tokens"
        );
        console.log(
            "Hook USDC:                  ",
            backingAsset.balanceOf(address(hook)) / 1e6,
            "USDC"
        );
        console.log(
            "Hook ROCK25:                 ",
            eventToken.balanceOf(address(hook)) / 1e18,
            "tokens"
        );
        console.log("");

        // Step 1: Transfer tokens to hook
        eventToken.setHook(address(hook));
        assertEq(eventToken.balanceOf(address(hook)), TOKEN_AMOUNT);

        // Step 2: Organizer deposits backing asset
        vm.startPrank(ORGANIZER);
        backingAsset.approve(address(hook), BACKING_AMOUNT);
        hook.depositBackingAsset(BACKING_AMOUNT);
        vm.stopPrank();
        assertEq(backingAsset.balanceOf(address(hook)), BACKING_AMOUNT);

        // Log funding after
        console.log("=== FUNDING & APPROVALS - AFTER ===");
        console.log(
            "Organizer USDC:             ",
            backingAsset.balanceOf(ORGANIZER) / 1e6,
            "USDC"
        );
        console.log(
            "Organizer ROCK25:            ",
            eventToken.balanceOf(ORGANIZER) / 1e18,
            "tokens"
        );
        console.log(
            "Hook USDC:                  ",
            backingAsset.balanceOf(address(hook)) / 1e6,
            "USDC"
        );
        console.log(
            "Hook ROCK25:                 ",
            eventToken.balanceOf(address(hook)) / 1e18,
            "tokens"
        );
        console.log("");
        console.log("--------------------------------------------");
        console.log("");

        // Step 3: Initialize pool (automatic bootstrap)
        _initAtDesiredPrice();

        // Step 4: Verify final state
        uint128 finalLiquidity = manager.getLiquidity(poolId);
        assertTrue(finalLiquidity > 0, "Pool must have liquidity");

        // Hook should have consumed some/all of its assets
        uint256 hookTokensAfter = eventToken.balanceOf(address(hook));
        uint256 hookUsdcAfter = backingAsset.balanceOf(address(hook));

        console.log("=== BOOTSTRAP RESULTS ===");
        console.log("Pool liquidity:             ", finalLiquidity);
        console.log(
            "USDC consumed:              ",
            (BACKING_AMOUNT - hookUsdcAfter) / 1e6
        );
        console.log(
            "ROCK25 consumed:             ",
            (TOKEN_AMOUNT - hookTokensAfter) / 1e18
        );
        console.log("Hook USDC remaining:        ", hookUsdcAfter / 1e6);
        console.log("Hook ROCK25 remaining:       ", hookTokensAfter / 1e18);
        console.log("");
        console.log("--------------------------------------------");
        console.log("");

        console.log("=== FINAL BALANCES ===");
        console.log(
            "Organizer USDC:             ",
            backingAsset.balanceOf(ORGANIZER) / 1e6,
            "USDC"
        );
        console.log(
            "Organizer ROCK25:            ",
            eventToken.balanceOf(ORGANIZER) / 1e18,
            "tokens"
        );
        console.log(
            "Hook USDC:                  ",
            hookUsdcAfter / 1e6,
            "USDC"
        );
        console.log(
            "Hook ROCK25:                 ",
            hookTokensAfter / 1e18,
            "tokens"
        );

        // Verify significant amounts were consumed for liquidity
        assertLt(hookTokensAfter, TOKEN_AMOUNT, "Should consume some tokens");
        assertLt(hookUsdcAfter, BACKING_AMOUNT, "Should consume some USDC");

        uint256 usdcSpent = BACKING_AMOUNT -
            backingAsset.balanceOf(address(hook));
        uint256 evtSpent = TOKEN_AMOUNT - eventToken.balanceOf(address(hook));

        EventCoinHookTestUtils.log6("USDC spent", usdcSpent);
        EventCoinHookTestUtils.log18("ROCK25 spent", evtSpent);

        EventCoinHookTestUtils.log6(
            "Hook USDC remaining",
            backingAsset.balanceOf(address(hook))
        );
        EventCoinHookTestUtils.log18(
            "Hook ROCK25 remaining",
            eventToken.balanceOf(address(hook))
        );

        assertApproxEqAbs(
            usdcSpent,
            BACKING_AMOUNT,
            1,
            "USDC mismatch (end-to-end)"
        );
    }

    function _initAtDesiredPrice() internal {
        address c0 = Currency.unwrap(poolKey.currency0);
        address c1 = Currency.unwrap(poolKey.currency1);

        uint256 amount0Raw;
        uint256 amount1Raw;

        if (c0 == address(backingAsset) && c1 == address(eventToken)) {
            // currency0 = USDC, currency1 = EVENT
            amount0Raw = BACKING_AMOUNT;
            amount1Raw = TOKEN_AMOUNT;
        } else if (c0 == address(eventToken) && c1 == address(backingAsset)) {
            // currency0 = EVENT, currency1 = USDC
            amount0Raw = TOKEN_AMOUNT;
            amount1Raw = BACKING_AMOUNT;
        } else {
            revert("Pool must contain backing & event");
        }

        uint160 sqrtPriceX96 = EventCoinHookTestUtils.priceToSqrtPriceX96_RAW(
            amount1Raw,
            amount0Raw
        );

        // Debug logs for initialization
        console.log("=== POOL INIT ===");
        console.log("amount0Raw:                 ", amount0Raw, "(USDC, 6d)");
        console.log(
            "amount1Raw:                 ",
            amount1Raw,
            "(ROCK25, 18d)"
        );
        console.log("sqrtPriceX96:               ", sqrtPriceX96);

        uint256 priceRaw = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) >>
            192;
        console.log("price RAW (t1/t0):          ", priceRaw);
        console.log(
            "price HUMAN (t1/t0):        ",
            priceRaw / 1e12,
            "ROCK25 per 1 USDC"
        );

        console.log("");
        console.log("--------------------------------------------");
        console.log("");

        manager.initialize(poolKey, sqrtPriceX96);
    }

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
            backingAsset.balanceOf(ORGANIZER) / 1e6,
            "USDC"
        );
        console.log(
            "Organizer ROCK25:            ",
            eventToken.balanceOf(ORGANIZER) / 1e18,
            "tokens"
        );
        console.log(
            "Hook USDC:                  ",
            backingAsset.balanceOf(address(hook)) / 1e6,
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
}
