# Smart Contracts

## Overview
EventCoinHook and EventToken implementation for UniFans - a trustless crowdfunding platform for live events powered by Uniswap v4 hooks.

## ��️ Architecture

### Core Contracts
- **`EventCoinHook.sol`**: Main Uniswap v4 hook that handles fee distribution and liquidity management
- **`EventToken.sol`**: ERC20 token representing shares in a specific live event
- **`interfaces/`**: Contract interfaces and type definitions
- **`libs/`**: Reusable libraries for liquidity and rewards management

### Hook Flow
Swap → 3% LP Fee → Hook intercepts
├── 40% → Liquidez permanente (locked depth)
└── 60% → Distribución automática
├── 90% → Organizador (flujo temprano)
└── 10% → Protocolo (UniFans)


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
# Run all tests
npm run test

# Run specific test file
forge test --match-test testEventToken

# Run with verbose output
forge test -vv
```

## 📁 Project Structure
packages/contracts/
├── src/
│ ├── EventCoinHook.sol # Main hook implementation
│ ├── EventToken.sol # Event token contract
│ ├── interfaces/ # Contract interfaces
│ │ ├── IEventCoinHook.sol
│ │ └── IEventToken.sol
│ ├── libs/ # Reusable libraries
│ │ ├── EventRewards.sol # Fee distribution logic
│ │ └── LiquidityManager.sol # Liquidity management
│ └── types/ # Custom types and structs
├── test/ # Test files
│ ├── EventCoinHook.t.sol
│ └── EventToken.t.sol
├── script/ # Deployment scripts
├── foundry.toml # Foundry configuration
└── package.json # Dependencies


## 🔧 Key Features

### EventCoinHook
- **Fee Collection**: Automatically collects LP fees on every swap
- **Liquidity Management**: Maintains permanent liquidity for market depth
- **Reward Distribution**: Distributes fees to organizer and protocol
- **Uniswap V4 Integration**: Full compatibility with V4 pools

### EventToken
- **ERC20 Standard**: Standard token with additional event metadata
- **Event Information**: Stores event details (date, venue, organizer)
- **Supply Management**: Fixed supply with vesting for organizer
- **Metadata URI**: Links to off-chain event information

## �� Testing Strategy

### Test Categories
- **Unit Tests**: Individual contract functions
- **Integration Tests**: Hook + Token interaction
- **Gas Tests**: Performance optimization
- **Edge Cases**: Boundary conditions and error handling

### Test Coverage Goals
- **EventCoinHook**: 95%+ coverage
- **EventToken**: 90%+ coverage
- **Libraries**: 85%+ coverage

## 📊 Dependencies

### Core Dependencies
- **@openzeppelin/contracts**: Standard library for ERC20, access control
- **@uniswap/v4-core**: Uniswap V4 core contracts
- **@uniswap/v4-periphery**: V4 periphery contracts and hooks

### Development Dependencies
- **forge-std**: Foundry testing utilities
- **ds-test**: DappHub testing framework

## 🚨 Security Considerations

### Access Control
- Hook permissions properly configured
- Admin functions protected
- Emergency pause functionality

### Reentrancy Protection
- All external calls protected
- State changes before external calls
- ReentrancyGuard implementation

### Fee Management
- Fee percentages capped
- Slippage protection
- Emergency fee adjustment

## �� Gas Optimization

### Strategies
- **Batch Operations**: Combine multiple operations
- **Storage Packing**: Optimize storage layout
- **External Calls**: Minimize expensive operations
- **Loop Optimization**: Efficient iteration patterns

### Gas Targets
- **Hook Deployment**: < 2M gas
- **Swap Execution**: < 200K gas overhead
- **Token Transfer**: < 50K gas

## 🔄 Deployment

### Networks
- **Testnet**: Sepolia, Base Sepolia
- **Mainnet**: Base, Ethereum (future)

### Verification
```bash
# Verify on Etherscan/BaseScan
forge verify-contract <CONTRACT_ADDRESS> \
  --chain-id <CHAIN_ID> \
  --etherscan-api-key <API_KEY>
```

## �� Documentation

- [Architecture Overview](../docs/ARCHITECTURE.md)
- [Hook Integration Guide](../docs/HOOK_INTEGRATION.md)
- [Testing Guide](../docs/TESTING.md)
- [Deployment Guide](../docs/DEPLOYMENT.md)

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit pull request

## 📄 License

MIT License
