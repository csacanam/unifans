// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/console.sol";
import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";

import {TickMath} from "v4-core/libraries/TickMath.sol";
import {LiquidityAmounts} from "v4-periphery/src/libraries/LiquidityAmounts.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {CurrencySettler} from "v4-periphery/lib/v4-core/test/utils/CurrencySettler.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

/**
 * @title EventCoinSimpleHook
 * @notice Simplified Uniswap V4 hook for UniFans - only handles initial liquidity bootstrapping
 * @dev This hook focuses only on:
 *      - Automatic liquidity bootstrapping after pool initialization
 *      - Managing backing asset deposits from organizer
 *      - Coordinating initial liquidity addition via callback pattern
 *
 * @dev Does NOT include:
 *      - Fee collection from swaps
 *      - Fee distribution to organizer/protocol
 *      - Permanent liquidity addition from fees
 *
 * @author @camilosaka
 */
contract EventCoinSimpleHook is BaseHook {
    using CurrencyLibrary for Currency;
    using CurrencySettler for Currency;
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    // ============================================================================
    // CONSTANTS
    // ============================================================================

    /// @notice Tick range for liquidity positions (full range)
    int24 public constant FULL_RANGE_LOWER = -887220;
    int24 public constant FULL_RANGE_UPPER = 887220;

    /// @notice Callback ID for adding initial liquidity
    uint8 constant ADD_LIQUIDITY_CALLBACK_ID = 1;

    // ============================================================================
    // IMMUTABLE STATE VARIABLES
    // ============================================================================

    /// @notice Address of the event organizer who provides backing asset
    address public immutable eventOrganizer;

    /// @notice Address of the event token (ERC20) being traded
    address public immutable eventToken;

    /// @notice Address of the backing asset (ERC20) for the pool
    address public immutable backingAsset;

    /// @notice Amount of backing asset deposited by organizer for initial liquidity
    uint256 public initialBackingAmount;

    /// @notice Flag to track if organizer has deposited backing asset
    bool public backingAssetDeposited;

    // ============================================================================
    // ERRORS
    // ============================================================================

    error InvalidOrganizer();
    error InvalidToken();
    error InvalidBackingAsset();
    error InvalidCallbackId(uint8 callbackId);
    error CallbackNotFromPoolManager();
    error OnlyOrganizer();
    error ZeroAmounts();
    error BackingAssetAlreadyDeposited();
    error NoBackingAssetDeposited();
    error InsufficientEventTokens();

    // ============================================================================
    // MODIFIERS
    // ============================================================================

    /// @notice Ensures only the pool manager can call callback functions
    modifier onlyPoolManagerCallback() {
        if (msg.sender != address(poolManager)) {
            revert CallbackNotFromPoolManager();
        }
        _;
    }

    /// @notice Ensures only the event organizer can call certain functions
    modifier onlyOrganizer() {
        if (msg.sender != eventOrganizer) revert OnlyOrganizer();
        _;
    }

    // ============================================================================
    // CONSTRUCTOR
    // ============================================================================

    /**
     * @notice Initializes the EventCoinSimpleHook
     * @param _manager The Uniswap V4 PoolManager address
     * @param _eventOrganizer The address of the event organizer
     * @param _eventToken The address of the event token
     * @param _backingAsset The address of the backing asset (ERC20)
     * @dev All addresses must be non-zero for security
     */
    constructor(
        IPoolManager _manager,
        address _eventOrganizer,
        address _eventToken,
        address _backingAsset
    ) BaseHook(_manager) {
        if (_eventOrganizer == address(0)) revert InvalidOrganizer();
        if (_eventToken == address(0)) revert InvalidToken();
        if (_backingAsset == address(0)) revert InvalidBackingAsset();

        eventOrganizer = _eventOrganizer;
        eventToken = _eventToken;
        backingAsset = _backingAsset;
    }

    // ============================================================================
    // HOOK PERMISSIONS
    // ============================================================================

    /**
     * @notice Configure hook permissions for Uniswap V4
     * @return permissions The hook permissions configuration
     * @dev Only afterInitialize is enabled - no swap processing
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
                afterInitialize: true, // ✅ For automatic liquidity bootstrapping
                beforeAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: false,
                afterSwap: false, // ❌ No swap processing in simple version
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    // ============================================================================
    // LIQUIDITY BOOTSTRAPPING
    // ============================================================================

    /**
     * @notice Allows organizer to deposit backing asset for initial liquidity
     * @dev This must be called before pool initialization to provide backing asset
     * @param amount Amount of backing asset to deposit for initial liquidity
     */
    function depositBackingAsset(uint256 amount) external onlyOrganizer {
        if (backingAssetDeposited) revert BackingAssetAlreadyDeposited();
        if (amount == 0) revert ZeroAmounts();

        // Transfer backing asset from organizer to this hook
        // Organizer must have approved this amount to the hook
        IERC20(backingAsset).transferFrom(msg.sender, address(this), amount);

        initialBackingAmount = amount;
        backingAssetDeposited = true;

        emit BackingAssetDeposited(msg.sender, amount);
    }

    /**
     * @notice Manual bootstrap initial liquidity (fallback if automatic failed)
     * @dev Uses callback pattern to add liquidity with both backing asset and event tokens
     * @dev Can only be called by organizer after depositing backing asset
     * @dev Only needed if automatic bootstrap in afterInitialize didn't work
     */
    function bootstrapInitialLiquidity(
        PoolKey calldata key
    ) external onlyOrganizer {
        // Check if liquidity already exists (automatic bootstrap worked)
        PoolId poolId = key.toId();
        if (poolManager.getLiquidity(poolId) > 0) {
            revert("Liquidity already bootstrapped");
        }
        if (!_canBootstrapLiquidity()) {
            if (!backingAssetDeposited) revert NoBackingAssetDeposited();
            if (
                IERC20(eventToken).balanceOf(address(this)) < 600_000_000 ether
            ) {
                revert InsufficientEventTokens();
            }
        }

        _performBootstrap(key);
    }

    // ============================================================================
    // CORE HOOK LOGIC
    // ============================================================================

    /**
     * @notice Hook called after pool initialization
     * @dev Automatically bootstraps initial liquidity if conditions are met
     * @param key The pool key containing pool information
     * @return selector The function selector for afterInitialize
     */
    function _afterInitialize(
        address,
        PoolKey calldata key,
        uint160,
        int24
    ) internal override returns (bytes4) {
        require(address(key.hooks) == address(this), "Wrong hook");

        emit PoolInitialized(key);

        // Check if we can automatically bootstrap liquidity
        if (_canBootstrapLiquidity()) {
            _performBootstrap(key);
        }

        return IHooks.afterInitialize.selector;
    }

    /**
     * @notice Check if conditions are met for automatic liquidity bootstrapping
     * @return bool True if bootstrap can proceed automatically
     */
    function _canBootstrapLiquidity() internal view returns (bool) {
        return
            backingAssetDeposited &&
            IERC20(eventToken).balanceOf(address(this)) >= 600_000_000 ether;
    }

    /**
     * @notice Internal function to perform the bootstrap operation
     * @param key The pool key for the liquidity operation
     */
    function _performBootstrap(PoolKey calldata key) internal {
        // Create callback data for liquidity addition
        bytes memory data = abi.encode(
            ADD_LIQUIDITY_CALLBACK_ID,
            abi.encode(key, initialBackingAmount, 600_000_000 ether)
        );

        // Use PoolManager unlock pattern
        poolManager.unlock(data);

        emit LiquidityBootstrapped(
            key,
            initialBackingAmount,
            600_000_000 ether
        );
    }

    // ============================================================================
    // CALLBACK PATTERN FOR LIQUIDITY ADDITION
    // ============================================================================

    /**
     * @notice Callback function called by PoolManager during unlock operations
     * @dev Handles liquidity addition using proper V4 settle/take pattern
     * @param data Encoded callback data containing operation type and parameters
     * @return result The result of the callback operation
     */
    function unlockCallback(
        bytes calldata data
    ) external onlyPoolManagerCallback returns (bytes memory) {
        // Decode callback data to determine operation type
        (uint8 callbackId, bytes memory contents) = abi.decode(
            data,
            (uint8, bytes)
        );

        if (callbackId == ADD_LIQUIDITY_CALLBACK_ID) {
            return _handleBootstrapLiquidity(contents);
        }

        revert InvalidCallbackId(callbackId);
    }

    /**
     * @notice Handles the bootstrap liquidity callback operation
     * @dev Adds initial liquidity with both backing asset and event tokens
     * @param contents Encoded liquidity parameters (PoolKey, backingAmount, tokenAmount)
     * @return result Empty bytes on success
     */
    function _handleBootstrapLiquidity(
        bytes memory contents
    ) internal returns (bytes memory) {
        // Decode liquidity data from callback
        (PoolKey memory key, uint256 backingAmount, uint256 tokenAmount) = abi
            .decode(contents, (PoolKey, uint256, uint256));

        require(address(key.hooks) == address(this), "Wrong hook");

        // Verify currencies are present (order can vary based on addresses)
        address currency0Addr = Currency.unwrap(key.currency0);
        address currency1Addr = Currency.unwrap(key.currency1);

        bool hasBackingAsset = (currency0Addr == backingAsset ||
            currency1Addr == backingAsset);
        bool hasEventToken = (currency0Addr == eventToken ||
            currency1Addr == eventToken);

        require(hasBackingAsset, "Pool must contain backing asset");
        require(hasEventToken, "Pool must contain event token");

        // Simplified approach to avoid stack too deep
        (uint160 sqrtP, , , ) = poolManager.getSlot0(key.toId());

        uint128 L = LiquidityAmounts.getLiquidityForAmounts(
            sqrtP,
            TickMath.getSqrtPriceAtTick(FULL_RANGE_LOWER),
            TickMath.getSqrtPriceAtTick(FULL_RANGE_UPPER),
            Currency.unwrap(key.currency0) == backingAsset
                ? backingAmount
                : tokenAmount,
            Currency.unwrap(key.currency0) == backingAsset
                ? tokenAmount
                : backingAmount
        );

        // Add liquidity to the pool
        console.log("Calculated liquidity:", L);
        console.log("Token amount to use:", tokenAmount / 1e18);
        console.log("Backing amount to use:", backingAmount / 1e6);

        (BalanceDelta delta, ) = poolManager.modifyLiquidity(
            key,
            ModifyLiquidityParams({
                tickLower: FULL_RANGE_LOWER,
                tickUpper: FULL_RANGE_UPPER,
                liquidityDelta: int256(uint256(L)),
                salt: 0
            }),
            ""
        );

        console.log("Delta amount0:", int256(delta.amount0()));
        console.log("Delta amount1:", int256(delta.amount1()));

        // Handle payments using settle pattern (simplified)
        if (delta.amount0() < 0) {
            key.currency0.settle(
                poolManager,
                address(this),
                uint256(uint128(-delta.amount0())),
                false
            );
        }

        if (delta.amount1() < 0) {
            key.currency1.settle(
                poolManager,
                address(this),
                uint256(uint128(-delta.amount1())),
                false
            );
        }

        emit InitialLiquidityAdded(
            key,
            FULL_RANGE_LOWER,
            FULL_RANGE_UPPER,
            L,
            delta.amount0() < 0 ? uint256(uint128(-delta.amount0())) : 0,
            delta.amount1() < 0 ? uint256(uint128(-delta.amount1())) : 0,
            0, // liqBefore simplified
            L // liqAfter simplified
        );

        return bytes("");
    }

    // ============================================================================
    // EVENTS
    // ============================================================================

    /// @notice Emitted when organizer deposits backing asset
    event BackingAssetDeposited(address indexed organizer, uint256 amount);

    /// @notice Emitted when pool is initialized and ready for liquidity
    event PoolInitialized(PoolKey indexed key);

    /// @notice Emitted when initial liquidity is successfully bootstrapped
    event LiquidityBootstrapped(
        PoolKey indexed key,
        uint256 backingAmount,
        uint256 tokenAmount
    );

    /// @notice Emitted when initial liquidity is added to the pool
    event InitialLiquidityAdded(
        PoolKey indexed key,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 backingAmount,
        uint256 tokenAmount,
        uint128 poolLiquidityBefore,
        uint128 poolLiquidityAfter
    );
}
