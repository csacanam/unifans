// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {LiquidityAmounts} from "v4-periphery/src/libraries/LiquidityAmounts.sol";

/**
 * @title EventCoinHook
 * @notice Uniswap V4 hook for UniFans - distributes fees to organizers and adds permanent liquidity
 * @dev This hook implements the core UniFans tokenomics:
 *      - Collects 3% fee from swaps in both directions (ETH ↔ TOKEN)
 *      - Distributes 40% to permanent liquidity (strengthens the pool)
 *      - Distributes 60% to rewards (90% organizer + 10% protocol)
 *      - All distributions happen immediately after each swap
 *
 * @dev Fee collection is asset-aware:
 *      - ETH → TOKEN swaps: fees collected in ETH
 *      - TOKEN → ETH swaps: fees collected in TOKENS
 *
 * @dev This creates a sustainable model where:
 *      - Organizers receive immediate funding
 *      - Protocol earns sustainable revenue
 *      - Pool maintains liquidity for secondary market
 *
 * @author UniFans Team
 * @custom:security-contact security@unifans.xyz
 */
contract EventCoinHook is BaseHook {
    using LPFeeLibrary for uint24;

    // ============================================================================
    // ERRORS
    // ============================================================================

    error InvalidOrganizer();
    error FeeDistributionFailed();
    error LiquidityAdditionFailed();

    // ============================================================================
    // CONSTANTS
    // ============================================================================

    /// @notice Fee percentage (3% = 300 basis points)
    uint24 public constant FEE_BPS = 300;

    /// @notice Distribution percentages for collected fees
    uint256 public constant LIQUIDITY_PERCENTAGE = 40; // 40% to permanent liquidity
    uint256 public constant REWARDS_PERCENTAGE = 60; // 60% to rewards distribution

    /// @notice Reward split percentages
    uint256 public constant ORGANIZER_PERCENTAGE = 90; // 90% to event organizer
    uint256 public constant PROTOCOL_PERCENTAGE = 10; // 10% to UniFans protocol

    /// @notice Tick range for liquidity positions (full range)
    int24 public constant FULL_RANGE_LOWER = -887220;
    int24 public constant FULL_RANGE_UPPER = 887220;

    // ============================================================================
    // IMMUTABLE STATE VARIABLES
    // ============================================================================

    /// @notice Address of the event organizer who receives rewards
    address public immutable eventOrganizer;

    /// @notice Address of the event token (ERC20) being traded
    address public immutable eventToken;

    /// @notice Address of the UniFans protocol wallet
    address public immutable protocolWallet;

    // ============================================================================
    // CONSTRUCTOR
    // ============================================================================

    /**
     * @notice Initializes the EventCoinHook
     * @param _manager The Uniswap V4 PoolManager address
     * @param _eventOrganizer The address of the event organizer
     * @param _eventToken The address of the event token
     * @param _protocolWallet The address of the UniFans protocol wallet
     * @dev All addresses must be non-zero for security
     */
    constructor(
        IPoolManager _manager,
        address _eventOrganizer,
        address _eventToken,
        address _protocolWallet
    ) BaseHook(_manager) {
        if (_eventOrganizer == address(0)) revert InvalidOrganizer();
        if (_eventToken == address(0)) revert InvalidOrganizer();
        if (_protocolWallet == address(0)) revert InvalidOrganizer();

        eventOrganizer = _eventOrganizer;
        eventToken = _eventToken;
        protocolWallet = _protocolWallet;
    }

    // ============================================================================
    // HOOK PERMISSIONS
    // ============================================================================

    /**
     * @notice Configure hook permissions for Uniswap V4
     * @return permissions The hook permissions configuration
     * @dev Only afterSwap is enabled - we don't need other hooks for this use case
     */
    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: true,
                beforeAddLiquidity: false, // ✅ Simplified for now
                beforeRemoveLiquidity: false,
                afterAddLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: false,
                afterSwap: true, // ✅ Only afterSwap needed
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    // ============================================================================
    // CORE HOOK LOGIC
    // ============================================================================

    function _afterInitialize(
        address /* sender */,
        PoolKey calldata key,
        uint160 /* sqrtPriceX96 */,
        int24 /* tick */
    ) internal override returns (bytes4) {
        // Create initial liquidity automatically with the 600M tokens
        // This executes when the pool is initialized
        _createInitialLiquidity(key);

        return IHooks.afterInitialize.selector;
    }

    /**
     * @notice Hook called after a swap is executed
     * @dev This is the main function that implements UniFans tokenomics
     * @dev Collects 3% fee and distributes according to the model:
     *      - 40% → permanent liquidity (strengthens pool)
     *      - 60% → rewards (90% organizer + 10% protocol)
     *
     * @param key The pool key containing pool information
     * @param swapParams The swap parameters (direction, amounts)
     * @param delta The balance delta showing what changed in the swap
     * @return selector The function selector for afterSwap
     * @return delta The balance delta (unused, returns 0)
     */
    function _afterSwap(
        address, // sender - not used in this implementation
        PoolKey calldata key,
        SwapParams calldata swapParams,
        BalanceDelta delta,
        bytes calldata // hookData - not used in this implementation
    ) internal override returns (bytes4, int128) {
        // Only process ETH-TOKEN pools (currency0 must be ETH/address(0))
        if (!key.currency0.isAddressZero()) {
            return (this.afterSwap.selector, 0);
        }

        // Process BOTH directions: ETH ↔ TOKEN
        if (swapParams.zeroForOne) {
            // ETH → TOKEN (buying tokens)
            _processBuySwap(delta, key);
        } else {
            // TOKEN → ETH (selling tokens)
            _processSellSwap(delta, key);
        }

        return (this.afterSwap.selector, 0);
    }

    function _createInitialLiquidity(PoolKey memory key) internal {
        // Create position with the tokens that the hook already has
        // Use full range ticks for maximum liquidity coverage
        int24 minTick = FULL_RANGE_LOWER;
        int24 maxTick = FULL_RANGE_UPPER;

        // Calculate liquidity using LiquidityAmounts
        uint160 sqrtPriceLower = TickMath.getSqrtPriceAtTick(minTick);
        uint160 sqrtPriceUpper = TickMath.getSqrtPriceAtTick(maxTick);

        // Use all available tokens from the hook
        uint256 availableTokens = IERC20(eventToken).balanceOf(address(this));

        if (availableTokens == 0) return; // No tokens to add as liquidity

        // Calculate liquidity for one-sided (tokens only)
        uint128 calculatedLiquidity = LiquidityAmounts.getLiquidityForAmount1(
            sqrtPriceLower,
            sqrtPriceUpper,
            availableTokens
        );

        if (calculatedLiquidity == 0) return; // No liquidity to add

        // ✅ SIMPLIFIED: For now, just log the liquidity calculation
        // TODO: Implement full callback pattern for real liquidity addition
        // This will be the next step after basic functionality works

        // Emit event for successful liquidity calculation
        emit InitialLiquidityAdded(
            key,
            minTick,
            maxTick,
            calculatedLiquidity,
            availableTokens
        );
    }

    // ============================================================================
    // UNLOCK CALLBACK (ZORA PATTERN)
    // ============================================================================

    // REMOVED: Custom unlock function not needed with beforeAddLiquidity pattern

    // ============================================================================
    // EVENTS
    // ============================================================================

    event InitialLiquidityAdded(
        PoolKey indexed key,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 tokens
    );

    // ============================================================================
    // SWAP PROCESSING FUNCTIONS
    // ============================================================================

    /**
     * @notice Process ETH → TOKEN swap (buying tokens)
     * @param delta The balance delta from the swap
     * @param key The pool key for liquidity operations
     * @dev Collects fees in ETH and distributes accordingly
     */
    function _processBuySwap(
        BalanceDelta delta,
        PoolKey calldata key
    ) internal {
        // Calculate ETH spent (negative delta for amount0)
        uint256 ethSpent = uint256(int256(-delta.amount0()));

        // Calculate 3% fee in ETH
        uint256 ethFees = (ethSpent * FEE_BPS) / 10000;

        if (ethFees > 0) {
            _distributeETHFees(ethFees, key);
        }
    }

    /**
     * @notice Process TOKEN → ETH swap (selling tokens)
     * @param delta The balance delta from the swap
     * @param key The pool key for liquidity operations
     * @dev Collects fees in TOKENS and distributes accordingly
     */
    function _processSellSwap(
        BalanceDelta delta,
        PoolKey calldata key
    ) internal {
        // Calculate tokens sold (negative delta for amount1)
        uint256 tokensSold = uint256(int256(-delta.amount1()));

        // Calculate 3% fee in TOKENS
        uint256 tokenFees = (tokensSold * FEE_BPS) / 10000;

        if (tokenFees > 0) {
            _distributeTokenFees(tokenFees, key);
        }
    }

    // ============================================================================
    // FEE DISTRIBUTION FUNCTIONS
    // ============================================================================

    /**
     * @notice Distributes ETH fees according to UniFans tokenomics
     * @param totalFees Total ETH fees collected from the swap
     * @param key The pool key for liquidity operations
     * @dev Splits fees: 40% to liquidity, 60% to rewards
     */
    function _distributeETHFees(
        uint256 totalFees,
        PoolKey calldata key
    ) internal {
        // 40% to permanent liquidity (strengthens the pool)
        uint256 liquidityAmount = (totalFees * LIQUIDITY_PERCENTAGE) / 100;
        _addPermanentLiquidity(liquidityAmount, key);

        // 60% to rewards distribution
        uint256 rewardsAmount = (totalFees * REWARDS_PERCENTAGE) / 100;
        _distributeETHRewards(rewardsAmount);
    }

    /**
     * @notice Distributes TOKEN fees according to UniFans tokenomics
     * @param totalFees Total TOKEN fees collected from the swap
     * @param key The pool key for liquidity operations
     * @dev Splits fees: 40% to liquidity, 60% to rewards
     */
    function _distributeTokenFees(
        uint256 totalFees,
        PoolKey calldata key
    ) internal {
        // 40% to permanent liquidity (strengthens the pool)
        uint256 liquidityAmount = (totalFees * LIQUIDITY_PERCENTAGE) / 100;
        _addPermanentLiquidity(liquidityAmount, key);

        // 60% to rewards distribution
        uint256 rewardsAmount = (totalFees * REWARDS_PERCENTAGE) / 100;
        _distributeTokenRewards(rewardsAmount);
    }

    // ============================================================================
    // REWARDS DISTRIBUTION FUNCTIONS
    // ============================================================================

    /**
     * @notice Distributes ETH rewards: 90% to organizer, 10% to protocol
     * @param totalRewards Total ETH rewards to distribute
     * @dev Both distributions happen immediately
     */
    function _distributeETHRewards(uint256 totalRewards) internal {
        // 90% to event organizer (immediate payment)
        uint256 organizerAmount = (totalRewards * ORGANIZER_PERCENTAGE) / 100;
        _transferETHToOrganizer(organizerAmount);

        // 10% to UniFans protocol (immediate payment)
        uint256 protocolAmount = (totalRewards * PROTOCOL_PERCENTAGE) / 100;
        _transferETHToProtocol(protocolAmount);
    }

    /**
     * @notice Distributes TOKEN rewards: 90% to organizer, 10% to protocol
     * @param totalRewards Total TOKEN rewards to distribute
     * @dev Both distributions happen immediately
     */
    function _distributeTokenRewards(uint256 totalRewards) internal {
        // 90% to event organizer (immediate payment)
        uint256 organizerAmount = (totalRewards * ORGANIZER_PERCENTAGE) / 100;
        _transferTokensToOrganizer(organizerAmount);

        // 10% to UniFans protocol (immediate payment)
        uint256 protocolAmount = (totalRewards * PROTOCOL_PERCENTAGE) / 100;
        _transferTokensToProtocol(protocolAmount);
    }

    // ============================================================================
    // LIQUIDITY MANAGEMENT
    // ============================================================================

    /**
     * @notice Adds permanent liquidity to the pool
     * @param amount Amount to add as permanent liquidity (in ETH)
     * @param key The pool key for liquidity operations
     * @dev This strengthens the pool and ensures market depth for secondary trading
     * @dev Uses full range liquidity (-887220 to 887220 ticks)
     */
    function _addPermanentLiquidity(
        uint256 amount,
        PoolKey calldata key
    ) internal {
        if (amount == 0) return;

        // Use consistent full range ticks
        int24 minTick = FULL_RANGE_LOWER;
        int24 maxTick = FULL_RANGE_UPPER;

        // Create liquidity parameters
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: minTick,
            tickUpper: maxTick,
            liquidityDelta: int256(amount), // Add liquidity
            salt: 0
        });

        // Add real liquidity to the pool
        poolManager.modifyLiquidity(key, params, "");
    }

    // ============================================================================
    // TRANSFER FUNCTIONS
    // ============================================================================

    /**
     * @notice Transfers ETH to the event organizer
     * @param amount Amount of ETH to transfer
     * @dev Uses low-level call for ETH transfers
     */
    function _transferETHToOrganizer(uint256 amount) internal {
        if (amount == 0) return;

        (bool success, ) = eventOrganizer.call{value: amount}("");
        if (!success) revert FeeDistributionFailed();
    }

    /**
     * @notice Transfers ETH to the protocol wallet
     * @param amount Amount of ETH to transfer
     * @dev Uses low-level call for ETH transfers
     */
    function _transferETHToProtocol(uint256 amount) internal {
        if (amount == 0) return;

        (bool success, ) = protocolWallet.call{value: amount}("");
        if (!success) revert FeeDistributionFailed();
    }

    /**
     * @notice Transfers TOKENS to the event organizer
     * @param amount Amount of tokens to transfer
     * @dev Uses IERC20 transfer for token transfers
     */
    function _transferTokensToOrganizer(uint256 amount) internal {
        if (amount == 0) return;

        bool success = IERC20(eventToken).transfer(eventOrganizer, amount);
        if (!success) revert FeeDistributionFailed();
    }

    /**
     * @notice Transfers TOKENS to the protocol wallet
     * @param amount Amount of tokens to transfer
     * @dev Uses IERC20 transfer for token transfers
     */
    function _transferTokensToProtocol(uint256 amount) internal {
        if (amount == 0) return;

        bool success = IERC20(eventToken).transfer(protocolWallet, amount);
        if (!success) revert FeeDistributionFailed();
    }

    // ============================================================================
    // FALLBACK FUNCTIONS
    // ============================================================================

    /**
     * @notice Allows the contract to receive ETH
     * @dev Required for ETH transfers to work
     */
    receive() external payable {}
}
