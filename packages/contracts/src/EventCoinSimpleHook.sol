// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// ============================================================================
// UNISWAP V4 CORE IMPORTS
// ============================================================================
import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";

// ============================================================================
// UNISWAP V4 LIBRARIES
// ============================================================================
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {LiquidityAmounts} from "v4-periphery/src/libraries/LiquidityAmounts.sol";
import {CurrencySettler} from "v4-periphery/lib/v4-core/test/utils/CurrencySettler.sol";

// ============================================================================
// EXTERNAL DEPENDENCIES
// ============================================================================
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title EventCoinSimpleHook
 * @notice Simplified Uniswap V4 hook for UniFans event token liquidity bootstrapping
 * @dev This streamlined version focuses exclusively on initial liquidity provision,
 *      providing automatic two-sided liquidity when pools are initialized.
 *
 * ## Key Features
 * - ✅ Automatic liquidity bootstrapping after pool initialization
 * - ✅ Two-sided liquidity provision (backing asset + event tokens)
 * - ✅ Full-range liquidity positions for maximum trading efficiency
 * - ✅ Secure organizer-only deposit mechanism with single-use protection
 * - ✅ Fallback manual bootstrap for edge cases
 * - ✅ Generic backing asset support (any ERC20 with metadata)
 *
 * ## Architecture
 * This contract implements the Uniswap V4 hook pattern with `afterInitialize`
 * permission to automatically add liquidity when pools are created. It uses
 * the standard unlock/callback pattern for atomic operations.
 *
 * ## Flow
 * 1. Event organizer deposits backing asset via `depositBackingAsset()`
 * 2. Event tokens are transferred to hook (600M tokens)
 * 3. Pool initialization triggers automatic bootstrap via `afterInitialize`
 * 4. Hook adds full-range liquidity using both assets
 * 5. Pool is ready for trading with established price
 *
 * @author UniFans Protocol Team
 * @custom:version 2.0.0 - Generic backing asset support
 * @custom:security-contact security@unifans.io
 */
contract EventCoinSimpleHook is BaseHook {
    using CurrencyLibrary for Currency;
    using CurrencySettler for Currency;
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;
    using SafeERC20 for IERC20;

    // ============================================================================
    // CONSTANTS
    // ============================================================================

    /// @notice Lower tick for full-range liquidity positions (-887220 = minimum tick)
    /// @dev Full range ensures maximum capital efficiency and trading coverage
    int24 public constant FULL_RANGE_LOWER = -887220;

    /// @notice Upper tick for full-range liquidity positions (887220 = maximum tick)
    /// @dev Full range ensures maximum capital efficiency and trading coverage
    int24 public constant FULL_RANGE_UPPER = 887220;

    /// @notice Callback identifier for liquidity addition operations
    /// @dev Used to route callback data to the correct handler function
    uint8 private constant ADD_LIQUIDITY_CALLBACK_ID = 1;

    /// @notice Fixed token amount for initial liquidity (600M tokens)
    /// @dev This represents 60% of total token supply allocated to initial liquidity
    uint256 public constant INITIAL_TOKEN_AMOUNT = 600_000_000 ether;

    // ============================================================================
    // IMMUTABLE STATE VARIABLES
    // ============================================================================

    /// @notice Address of the event organizer authorized to deposit backing assets
    /// @dev This address is set at deployment and cannot be changed
    address public immutable eventOrganizer;

    /// @notice Address of the event token contract (ERC20 compatible)
    /// @dev The token representing ownership/access to the event
    address public immutable eventToken;

    /// @notice Address of the backing asset used for initial liquidity
    /// @dev Typically USDC or another stable asset providing price stability
    address public immutable backingAsset;

    /// @notice Number of decimals for the backing asset
    /// @dev Cached at deployment for gas efficiency in calculations
    uint8 public immutable backingAssetDecimals;

    // ============================================================================
    // MUTABLE STATE VARIABLES
    // ============================================================================

    /// @notice Amount of backing asset deposited by organizer for initial liquidity
    /// @dev This value is set when organizer calls depositBackingAsset()
    uint256 public initialBackingAmount;

    /// @notice Flag indicating whether organizer has deposited backing asset
    /// @dev Prevents double deposits and enables automatic bootstrap checks
    bool public backingAssetDeposited;

    // ============================================================================
    // CUSTOM ERRORS
    // ============================================================================

    /// @notice Thrown when organizer address is zero during construction
    error InvalidOrganizer();

    /// @notice Thrown when event token address is zero during construction
    error InvalidToken();

    /// @notice Thrown when backing asset address is zero during construction
    error InvalidBackingAsset();

    /// @notice Thrown when backing asset doesn't implement IERC20Metadata
    error BackingAssetNotERC20Metadata();

    /// @notice Thrown when an unknown callback ID is received
    /// @param callbackId The invalid callback identifier that was provided
    error InvalidCallbackId(uint8 callbackId);

    /// @notice Thrown when callback is called by address other than PoolManager
    error CallbackNotFromPoolManager();

    /// @notice Thrown when non-organizer attempts to call organizer-only functions
    error OnlyOrganizer();

    /// @notice Thrown when attempting to deposit zero amount of backing asset
    error ZeroAmounts();

    /// @notice Thrown when organizer attempts to deposit backing asset twice
    error BackingAssetAlreadyDeposited();

    /// @notice Thrown when bootstrap is attempted without backing asset deposit
    error NoBackingAssetDeposited();

    /// @notice Thrown when hook doesn't have sufficient event tokens for bootstrap
    error InsufficientEventTokens();

    // ============================================================================
    // ACCESS CONTROL MODIFIERS
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
     * @notice Initializes the EventCoinSimpleHook with generic backing asset support
     * @param _manager The Uniswap V4 PoolManager address
     * @param _eventOrganizer The address of the event organizer
     * @param _eventToken The address of the event token
     * @param _backingAsset The address of the backing asset (must implement IERC20Metadata)
     * @dev All addresses must be non-zero for security. Backing asset decimals are cached.
     */
    constructor(
        IPoolManager _manager,
        address _eventOrganizer,
        address _eventToken,
        address _backingAsset
    ) BaseHook(_manager) {
        // Validate constructor parameters
        if (_eventOrganizer == address(0)) revert InvalidOrganizer();
        if (_eventToken == address(0)) revert InvalidToken();
        if (_backingAsset == address(0)) revert InvalidBackingAsset();

        // Validate backing asset implements IERC20Metadata
        try IERC20Metadata(_backingAsset).decimals() returns (uint8 decimals) {
            backingAssetDecimals = decimals;
        } catch {
            revert BackingAssetNotERC20Metadata();
        }

        // Set immutable state variables
        eventOrganizer = _eventOrganizer;
        eventToken = _eventToken;
        backingAsset = _backingAsset;
    }

    // ============================================================================
    // HOOK PERMISSIONS CONFIGURATION
    // ============================================================================

    /**
     * @notice Configure hook permissions for Uniswap V4
     * @return permissions The hook permissions configuration
     * @dev Only afterInitialize is enabled - no swap processing in simple version
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
    // PUBLIC ORGANIZER FUNCTIONS
    // ============================================================================

    /**
     * @notice Allows event organizer to deposit backing asset for initial liquidity
     * @dev This function must be called before pool initialization to enable automatic
     *      bootstrap. The organizer must approve this contract to spend the backing asset.
     *
     * ## Requirements
     * - Only callable by the designated event organizer
     * - Amount must be greater than zero
     * - Can only be called once per hook deployment
     * - Organizer must have sufficient backing asset balance
     * - Organizer must have approved this contract for the deposit amount
     *
     * ## Process
     * 1. Validates caller is organizer and amount > 0
     * 2. Checks backing asset hasn't been deposited before
     * 3. Transfers backing asset from organizer to hook using SafeERC20
     * 4. Sets deposit flag to prevent double deposits
     * 5. Emits BackingAssetDeposited event
     *
     * @param amount The amount of backing asset to deposit (in backing asset decimals)
     *
     * @custom:emits BackingAssetDeposited
     */
    function depositBackingAsset(uint256 amount) external onlyOrganizer {
        if (backingAssetDeposited) revert BackingAssetAlreadyDeposited();
        if (amount == 0) revert ZeroAmounts();

        // Transfer backing asset from organizer to this hook
        // Using SafeERC20 for enhanced security
        IERC20(backingAsset).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        // Update state
        initialBackingAmount = amount;
        backingAssetDeposited = true;

        emit BackingAssetDeposited(msg.sender, amount);
    }

    /**
     * @notice Manually bootstrap initial liquidity as fallback mechanism
     * @dev This function serves as a fallback if automatic bootstrapping in afterInitialize
     *      fails for any reason. It uses the same callback pattern as automatic bootstrap.
     *
     * ## Requirements
     * - Only callable by the designated event organizer
     * - Backing asset must have been deposited previously
     * - Hook must have sufficient event tokens (600M tokens)
     * - Pool must not already have liquidity
     * - Pool must be initialized
     *
     * ## Use Cases
     * - Automatic bootstrap failed due to gas limits
     * - Pool was initialized before backing asset deposit
     * - Recovery from edge cases during deployment
     *
     * @param key The pool key identifying the target pool for liquidity addition
     *
     * @custom:emits LiquidityBootstrapped
     * @custom:emits InitialLiquidityAdded
     */
    function bootstrapInitialLiquidity(
        PoolKey calldata key
    ) external onlyOrganizer {
        // Check if liquidity already exists (automatic bootstrap worked)
        PoolId poolId = key.toId();
        if (poolManager.getLiquidity(poolId) > 0) {
            revert("Liquidity already bootstrapped");
        }

        // Validate bootstrap prerequisites
        if (!_canBootstrapLiquidity()) {
            if (!backingAssetDeposited) revert NoBackingAssetDeposited();
            if (
                IERC20(eventToken).balanceOf(address(this)) <
                INITIAL_TOKEN_AMOUNT
            ) {
                revert InsufficientEventTokens();
            }
        }

        _performBootstrap(key);
    }

    // ============================================================================
    // HOOK LIFECYCLE FUNCTIONS
    // ============================================================================

    /**
     * @notice Hook function automatically called after pool initialization
     * @dev This is the core function that enables automatic liquidity bootstrapping.
     *      It's called by the Uniswap V4 PoolManager immediately after pool initialization.
     *
     * ## Automatic Bootstrap Conditions
     * - Organizer has deposited backing asset via depositBackingAsset()
     * - Hook contract has at least 600M event tokens
     * - Pool being initialized uses this hook
     *
     * ## Process Flow
     * 1. Validates the pool uses this hook
     * 2. Emits PoolInitialized event
     * 3. Checks if bootstrap conditions are met
     * 4. If conditions met, triggers automatic bootstrap
     * 5. Returns success selector
     *
     * @param key The pool key containing currency addresses, fee, and hook information
     * @return selector The function selector confirming successful execution
     *
     * @custom:emits PoolInitialized
     * @custom:emits LiquidityBootstrapped (if bootstrap succeeds)
     * @custom:emits InitialLiquidityAdded (if bootstrap succeeds)
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

    // ============================================================================
    // CALLBACK PATTERN IMPLEMENTATION
    // ============================================================================

    /**
     * @notice Callback function executed by PoolManager during unlock operations
     * @dev This function implements the Uniswap V4 callback pattern for atomic operations.
     *      It's called by PoolManager.unlock() and handles the actual liquidity addition.
     *
     * ## Security Features
     * - Only callable by the PoolManager contract
     * - Validates callback ID to route to correct handler
     * - All operations are atomic within the unlock context
     *
     * ## Supported Operations
     * - ADD_LIQUIDITY_CALLBACK_ID: Initial liquidity addition
     *
     * @param data ABI-encoded callback data containing:
     *             - uint8 callbackId: Operation identifier
     *             - bytes contents: Operation-specific parameters
     * @return result Empty bytes on successful execution
     *
     * @custom:security Only callable by PoolManager
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

    // ============================================================================
    // VIEW FUNCTIONS
    // ============================================================================

    /**
     * @notice Get backing asset information including cached decimals
     * @return asset The backing asset address
     * @return decimals The number of decimals for the backing asset
     * @return symbol The symbol of the backing asset
     */
    function getBackingAssetInfo()
        external
        view
        returns (address asset, uint8 decimals, string memory symbol)
    {
        asset = backingAsset;
        decimals = backingAssetDecimals;
        try IERC20Metadata(backingAsset).symbol() returns (
            string memory _symbol
        ) {
            symbol = _symbol;
        } catch {
            symbol = "UNKNOWN";
        }
    }

    // ============================================================================
    // INTERNAL BOOTSTRAP LOGIC
    // ============================================================================

    /**
     * @notice Internal function to check if automatic liquidity bootstrap can proceed
     * @dev Validates that all prerequisites for liquidity addition are satisfied
     *
     * ## Bootstrap Prerequisites
     * - Organizer has deposited backing asset (backingAssetDeposited = true)
     * - Hook contract has sufficient event tokens (≥ 600M tokens)
     *
     * @return canBootstrap True if all conditions are met, false otherwise
     */
    function _canBootstrapLiquidity() internal view returns (bool) {
        return
            backingAssetDeposited &&
            IERC20(eventToken).balanceOf(address(this)) >= INITIAL_TOKEN_AMOUNT;
    }

    /**
     * @notice Internal function to execute liquidity bootstrap via callback pattern
     * @dev Initiates the Uniswap V4 unlock/callback pattern to add initial liquidity.
     *      This function prepares callback data and triggers the PoolManager unlock.
     *
     * ## Process Flow
     * 1. Encode callback data with operation ID and liquidity parameters
     * 2. Call PoolManager.unlock() to begin atomic operation
     * 3. PoolManager calls back to unlockCallback() with encoded data
     * 4. Callback handler adds liquidity using modifyLiquidity()
     * 5. Settle payments for both currencies
     *
     * @param key The pool key identifying the target pool
     *
     * @custom:emits LiquidityBootstrapped
     */
    function _performBootstrap(PoolKey calldata key) internal {
        // Create callback data for liquidity addition
        bytes memory data = abi.encode(
            ADD_LIQUIDITY_CALLBACK_ID,
            abi.encode(key, initialBackingAmount, INITIAL_TOKEN_AMOUNT)
        );

        // Use PoolManager unlock pattern
        poolManager.unlock(data);

        emit LiquidityBootstrapped(
            key,
            initialBackingAmount,
            INITIAL_TOKEN_AMOUNT
        );
    }

    /**
     * @notice Internal callback handler for initial liquidity addition
     * @dev This function performs the actual liquidity addition using Uniswap V4 primitives.
     *      It calculates optimal liquidity amounts and settles payments atomically.
     *
     * ## Liquidity Addition Process
     * 1. Decode and validate callback parameters
     * 2. Verify pool contains both required currencies
     * 3. Calculate liquidity amount using current price and full-range ticks
     * 4. Add liquidity via PoolManager.modifyLiquidity()
     * 5. Settle payments for both currencies using settle() pattern
     * 6. Emit detailed liquidity addition event
     *
     * @param contents ABI-encoded parameters containing:
     *                 - PoolKey: Pool identification and configuration
     *                 - uint256 backingAmount: Amount of backing asset to use
     *                 - uint256 tokenAmount: Amount of event tokens to use
     * @return result Empty bytes indicating successful completion
     *
     * @custom:emits InitialLiquidityAdded
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

        // Get current pool price for liquidity calculations
        (uint160 sqrtP, , , ) = poolManager.getSlot0(key.toId());

        // Calculate liquidity using current price and amounts
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
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

        // Add liquidity to the pool using calculated amounts
        (BalanceDelta delta, ) = poolManager.modifyLiquidity(
            key,
            ModifyLiquidityParams({
                tickLower: FULL_RANGE_LOWER,
                tickUpper: FULL_RANGE_UPPER,
                liquidityDelta: int256(uint256(liquidity)),
                salt: 0
            }),
            ""
        );

        // Handle payments using settle pattern
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
            liquidity,
            delta.amount0() < 0 ? uint256(uint128(-delta.amount0())) : 0,
            delta.amount1() < 0 ? uint256(uint128(-delta.amount1())) : 0,
            0, // liqBefore (simplified for this version)
            liquidity // liqAfter
        );

        return bytes("");
    }

    // ============================================================================
    // EVENTS
    // ============================================================================

    /**
     * @notice Emitted when organizer successfully deposits backing asset
     * @param organizer The address of the event organizer making the deposit
     * @param amount The amount of backing asset deposited (in backing asset decimals)
     */
    event BackingAssetDeposited(address indexed organizer, uint256 amount);

    /**
     * @notice Emitted when pool initialization is complete and hook is ready
     * @param key The pool key identifying the initialized pool
     */
    event PoolInitialized(PoolKey indexed key);

    /**
     * @notice Emitted when liquidity bootstrap process is initiated
     * @param key The pool key where liquidity is being added
     * @param backingAmount The amount of backing asset used for liquidity
     * @param tokenAmount The amount of event tokens used for liquidity
     */
    event LiquidityBootstrapped(
        PoolKey indexed key,
        uint256 backingAmount,
        uint256 tokenAmount
    );

    /**
     * @notice Emitted when initial liquidity is successfully added to the pool
     * @param key The pool key where liquidity was added
     * @param tickLower The lower tick of the liquidity position
     * @param tickUpper The upper tick of the liquidity position
     * @param liquidity The amount of liquidity added to the pool
     * @param backingAmount The actual amount of backing asset consumed
     * @param tokenAmount The actual amount of event tokens consumed
     * @param poolLiquidityBefore The pool's liquidity before this addition
     * @param poolLiquidityAfter The pool's liquidity after this addition
     */
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
