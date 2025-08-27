"use client";

import { useState } from "react";

/**
 * @interface PurchaseFormProps
 * @description Props for the PurchaseForm component
 */
interface PurchaseFormProps {
  /** Current token price in USD */
  currentPrice: number;
  /** Callback function called when purchase is initiated */
  onPurchase: (amount: number) => void;
}

/**
 * @component PurchaseForm
 * @description Interactive form component for purchasing event tokens
 * 
 * Features:
 * - Token amount input with validation
 * - Real-time total cost calculation
 * - Quick amount selection buttons
 * - Purchase simulation with loading states
 * - Responsive design with gradient styling
 * - Educational information about token benefits
 * 
 * @param {PurchaseFormProps} props - Component props
 * @returns {JSX.Element} Rendered purchase form component
 */
export default function PurchaseForm({ currentPrice, onPurchase }: PurchaseFormProps) {
  const [purchaseAmount, setPurchaseAmount] = useState("");
  const [isProcessing, setIsProcessing] = useState(false);

  /**
   * @function handlePurchase
   * @description Handles the token purchase process with simulation
   */
  const handlePurchase = async () => {
    if (!purchaseAmount || parseFloat(purchaseAmount) <= 0) return;
    
    setIsProcessing(true);
    
    // Simulate processing delay for realistic UX
    setTimeout(() => {
      onPurchase(parseFloat(purchaseAmount));
      setPurchaseAmount("");
      setIsProcessing(false);
    }, 2000);
  };

  // Calculate total cost in real-time
  const totalCost = purchaseAmount ? parseFloat(purchaseAmount) * currentPrice : 0;

  // Quick amount options for user convenience
  const quickAmounts = [10, 50, 100, 250, 500, 1000];

  return (
    <div className="bg-white dark:bg-gray-800 rounded-2xl p-6 shadow-lg">
      {/* Form Header */}
      <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-6">
        🎫 Buy Event Tokens
      </h3>
      
      {/* Educational Information */}
      <div className="mb-4 p-4 bg-green-50 dark:bg-green-900/20 rounded-xl">
        <p className="text-sm text-green-700 dark:text-green-300">
          <strong>Why buy tokens?</strong> Each token gives you access to exclusive benefits 
          like meet & greets, special merch, private soundchecks, and more unique experiences.
        </p>
      </div>
      
      <div className="space-y-4">
        {/* Token Amount Input */}
        <div>
          <label 
            htmlFor="token-amount"
            className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2"
          >
            Number of tokens to purchase
          </label>
          <div className="relative">
            <input
              id="token-amount"
              type="number"
              value={purchaseAmount}
              onChange={(e) => setPurchaseAmount(e.target.value)}
              placeholder="0.00"
              min="0"
              step="0.01"
              className="w-full px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-transparent dark:bg-gray-700 dark:text-white pr-24"
              aria-describedby="token-symbol"
            />
            <div 
              id="token-symbol"
              className="absolute right-3 top-3 text-purple-600 font-semibold pointer-events-none"
            >
              $SWIFTIEMX
            </div>
          </div>
        </div>

        {/* Price Information Panel */}
        <div className="bg-gradient-to-r from-purple-50 to-blue-50 dark:from-purple-900/20 dark:to-blue-900/20 rounded-xl p-4">
          <div className="space-y-3">
            <div className="flex justify-between items-center">
              <span className="text-gray-600 dark:text-gray-400">Price per token:</span>
              <span className="font-semibold text-gray-900 dark:text-white">
                ${currentPrice.toFixed(4)}
              </span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-gray-600 dark:text-gray-400">Quantity:</span>
              <span className="font-semibold text-gray-900 dark:text-white">
                {purchaseAmount || "0.00"} $SWIFTIEMX
              </span>
            </div>
            <div className="border-t border-gray-200 dark:border-gray-600 pt-3">
              <div className="flex justify-between items-center">
                <span className="text-lg font-semibold text-gray-900 dark:text-white">
                  Total cost:
                </span>
                <span className="text-2xl font-bold text-purple-600">
                  ${totalCost.toFixed(2)}
                </span>
              </div>
            </div>
          </div>
        </div>

        {/* Purchase Button */}
        <button
          onClick={handlePurchase}
          disabled={!purchaseAmount || parseFloat(purchaseAmount) <= 0 || isProcessing}
          className="w-full bg-gradient-to-r from-purple-600 to-blue-600 text-white py-4 rounded-xl font-semibold text-lg hover:from-purple-700 hover:to-blue-700 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center space-x-2"
          aria-label={isProcessing ? "Processing purchase" : "Purchase tokens"}
        >
          {isProcessing ? (
            <>
              <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
              <span>Processing...</span>
            </>
          ) : (
            <>
              <span>🎫</span>
              <span>Buy Tokens</span>
            </>
          )}
        </button>

        {/* Information Text */}
        <div className="text-center text-sm text-gray-500 dark:text-gray-400">
          <p>Tokens will be transferred to your wallet immediately after purchase.</p>
        </div>
      </div>

      {/* Quick Amount Selection */}
      <div className="mt-6">
        <p className="text-sm text-gray-600 dark:text-gray-400 mb-3">Quick amounts:</p>
        <div className="grid grid-cols-3 gap-2">
          {quickAmounts.map((amount) => (
            <button
              key={amount}
              onClick={() => setPurchaseAmount(amount.toString())}
              className="px-3 py-2 text-sm border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors focus:ring-2 focus:ring-purple-500 focus:border-transparent"
              aria-label={`Set amount to ${amount} tokens`}
            >
              {amount}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}