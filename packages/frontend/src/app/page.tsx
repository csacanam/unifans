"use client";

import { useState } from "react";
import PurchaseForm from "../components/PurchaseForm";
import Notification from "../components/Notification";

/**
 * @interface EventData
 * @description Type definition for event information and token metrics
 */
interface EventData {
  name: string;
  date: string;
  location: string;
  promoter: string;
  description: string;
  tokenSymbol: string;
  currentPrice: number;
  totalSupply: number;
  organizerTokens: number;
  unlockedTokens: number;
  remainingToUnlock: number;
  availableForPurchase: number;
  raised: number;
  goal: number;
  holders: number;
  minInterest: number;
  daysLeft: number;
}

/**
 * @interface NotificationState
 * @description Type definition for notification component state
 */
interface NotificationState {
  message: string;
  type: "success" | "error" | "info";
  isVisible: boolean;
}

/**
 * @component Home
 * @description Main landing page component for UniFans application
 * 
 * Features:
 * - Event showcase with hero section
 * - Pre-support progress tracking
 * - Token purchase functionality
 * - Educational content about the platform
 * - Responsive design with dark mode support
 * - Interactive notifications
 * - FAQ section for user guidance
 * 
 * The page demonstrates a pre-support model where fans can show interest
 * in events before they're confirmed, helping promoters validate demand.
 * 
 * @returns {JSX.Element} Complete home page with all sections
 */
export default function Home() {
  // Component state management
  const [isCreatingAccount, setIsCreatingAccount] = useState(false);
  const [notification, setNotification] = useState<NotificationState>({
    message: "",
    type: "info",
    isVisible: false
  });

  /**
   * Mock event data for demonstration purposes
   * In production, this would come from an API or blockchain
   */
  const eventData: EventData = {
    name: "Taylor Swift - The Eras Tour",
    date: "December 15, 2024",
    location: "Azteca Stadium, Mexico City",
    promoter: "Páramo Presenta",
    description: "A magical night with Taylor Swift on her most anticipated world tour. Be part of history by buying event tokens and join the most passionate fan community in the world.",
    tokenSymbol: "SWIFTIEMX",
    currentPrice: 0.85,
    totalSupply: 1000000000, // 1 billion total tokens
    organizerTokens: 400000000, // 400M organizer tokens
    unlockedTokens: 150000000,  // Already unlocked
    remainingToUnlock: 250000000, // Still to unlock
    availableForPurchase: 600000000, // 600M available for purchase
    raised: 450000000, // 450M already purchased by community
    goal: 600000000, // Goal: 600M for community
    holders: 2847,
    minInterest: 500000000, // 500M tokens needed to confirm event
    daysLeft: 15
  };

  /**
   * @function handleCreateAccount
   * @description Simulates account creation process with loading state
   */
  const handleCreateAccount = (): void => {
    setIsCreatingAccount(true);
    setTimeout(() => {
      setIsCreatingAccount(false);
      showNotification("Account created successfully!", "success");
    }, 2000);
  };

  /**
   * @function handlePurchase
   * @description Handles token purchase and shows success notification
   * @param {number} amount - Number of tokens purchased
   */
  const handlePurchase = (amount: number): void => {
    const totalCost = amount * eventData.currentPrice;
    showNotification(
      `Purchase successful! You bought ${amount} $SWIFTIEMX tokens for $${totalCost.toFixed(2)}`, 
      "success"
    );
  };

  /**
   * @function showNotification
   * @description Displays a notification with specified message and type
   * @param {string} message - Message to display
   * @param {"success" | "error" | "info"} type - Notification type
   */
  const showNotification = (message: string, type: "success" | "error" | "info"): void => {
    setNotification({
      message,
      type,
      isVisible: true
    });
  };

  /**
   * @function closeNotification
   * @description Hides the currently visible notification
   */
  const closeNotification = (): void => {
    setNotification(prev => ({ ...prev, isVisible: false }));
  };

  // Calculate progress percentages for visual indicators
  const progressPercentage = (eventData.raised / eventData.goal) * 100;
  const interestPercentage = (eventData.raised / eventData.minInterest) * 100;

  return (
    <div className="min-h-screen bg-gradient-to-br from-purple-50 via-blue-50 to-indigo-100 dark:from-gray-900 dark:via-purple-900 dark:to-indigo-900">
      {/* Global Notification System */}
      <Notification
        message={notification.message}
        type={notification.type}
        isVisible={notification.isVisible}
        onClose={closeNotification}
      />

      {/* Application Header */}
      <header className="bg-white/80 dark:bg-gray-900/80 backdrop-blur-md border-b border-gray-200 dark:border-gray-700 sticky top-0 z-50">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-4">
            {/* Brand Logo and Name */}
            <div className="flex items-center space-x-3">
              <div className="w-10 h-10 bg-gradient-to-r from-purple-600 to-blue-600 rounded-full flex items-center justify-center">
                <span className="text-white font-bold text-lg" aria-hidden="true">U</span>
              </div>
              <span className="text-xl font-bold text-gray-900 dark:text-white">UniFans</span>
            </div>
            
            {/* Account Creation Button */}
            <button
              onClick={handleCreateAccount}
              disabled={isCreatingAccount}
              className="bg-gradient-to-r from-purple-600 to-blue-600 text-white px-6 py-2 rounded-full font-medium hover:from-purple-700 hover:to-blue-700 transition-all duration-200 disabled:opacity-50 flex items-center space-x-2 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2"
              aria-label={isCreatingAccount ? "Creating account..." : "Create account"}
            >
              {isCreatingAccount ? (
                <>
                  <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                  <span>Creating account...</span>
                </>
              ) : (
                <>
                  <span aria-hidden="true">👤</span>
                  <span>Create Account</span>
                </>
              )}
            </button>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Event Hero Section */}
        <section className="bg-white dark:bg-gray-800 rounded-3xl shadow-xl overflow-hidden mb-8">
          <div className="relative h-80 bg-gradient-to-r from-purple-600 via-pink-600 to-red-600">
            <div className="absolute inset-0 bg-black/20"></div>
            <div className="absolute inset-0 flex items-center justify-center">
              <div className="text-center text-white px-4">
                <h1 className="text-4xl md:text-6xl font-bold mb-4">{eventData.name}</h1>
                <p className="text-xl md:text-2xl mb-2">{eventData.date}</p>
                <p className="text-lg md:text-xl opacity-90">{eventData.location}</p>
              </div>
            </div>
          </div>
          <div className="p-8">
            <div className="flex items-center justify-center mb-4 space-x-2">
              <span className="text-gray-700 dark:text-gray-300 font-medium">
                Promoter: {eventData.promoter}
              </span>
              <div className="bg-blue-500 text-white w-5 h-5 rounded-full flex items-center justify-center">
                <span className="text-xs" aria-label="Verified">✓</span>
              </div>
            </div>
            <p className="text-gray-600 dark:text-gray-300 text-lg leading-relaxed text-center">
              This is a <strong>pre-support</strong> to validate interest in bringing Taylor Swift. 
              Buy tokens to show your interest and receive exclusive benefits <strong>only if the event is confirmed</strong>.
            </p>
          </div>
        </section>

        {/* Pre-Support Status Section */}
        <section className="bg-white dark:bg-gray-800 rounded-2xl p-8 shadow-lg mb-8">
          <h2 className="text-2xl font-bold text-gray-900 dark:text-white mb-6 text-center">
            Pre-Support Status
          </h2>
          
          {/* Interest Progress Bar */}
          <div className="mb-6">
            <div className="flex justify-between text-sm text-gray-600 dark:text-gray-400 mb-2">
              <span>
                Interest shown: {eventData.raised.toLocaleString('en-US')} / {eventData.minInterest.toLocaleString('en-US')} tokens
              </span>
              <span>{interestPercentage.toFixed(1)}%</span>
            </div>
            <div className="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-4 mb-2">
              <div 
                className="bg-gradient-to-r from-orange-500 to-red-500 h-4 rounded-full transition-all duration-1000"
                style={{ width: `${Math.min(interestPercentage, 100)}%` }}
                role="progressbar"
                aria-valuenow={interestPercentage}
                aria-valuemin={0}
                aria-valuemax={100}
                aria-label={`${interestPercentage.toFixed(1)}% interest shown for event confirmation`}
              ></div>
            </div>
            <p className="text-sm text-gray-500 dark:text-gray-400 text-center">
              {interestPercentage >= 100 ? 
                "Interest confirmed! The event will take place." : 
                `${(eventData.minInterest - eventData.raised).toLocaleString('en-US')} more tokens needed to confirm the event`
              }
            </p>
          </div>

          {/* Event Statistics */}
          <div className="grid grid-cols-3 gap-6 text-center">
            <div>
              <div className="text-3xl font-bold text-green-600 mb-2">
                {eventData.holders.toLocaleString('en-US')}
              </div>
              <div className="text-sm text-gray-500 dark:text-gray-400">Supporting Fans</div>
            </div>
            <div>
              <div className="text-3xl font-bold text-blue-600 mb-2">
                ${eventData.currentPrice}
              </div>
              <div className="text-sm text-gray-500 dark:text-gray-400">Price per Token</div>
            </div>
            <div>
              <div className="text-3xl font-bold text-purple-600 mb-2">
                {eventData.daysLeft}
              </div>
              <div className="text-sm text-gray-500 dark:text-gray-400">Days Remaining</div>
            </div>
          </div>
        </section>

        {/* What Happens Next Section */}
        <section className="bg-white dark:bg-gray-800 rounded-2xl p-8 shadow-lg mb-8">
          <h2 className="text-2xl font-bold text-gray-900 dark:text-white mb-6 text-center">
            What Happens Next?
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="text-center">
              <div className="w-16 h-16 bg-orange-100 dark:bg-orange-900/30 rounded-full flex items-center justify-center mx-auto mb-4">
                <span className="text-2xl" aria-hidden="true">🎯</span>
              </div>
              <h3 className="text-lg font-semibold mb-2">If Event is Confirmed</h3>
              <p className="text-gray-600 dark:text-gray-400">
                You receive all benefits: meet & greets, exclusive merch, private soundchecks, and more
              </p>
            </div>
            <div className="text-center">
              <div className="w-16 h-16 bg-blue-100 dark:bg-blue-900/30 rounded-full flex items-center justify-center mx-auto mb-4">
                <span className="text-2xl" aria-hidden="true">💎</span>
              </div>
              <h3 className="text-lg font-semibold mb-2">If Event is Not Confirmed</h3>
              <p className="text-gray-600 dark:text-gray-400">
                You can sell your tokens on the secondary market or keep them for future events
              </p>
            </div>
          </div>
        </section>

        {/* Token Purchase Form */}
        <section className="bg-white dark:bg-gray-800 rounded-2xl shadow-lg mb-8">
          <PurchaseForm 
            currentPrice={eventData.currentPrice}
            onPurchase={handlePurchase}
          />
        </section>

        {/* FAQ Section */}
        <section className="bg-white dark:bg-gray-800 rounded-2xl p-8 shadow-lg">
          <h2 className="text-2xl font-bold text-gray-900 dark:text-white mb-6 text-center">
            Frequently Asked Questions
          </h2>
          <div className="space-y-4">
            <div className="border-b border-gray-200 dark:border-gray-700 pb-4">
              <h3 className="font-semibold text-gray-900 dark:text-white mb-2">
                What is pre-support?
              </h3>
              <p className="text-gray-600 dark:text-gray-400">
                It's a way to show your interest in an event before it's confirmed. You help the promoter validate if there's enough demand.
              </p>
            </div>
            <div className="border-b border-gray-200 dark:border-gray-700 pb-4">
              <h3 className="font-semibold text-gray-900 dark:text-white mb-2">
                When do I receive my benefits?
              </h3>
              <p className="text-gray-600 dark:text-gray-400">
                Only if the event is confirmed. If it's not confirmed, you can sell your tokens or keep them.
              </p>
            </div>
            <div>
              <h3 className="font-semibold text-gray-900 dark:text-white mb-2">
                Can I sell my tokens?
              </h3>
              <p className="text-gray-600 dark:text-gray-400">
                Yes, you can sell them to other fans on the secondary market at any time.
              </p>
            </div>
          </div>
        </section>
      </main>

      {/* Application Footer */}
      <footer className="bg-gray-50 dark:bg-gray-800/50 border-t border-gray-200 dark:border-gray-700 mt-16">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div className="text-center text-gray-600 dark:text-gray-400">
            <p>© 2024 UniFans. Connecting fans with events through tokens.</p>
          </div>
        </div>
      </footer>
    </div>
  );
}