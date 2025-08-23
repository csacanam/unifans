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
npm run build --workspace=contracts

# Start frontend
npm run dev --workspace=frontend
```

## 📁 Project Structure

```
unifans/
├── packages/
│   ├── contracts/          # Smart contracts (EventCoinHook, EventToken)
│   ├── frontend/           # Next.js web app
│   └── shared/             # Shared types & configs
├── package.json            # Workspace root
└── README.md               # This file
```

## 💡 What is UniFans?

UniFans converts each live event into a liquid digital asset:

- **EventToken ($EVENT)**: Each show emits tokens in a Uniswap v4 pool
- **Early Funding**: Organizers receive USDC immediately on each trade
- **Liquidity**: Pool maintains automatic liquidity for secondary market
- **Transparency**: All fee distributions are on-chain and verifiable

## 🔧 Development

### Commands

```bash
npm run build              # Build all packages
npm run test               # Test contracts
npm run dev                # Start frontend dev server
npm run format             # Format Solidity code
```

### Smart Contracts

```bash
cd packages/contracts
forge build                # Build contracts
forge test                 # Run tests
forge test --watch         # Watch mode
```

### Frontend

```bash
cd packages/frontend
npm run dev                # Start dev server
npm run build              # Build for production
```

## 📚 Documentation

- [Smart Contracts](./packages/contracts/README.md)
- [Frontend](./packages/frontend/README.md)
- [Architecture](./docs/ARCHITECTURE.md)

## 🎪 Hackathon Scope (10 hours)

MVP features:

- ✅ Basic EventCoinHook with fee distribution
- ✅ EventToken deployment
- ✅ Pool initialization with liquidity
- ✅ Simple frontend for buying $EVENT
- ✅ Real-time payout tracking

## 🤝 Contributing

This is a hackathon project. Feel free to fork and experiment!

## 📄 License

MIT License
