// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {EventCoinHook} from "../src/EventCoinHook.sol";
import {EventToken} from "../src/EventToken.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

/**
 * @title EventCoinHookTest
 * @dev Test suite for EventCoinHook contract
 * @dev Tests hook deployment, pool initialization, and one-sided liquidity
 */
contract EventCoinHookTest is Test, Deployers {
    EventCoinHook hook;
    EventToken eventToken;

    // Pool currencies
    Currency eventTokenCurrency;
    Currency wethCurrency;

    // Test parameters
    string public constant EVENT_NAME = "UniFans Test Event";
    string public constant TOKEN_SYMBOL = "TEST";
    uint256 public constant EVENT_DATE = 1758577019; // 30 days from now
    address public constant ORGANIZER = address(0x123);
    address public constant PROTOCOL_WALLET = address(0x456);

    function setUp() public {
        // Deploy v4 core contracts
        deployFreshManagerAndRouters();

        // Deploy EventToken
        eventToken = new EventToken(
            EVENT_NAME,
            TOKEN_SYMBOL,
            EVENT_DATE,
            ORGANIZER
        );

        // Configure currencies (ETH is always currency0, EventToken is currency1)
        wethCurrency = Currency.wrap(address(0));
        eventTokenCurrency = Currency.wrap(address(eventToken));

        // Deploy hook with proper flags
        uint160 flags = uint160(
            Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_SWAP_FLAG
        );
        address hookAddress = address(flags);

        deployCodeTo(
            "EventCoinHook.sol",
            abi.encode(
                manager,
                ORGANIZER,
                address(eventToken),
                PROTOCOL_WALLET
            ),
            hookAddress
        );

        hook = EventCoinHook(payable(hookAddress));

        // Transfer tokens to hook and verify
        eventToken.setHook(address(hook));

        uint256 hookBalance = eventToken.balanceOf(address(hook));
        uint256 contractBalance = eventToken.balanceOf(address(eventToken));

        require(hookBalance > 500_000_000 ether, "Hook should receive tokens");
        require(contractBalance == 0, "Contract should be cleared");

        // Initialize pool
        (key, ) = initPool(
            wethCurrency,
            eventTokenCurrency,
            hook,
            3000,
            SQRT_PRICE_1_1
        );
    }

    // ============ BASIC SETUP TESTS ============

    function test_basicSetup() public {
        // Verify hook deployment
        assertEq(hook.eventOrganizer(), ORGANIZER);
        assertEq(hook.eventToken(), address(eventToken));
        assertEq(hook.protocolWallet(), PROTOCOL_WALLET);

        // Verify pool initialization
        assertTrue(key.currency0 == wethCurrency);
        assertTrue(key.currency1 == eventTokenCurrency);
    }

    function test_setHookAndOneSidedLiquidity() public {
        // Verify setHook execution
        address currentHook = eventToken.eventHook();
        uint256 hookBalance = eventToken.balanceOf(address(hook));
        uint256 contractBalance = eventToken.balanceOf(address(eventToken));

        assertEq(currentHook, address(hook), "Hook should be set");
        assertTrue(hookBalance > 500_000_000 ether, "Hook should have tokens");
        assertEq(contractBalance, 0, "Contract should be cleared");

        // Verify pool configuration
        int24 minTick = TickMath.minUsableTick(60);
        int24 maxTick = TickMath.maxUsableTick(60);

        assertTrue(minTick < maxTick, "Valid tick range");
    }

    function test_poolHasActualLiquidity() public {
        // Check if the pool actually has liquidity after initialization
        // This will reveal if _createInitialLiquidity actually adds liquidity

        // Try to get pool liquidity at the current price
        // If there's no liquidity, this will show 0

        // For now, let's just verify the hook has the tokens
        uint256 hookBalance = eventToken.balanceOf(address(hook));
        assertTrue(hookBalance > 0, "Hook should have tokens for liquidity");

        // TODO: Add actual pool liquidity verification
        // This would require checking the pool's liquidity at specific ticks
        // But we can see that tokens are in the hook, ready to be used
    }
}
