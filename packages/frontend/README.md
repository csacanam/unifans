# UniFans Frontend

A modern and elegant web application connecting fans with events through tokens. This is the first version of UniFans UI, designed for regular users (not crypto bros) with an exceptional user experience.

## 🚀 Features

### Demo Event

- **Event**: Taylor Swift - The Eras Tour
- **Date**: December 15, 2024
- **Location**: Azteca Stadium, Mexico City
- **Token**: $SWIFTIEMX

### Core Functionalities

#### 📊 Token Metrics

- Current token price
- Real-time market cap
- 24h trading volume
- Number of active holders

#### 📈 Interactive Price Chart

- Multiple timeframes (1H, 24H, 7D, 30D)
- Real-time simulated data
- Price statistics (high, low, volatility)
- Responsive SVG chart with gradients

#### 💰 Purchase System

- Intuitive purchase form
- Automatic price calculation
- Quick amount buttons
- Input validation
- Transaction simulation

#### 🔓 Unlock Progress

- Organizer token progress visualization
- Unlocked vs. pending tokens
- Upcoming unlock schedule
- Animated progress bars

#### 🎯 Event Information

- Complete event details
- Community statistics
- Tokens in circulation
- Holder benefits

## 🛠️ Technologies Used

- **Framework**: Next.js 15 with App Router
- **Language**: TypeScript
- **Styling**: Tailwind CSS v4
- **State**: React Hooks
- **Web3**: Wagmi + Viem (ready for integration)
- **Animations**: Custom CSS + Tailwind
- **Responsive**: Mobile-first design

## 🎨 Design and UX

### Design Principles

- **User-Friendly**: Intuitive interface for regular users
- **Modern**: Contemporary design with gradients and shadows
- **Responsive**: Works perfectly on all devices
- **Accessible**: Proper contrast and clear navigation
- **Animations**: Smooth transitions and hover effects

### Color Palette

- **Primary**: Purple (#8B5CF6) and Blue (#3B82F6)
- **Secondary**: Pink (#EC4899) and Green (#10B981)
- **Neutral**: Grays for text and backgrounds
- **Gradients**: Attractive combinations for key elements

## 📱 Main Components

### 1. TokenChart

- Interactive price chart
- Multiple timeframes
- Real-time statistics
- Smooth animations

### 2. PurchaseForm

- Intuitive purchase form
- Input validation
- Automatic price calculation
- Quick amount buttons

### 3. UnlockProgress

- Unlock progress visualization
- Unlock schedule
- Animated progress bars
- Detailed statistics

### 4. Notification

- Notification system
- Multiple types (success, error, info)
- Auto-dismiss with timer
- Fixed positioning

## 🚀 Installation and Usage

### Prerequisites

- Node.js 18+
- npm or yarn

### Installation

```bash
cd packages/frontend
npm install
```

### Development

```bash
npm run dev
```

The application will be available at `http://localhost:3000`

### Production Build

```bash
npm run build
npm start
```

## 📁 Project Structure

```
src/
├── app/
│   ├── globals.css          # Global styles and animations
│   ├── layout.tsx           # Main layout
│   └── page.tsx             # Main page
├── components/
│   ├── TokenChart.tsx       # Price chart
│   ├── PurchaseForm.tsx     # Purchase form
│   ├── UnlockProgress.tsx   # Unlock progress
│   └── Notification.tsx     # Notification system
```

## 🎯 Next Steps

### Web3 Integration

- Connect with real wallets (MetaMask, WalletConnect)
- Integrate with smart contracts
- Real blockchain transactions

### Additional Features

- Authentication system
- User profile
- Transaction history
- Live chat between fans
- Rewards system

### UX Improvements

- Dark/light mode toggle
- Internationalization (i18n)
- PWA capabilities
- Push notifications

## 🤝 Contributing

This is an actively developed project. Contributions are welcome:

1. Fork the project
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## 📄 License

This project is under the MIT license. See `LICENSE` for more details.

## 🎉 Acknowledgments

Built with ❤️ for the live events fan community.

---

**UniFans** - Connecting fans with events through tokens.
