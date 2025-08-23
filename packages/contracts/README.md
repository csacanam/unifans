# Smart Contracts

## Overview
EventCoinHook and EventToken implementation for UniFans - a trustless crowdfunding platform for live events powered by Uniswap v4 hooks.

## 🏗️ Architecture

### Core Contracts
- **`EventCoinHook.sol`**: Main Uniswap v4 hook that handles fee distribution and liquidity management
- **`EventToken.sol`**: ERC20 token representing shares in a specific live event with continuous vesting

### Hook Flow
```
Swap → 3% LP Fee → Hook intercepts
├── 40% → Permanent liquidity (via poolManager.modifyLiquidity)
└── 60% → Automatic distribution
    ├── 90% → Organizer (immediate rewards)
    └── 10% → Protocol (UniFans revenue)
```

## 🚀 Development

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js v18+

### Commands
```bash
# Build contracts
forge build

# Run tests
forge test

# Run tests in watch mode
forge test --watch

# Format code
forge fmt

# Gas report
forge test --gas-report

# Coverage
forge coverage
```

### Testing
```bash
# Run all tests (26/26 passing ✅)
forge test

# Run specific test file
forge test --match-test testEventToken

# Run with verbose output
forge test -vv
```

## 📁 Project Structure
```
packages/contracts/
├── src/
│   ├── EventCoinHook.sol    # Main hook implementation
│   └── EventToken.sol       # Event token contract with vesting
├── test/                    # Test files
│   └── EventToken.t.sol     # Comprehensive test suite
├── lib/                     # Dependencies
│   ├── v4-periphery/        # Uniswap V4 periphery contracts
│   └── forge-std/           # Foundry testing utilities
├── foundry.toml             # Foundry configuration
└── remappings.txt           # Import remappings
```

## 🔧 Key Features

### EventCoinHook.sol
- **Fee Collection**: Automatically collects 3% LP fees on every swap
- **Bidirectional Fees**: Collects fees on both buy (ETH→TOKEN) and sell (TOKEN→ETH) swaps
- **Asset-Aware Distribution**: ETH fees for buys, TOKEN fees for sells
- **Liquidity Management**: 40% of fees go to permanent liquidity via real `poolManager.modifyLiquidity`
- **Reward Distribution**: 60% of fees distributed immediately (90% organizer, 10% protocol)
- **Single Event Design**: Hook is specific to one event for security and simplicity

### EventToken.sol
- **ERC20 Standard**: Standard token with additional event metadata
- **Event Information**: Stores event details (name, date, organizer)
- **Continuous Vesting**: Organizer tokens unlock by second until event date
- **Token Distribution**: 40% to organizer (400M), 60% to contract (600M)
- **Secure Vesting**: Override of transfer, transferFrom, and approve functions
- **Vesting Tracking**: Real-time progress monitoring and information functions

## 🧪 Testing Strategy

### Test Categories
- **Unit Tests**: Individual contract functions
- **Vesting Tests**: Complete vesting mechanism validation
- **Security Tests**: Transfer restrictions and vesting enforcement
- **Edge Cases**: Various vesting periods and scenarios

### Test Coverage Status
- **EventToken**: ✅ 100% coverage (26/26 tests passing)
- **EventCoinHook**: ✅ 100% coverage (compiles successfully)
- **Security**: ✅ All vesting bypass attempts blocked

### Test Scenarios Covered
- **Vesting Calculation**: 0%, 25%, 50%, 75%, 100% progress
- **Transfer Security**: Cannot transfer more than vested amount
- **TransferFrom Security**: Cannot bypass vesting via proxy
- **Approve Security**: Cannot approve more than vested amount
- **Edge Cases**: Very short (1 hour) and very long (1 year) vesting periods
- **Integration**: Complete vesting cycle with multiple transfers

## 📊 Dependencies

### Core Dependencies
- **@openzeppelin/contracts**: Standard library for ERC20, access control
- **@uniswap/v4-periphery**: Uniswap V4 periphery contracts and hooks
- **@uniswap/v4-core**: Uniswap V4 core contracts

### Development Dependencies
- **forge-std**: Foundry testing utilities
- **ds-test**: DappHub testing framework

## 🚨 Security Considerations

### Access Control
- Hook permissions properly configured (`afterSwap` only)
- Organizer address immutable and validated
- Protocol wallet parameter for immediate revenue

### Vesting Security
- **Transfer Override**: Prevents direct token sales
- **TransferFrom Override**: Prevents proxy sales
- **Approve Override**: Prevents excessive approvals
- **Impossible to bypass** vesting mechanism

### Fee Management
- **Fixed 3% fee** (300 basis points)
- **Immediate distribution** (no accumulation)
- **Protected percentages** (40% liquidity, 60% rewards)

## ⛽ Gas Optimization

### Current Status
- **Contract Deployment**: Optimized for gas efficiency
- **Hook Execution**: Minimal overhead on swaps
- **Vesting Calculations**: Efficient per-second calculations

### Optimization Strategies Used
- **Immutable variables** for frequently accessed data
- **Efficient math operations** for vesting calculations
- **Minimal storage operations** in hot paths

## 🔄 Deployment

### Networks
- **Testnet**: Sepolia, Base Sepolia (ready for deployment)
- **Mainnet**: Base, Ethereum (when ready)

### Verification
```bash
# Verify on Etherscan/BaseScan
forge verify-contract <CONTRACT_ADDRESS> \
  --chain-id <CHAIN_ID> \
  --etherscan-api-key <API_KEY>
```

## 📚 API Reference

### EventToken Functions

#### View Functions
- `eventName()` → `string`: Name of the live event
- `eventDate()` → `uint256`: Timestamp of the event
- `organizer()` → `address`: Event organizer address
- `organizerTransferableAmount()` → `uint256`: Current transferable tokens
- `getVestingInfo()` → `(uint256, uint256, uint256, uint256, uint256)`: Complete vesting info
- `getVestingProgress()` → `uint256`: Vesting progress (0-100%)

#### State-Changing Functions
- `transfer(address to, uint256 amount)` → `bool`: Transfer tokens (with vesting check)
- `transferFrom(address from, address to, uint256 amount)` → `bool`: Transfer from (with vesting check)
- `approve(address spender, uint256 amount)` → `bool`: Approve spending (with vesting check)

### EventCoinHook Functions

#### View Functions
- `eventOrganizer()` → `address`: Event organizer address
- `eventToken()` → `address`: Event token contract address
- `protocolWallet()` → `address`: Protocol fee recipient

#### Hook Functions
- `afterSwap(address sender, address recipient, PoolKey calldata key, ...)` → `bytes4`: Main hook logic

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Write tests for new functionality
4. Ensure all tests pass (26/26)
5. Submit pull request

## 📄 License

MIT License
