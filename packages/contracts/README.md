# 🎪 UniFans Smart Contracts

Smart contracts for the UniFans platform - a decentralized event tokenization system with continuous vesting and Uniswap V4 integration.

## 📋 Overview

UniFans allows event organizers to create ERC20 tokens with built-in vesting mechanisms and automatic fee distribution through Uniswap V4 hooks.

## 🏗️ Architecture

### Core Contracts

- **EventToken.sol**: ERC20 token with continuous vesting per second
- **EventCoinHook.sol**: Uniswap V4 hook for fee collection and distribution

### Token Distribution

- **40%** to organizer (with vesting until event date)
- **60%** to contract (for initial liquidity)

### Fee Structure

- **3% fee** on all swaps (buy/sell)
- **40%** to permanent liquidity
- **60%** to rewards: 90% organizer, 10% protocol

## 🚀 Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/) (latest version)
- [Anvil](https://book.getfoundry.sh/anvil/) for local testing

### Local Testing

1. **Start Anvil** (in a new terminal):

```bash
anvil
```

2. **Test the contracts**:

```bash
# Test EventToken functionality
forge script script/TestLocal.s.sol:TestEventTokenOnlyScript \
    --rpc-url http://localhost:8545 \
    --broadcast \
    --gas-limit 30000000
```

### Build & Deploy

```bash
# Build contracts
forge build

# Deploy (update parameters in Deploy.s.sol first)
forge script script/Deploy.s.sol:DeployScript \
    --rpc-url <YOUR_RPC_URL> \
    --broadcast \
    --verify
```

## 🧪 Testing

### Current Status

- **EventToken**: ✅ Fully tested and working
- **EventCoinHook**: 🔧 Ready for Uniswap V4 integration

### Test Coverage

- ✅ Constructor and parameter validation
- ✅ Token distribution (40/60 split)
- ✅ Continuous vesting mechanism
- ✅ Transfer restrictions
- ✅ Time manipulation with `vm.warp()`
- ✅ Vesting progress calculation

## 📁 Project Structure

```
packages/contracts/
├── src/
│   ├── EventToken.sol          # Main token contract
│   └── EventCoinHook.sol       # Uniswap V4 hook
├── script/
│   ├── Deploy.s.sol            # Production deployment
│   └── TestLocal.s.sol         # Local testing
├── test/
│   └── EventToken.t.sol        # Comprehensive tests
└── README.md                   # This file
```

## 🔧 Configuration

### EventToken Parameters

- **Event Name**: Human-readable event name
- **Token Symbol**: 3-5 character symbol
- **Event Date**: Unix timestamp when event occurs
- **Organizer**: Address receiving 40% of tokens

### EventCoinHook Parameters

- **PoolManager**: Uniswap V4 PoolManager address
- **Event Organizer**: Same as EventToken
- **Event Token**: Deployed EventToken address
- **Protocol Wallet**: Address receiving 10% of fees

## 🚨 Security Features

- **Vesting Security**: All transfer functions override to enforce vesting
- **Access Control**: Only organizer can access organizer-specific functions
- **Input Validation**: Comprehensive parameter validation
- **Reentrancy Protection**: Safe external calls

## 📚 Dependencies

- **OpenZeppelin**: ERC20, Ownable
- **Uniswap V4**: BaseHook, IPoolManager
- **Foundry**: Testing and deployment tools

## 🎯 Next Steps

1. **Test EventCoinHook** with real Uniswap V4 environment
2. **Deploy to testnet** (Sepolia, Base Sepolia)
3. **Integrate frontend** for user interaction
4. **Audit contracts** for production readiness

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details.

---

**🎉 Happy Building!** Your UniFans event is ready to go live! 🚀
