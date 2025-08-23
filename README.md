# 🎟️ UniFans

**From fans to stakeholders.**  
Trustless crowdfunding for live events powered by Uniswap v4 hooks.

## 🚀 Quick Start

### Prerequisites

- [Node.js](https://nodejs.org/) (v18+)
- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Setup

```bash
# Clone and install
git clone <your-repo>
cd unifans
npm install

# Build contracts
cd packages/contracts
forge build

# Run tests
forge test

# Start frontend (when ready)
cd ../frontend
npm run dev
```

## 📁 Project Structure

```
unifans/
├── packages/
│   ├── contracts/          # Smart contracts (EventCoinHook, EventToken)
│   │   ├── src/           # Contract source code
│   │   ├── test/          # Comprehensive test suite
│   │   └── lib/           # Dependencies (Uniswap V4, OpenZeppelin)
│   ├── frontend/           # Next.js web app (coming soon)
│   └── shared/             # Shared types & configs (coming soon)
├── package.json            # Workspace root
└── README.md               # This file
```

## 💡 What is UniFans?

UniFans converts each live event into a liquid digital asset with **continuous vesting**:

- **EventToken ($EVENT)**: Each event gets its own ERC20 token with unique metadata
- **Continuous Vesting**: Organizer tokens unlock gradually by second until event date
- **Fee Distribution**: 3% fees on all trades automatically distributed
- **Liquidity Management**: 40% of fees go to permanent liquidity, 60% to rewards
- **Transparency**: All operations on-chain and verifiable

## 🔧 Smart Contracts

### EventCoinHook.sol
- **Uniswap V4 Hook** that intercepts all swaps
- **3% fee collection** on both buy (ETH→TOKEN) and sell (TOKEN→ETH) directions
- **Asset-aware fees**: ETH fees for buys, TOKEN fees for sells
- **Automatic distribution**: 40% to liquidity, 60% to rewards (90% organizer, 10% protocol)
- **Real liquidity addition** via `poolManager.modifyLiquidity`

### EventToken.sol
- **ERC20 token** with continuous vesting per second
- **40% tokens** (400M) for organizer with vesting until event date
- **60% tokens** (600M) for contract (initial liquidity pool)
- **Secure vesting**: Override of transfer, transferFrom, and approve functions
- **Vesting tracking**: Real-time progress monitoring and information functions

## 🚀 Development

### Commands

```bash
# Build all packages
npm run build

# Test contracts
cd packages/contracts
forge test

# Build contracts
forge build

# Format Solidity code
forge fmt
```

### Smart Contracts

```bash
cd packages/contracts
forge build                # Build contracts
forge test                 # Run tests (26/26 passing)
forge test --watch         # Watch mode
forge test --gas-report    # Gas analysis
```

### Frontend (Coming Soon)

```bash
cd packages/frontend
npm run dev                # Start dev server
npm run build              # Build for production
```

## 📚 Documentation

- [Smart Contracts](./packages/contracts/README.md) - Technical details and API
- [Frontend](./packages/frontend/README.md) - Coming soon
- [Architecture](./docs/ARCHITECTURE.md) - Coming soon

## 🧪 Testing

**Current Status: 26/26 tests passing** ✅

- **EventToken**: Complete vesting mechanism testing
- **EventCoinHook**: Fee distribution and liquidity management
- **Security**: Transfer restrictions and vesting enforcement
- **Edge Cases**: Various vesting periods and scenarios

## 🤝 Contributing

Feel free to fork and experiment!

## 📄 License

MIT License
