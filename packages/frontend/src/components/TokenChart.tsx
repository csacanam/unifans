"use client";

import { useState, useEffect } from "react";

/**
 * @interface PricePoint
 * @description Represents a single price data point in the chart
 */
interface PricePoint {
  time: string;
  price: number;
}

/**
 * @component TokenChart
 * @description Interactive price chart component for displaying token price data
 * 
 * Features:
 * - Multiple timeframe selection (1H, 24H, 7D, 30D)
 * - Real-time price updates with mock data
 * - SVG-based responsive chart with gradient styling
 * - Price statistics (high, low, volatility)
 * - Smooth animations and hover effects
 * 
 * @returns {JSX.Element} Rendered token chart component
 */
export default function TokenChart() {
  const [selectedTimeframe, setSelectedTimeframe] = useState("24h");
  const [priceData, setPriceData] = useState<PricePoint[]>([]);

  /**
   * @function generateMockData
   * @description Generates mock price data for different timeframes
   * @param {string} timeframe - The selected timeframe (1h, 24h, 7d, 30d)
   * @returns {PricePoint[]} Array of price points with time and price data
   */
  const generateMockData = (timeframe: string) => {
    const data: PricePoint[] = [];
    const now = new Date();
    let points = 0;
    let interval = 0;

    // Configure data points and intervals based on timeframe
    switch (timeframe) {
      case "1h":
        points = 60;
        interval = 1;
        break;
      case "24h":
        points = 24;
        interval = 1;
        break;
      case "7d":
        points = 7;
        interval = 1;
        break;
      case "30d":
        points = 30;
        interval = 1;
        break;
      default:
        points = 24;
        interval = 1;
    }

    // Generate price data with realistic volatility
    let basePrice = 0.85;
    for (let i = points; i >= 0; i--) {
      const time = new Date(now.getTime() - i * interval * 60 * 60 * 1000);
      const volatility = (Math.random() - 0.5) * 0.1;
      basePrice = Math.max(0.1, basePrice + volatility);
      
      data.push({
        time: time.toLocaleTimeString('en-US', { 
          hour: '2-digit', 
          minute: '2-digit',
          hour12: false 
        }),
        price: parseFloat(basePrice.toFixed(4))
      });
    }

    return data;
  };

  // Update price data when timeframe changes
  useEffect(() => {
    setPriceData(generateMockData(selectedTimeframe));
  }, [selectedTimeframe]);

  // Calculate price statistics
  const maxPrice = Math.max(...priceData.map(p => p.price));
  const minPrice = Math.min(...priceData.map(p => p.price));
  const priceRange = maxPrice - minPrice;

  /**
   * @function getYPosition
   * @description Calculates Y position for price point on SVG chart
   * @param {number} price - The price value to position
   * @returns {number} Y coordinate (0-100) for SVG viewBox
   */
  const getYPosition = (price: number) => {
    if (priceRange === 0) return 50;
    return 100 - ((price - minPrice) / priceRange) * 80;
  };

  // Available timeframe options
  const timeframes = [
    { value: "1h", label: "1H" },
    { value: "24h", label: "24H" },
    { value: "7d", label: "7D" },
    { value: "30d", label: "30D" }
  ];

  return (
    <div className="bg-white dark:bg-gray-800 rounded-2xl p-6 shadow-lg">
      {/* Chart Header */}
      <div className="flex justify-between items-center mb-6">
        <h3 className="text-xl font-bold text-gray-900 dark:text-white">$SWIFTIEMX Token Price</h3>
        <div className="flex space-x-1 bg-gray-100 dark:bg-gray-700 rounded-lg p-1">
          {timeframes.map((tf) => (
            <button
              key={tf.value}
              onClick={() => setSelectedTimeframe(tf.value)}
              className={`px-3 py-1 rounded-md text-sm font-medium transition-all duration-200 ${
                selectedTimeframe === tf.value
                  ? "bg-white dark:bg-gray-600 text-purple-600 dark:text-purple-400 shadow-sm"
                  : "text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white"
              }`}
              aria-label={`Select ${tf.label} timeframe`}
            >
              {tf.label}
            </button>
          ))}
        </div>
      </div>

      {/* Current Price Display */}
      <div className="mb-6">
        <div className="text-3xl font-bold text-gray-900 dark:text-white mb-2">
          ${priceData[priceData.length - 1]?.price.toFixed(4) || "0.0000"}
        </div>
        <div className="flex items-center space-x-2">
          <span className="text-green-500 text-sm">+2.45%</span>
          <span className="text-gray-500 text-sm">in the last 24h</span>
        </div>
        <div className="mt-2 p-3 bg-purple-50 dark:bg-purple-900/20 rounded-lg">
          <p className="text-sm text-purple-700 dark:text-purple-300">
            💡 <strong>Why does the price change?</strong> The price reflects fan demand for 
            exclusive event benefits and experiences.
          </p>
        </div>
      </div>

      {/* Interactive Chart */}
      <div className="relative h-64 mb-4">
        <svg className="w-full h-full" viewBox="0 0 100 100" preserveAspectRatio="none">
          {/* Grid lines for better readability */}
          {[0, 25, 50, 75, 100].map((y) => (
            <line
              key={y}
              x1="0"
              y1={y}
              x2="100"
              y2={y}
              stroke="currentColor"
              strokeWidth="0.5"
              className="text-gray-200 dark:text-gray-700"
            />
          ))}
          
          {/* Price trend line */}
          <polyline
            fill="none"
            stroke="url(#gradient)"
            strokeWidth="2"
            points={priceData.map((point, index) => 
              `${(index / (priceData.length - 1)) * 100},${getYPosition(point.price)}`
            ).join(" ")}
          />
          
          {/* Gradient definition for line styling */}
          <defs>
            <linearGradient id="gradient" x1="0%" y1="0%" x2="0%" y2="100%">
              <stop offset="0%" stopColor="#8B5CF6" />
              <stop offset="100%" stopColor="#3B82F6" />
            </linearGradient>
          </defs>
        </svg>
      </div>

      {/* Price Statistics */}
      <div className="grid grid-cols-3 gap-4 text-center">
        <div>
          <div className="text-sm text-gray-500 dark:text-gray-400">High</div>
          <div className="text-lg font-semibold text-gray-900 dark:text-white">
            ${maxPrice.toFixed(4)}
          </div>
        </div>
        <div>
          <div className="text-sm text-gray-500 dark:text-gray-400">Low</div>
          <div className="text-lg font-semibold text-gray-900 dark:text-white">
            ${minPrice.toFixed(4)}
          </div>
        </div>
        <div>
          <div className="text-sm text-gray-500 dark:text-gray-400">Volatility</div>
          <div className="text-lg font-semibold text-gray-900 dark:text-white">
            {((priceRange / minPrice) * 100).toFixed(1)}%
          </div>
        </div>
      </div>
    </div>
  );
}