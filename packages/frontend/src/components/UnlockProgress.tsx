"use client";

/**
 * @interface UnlockProgressProps
 * @description Props for the UnlockProgress component
 */
interface UnlockProgressProps {
  /** Number of tokens already unlocked and available */
  unlockedTokens: number;
  /** Number of tokens still locked and waiting to be unlocked */
  remainingToUnlock: number;
  /** Total number of tokens allocated to the organizer */
  totalOrganizerTokens: number;
}

/**
 * @component UnlockProgress
 * @description Displays the progress of organizer token unlocking over time
 * 
 * Features:
 * - Visual progress bar with percentage completion
 * - Detailed breakdown of unlocked vs remaining tokens
 * - Educational information about gradual unlocking
 * - Animated progress visualization
 * - Responsive design with gradient styling
 * 
 * The gradual unlocking mechanism helps maintain token price stability
 * by preventing large sell-offs that could harm the fan community.
 * 
 * @param {UnlockProgressProps} props - Component props
 * @returns {JSX.Element} Rendered unlock progress component
 */
export default function UnlockProgress({ 
  unlockedTokens, 
  remainingToUnlock, 
  totalOrganizerTokens 
}: UnlockProgressProps) {
  // Calculate percentages for progress visualization
  const unlockPercentage = (unlockedTokens / totalOrganizerTokens) * 100;
  const remainingPercentage = (remainingToUnlock / totalOrganizerTokens) * 100;

  /**
   * @function formatTokenAmount
   * @description Formats large token numbers with proper locale formatting
   * @param {number} amount - The token amount to format
   * @returns {string} Formatted number string with thousand separators
   */
  const formatTokenAmount = (amount: number): string => {
    return amount.toLocaleString('en-US');
  };

  return (
    <div className="bg-white dark:bg-gray-800 rounded-2xl p-6 shadow-lg">
      {/* Component Header */}
      <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-4">
        🔒 Organizer Tokens
      </h3>
      
      {/* Educational Information */}
      <div className="mb-4 p-4 bg-blue-50 dark:bg-blue-900/20 rounded-xl">
        <p className="text-sm text-blue-700 dark:text-blue-300">
          <strong>Why are tokens unlocked gradually?</strong><br/>
          To maintain stable pricing and prevent sudden drops that could affect all fans.
        </p>
      </div>
      
      {/* Main Progress Bar */}
      <div className="mb-6">
        <div className="flex justify-between text-sm text-gray-600 dark:text-gray-400 mb-2">
          <span>Unlock Progress</span>
          <span>{unlockPercentage.toFixed(1)}%</span>
        </div>
        <div className="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-4 relative overflow-hidden">
          <div 
            className="bg-gradient-to-r from-green-500 to-blue-500 h-4 rounded-full transition-all duration-1000 ease-out"
            style={{ width: `${unlockPercentage}%` }}
            role="progressbar"
            aria-valuenow={unlockPercentage}
            aria-valuemin={0}
            aria-valuemax={100}
            aria-label={`${unlockPercentage.toFixed(1)}% of organizer tokens unlocked`}
          ></div>
        </div>
      </div>

      {/* Token Distribution Breakdown */}
      <div className="space-y-4">
        {/* Unlocked Tokens */}
        <div className="flex items-center justify-between p-4 bg-gradient-to-r from-green-50 to-emerald-50 dark:from-green-900/20 dark:to-emerald-900/20 rounded-xl">
          <div className="flex items-center space-x-3">
            <div className="w-3 h-3 bg-green-500 rounded-full" aria-hidden="true"></div>
            <span className="text-gray-700 dark:text-gray-300">Already Unlocked</span>
          </div>
          <div className="text-right">
            <div className="text-lg font-bold text-green-600">
              {formatTokenAmount(unlockedTokens)}
            </div>
            <div className="text-sm text-green-500">
              {unlockPercentage.toFixed(1)}%
            </div>
          </div>
        </div>

        {/* Remaining to Unlock */}
        <div className="flex items-center justify-between p-4 bg-gradient-to-r from-yellow-50 to-orange-50 dark:from-yellow-900/20 dark:to-orange-900/20 rounded-xl">
          <div className="flex items-center space-x-3">
            <div className="w-3 h-3 bg-orange-500 rounded-full" aria-hidden="true"></div>
            <span className="text-gray-700 dark:text-gray-300">To Be Unlocked</span>
          </div>
          <div className="text-right">
            <div className="text-lg font-bold text-orange-600">
              {formatTokenAmount(remainingToUnlock)}
            </div>
            <div className="text-sm text-orange-500">
              {remainingPercentage.toFixed(1)}%
            </div>
          </div>
        </div>

        {/* Total Organizer Tokens */}
        <div className="flex items-center justify-between p-4 bg-gradient-to-r from-purple-50 to-pink-50 dark:from-purple-900/20 dark:to-pink-900/20 rounded-xl">
          <div className="flex items-center space-x-3">
            <div className="w-3 h-3 bg-purple-500 rounded-full" aria-hidden="true"></div>
            <span className="text-gray-700 dark:text-gray-300">Total Organizer</span>
          </div>
          <div className="text-right">
            <div className="text-lg font-bold text-purple-600">
              {formatTokenAmount(totalOrganizerTokens)}
            </div>
            <div className="text-sm text-purple-500">100%</div>
          </div>
        </div>
      </div>
    </div>
  );
}