"use client";

import { useState, useEffect } from "react";

/**
 * @interface NotificationProps
 * @description Props for the Notification component
 */
interface NotificationProps {
  /** The message to display in the notification */
  message: string;
  /** The type of notification affecting styling and icon */
  type: "success" | "error" | "info";
  /** Whether the notification is currently visible */
  isVisible: boolean;
  /** Callback function called when notification should be closed */
  onClose: () => void;
}

/**
 * @component Notification
 * @description Toast notification component for displaying temporary messages
 * 
 * Features:
 * - Multiple notification types (success, error, info)
 * - Auto-dismiss functionality with 5-second timer
 * - Manual close button
 * - Smooth fade-in animation
 * - Fixed positioning in top-right corner
 * - Responsive design with proper contrast
 * - Accessibility support with proper ARIA labels
 * 
 * @param {NotificationProps} props - Component props
 * @returns {JSX.Element | null} Rendered notification or null if not visible
 */
export default function Notification({ message, type, isVisible, onClose }: NotificationProps) {
  /**
   * Auto-dismiss timer effect
   * Automatically closes the notification after 5 seconds
   */
  useEffect(() => {
    if (isVisible) {
      const timer = setTimeout(() => {
        onClose();
      }, 5000);

      return () => clearTimeout(timer);
    }
  }, [isVisible, onClose]);

  // Don't render if not visible
  if (!isVisible) return null;

  /**
   * @function getIcon
   * @description Returns appropriate emoji icon based on notification type
   * @returns {string} Emoji icon for the notification type
   */
  const getIcon = (): string => {
    switch (type) {
      case "success":
        return "✅";
      case "error":
        return "❌";
      case "info":
        return "ℹ️";
      default:
        return "ℹ️";
    }
  };

  /**
   * @function getBgColor
   * @description Returns appropriate background color class based on notification type
   * @returns {string} Tailwind CSS background color class
   */
  const getBgColor = (): string => {
    switch (type) {
      case "success":
        return "bg-green-500";
      case "error":
        return "bg-red-500";
      case "info":
        return "bg-blue-500";
      default:
        return "bg-blue-500";
    }
  };

  /**
   * @function getAriaLabel
   * @description Returns appropriate ARIA label for accessibility
   * @returns {string} Descriptive label for screen readers
   */
  const getAriaLabel = (): string => {
    switch (type) {
      case "success":
        return "Success notification";
      case "error":
        return "Error notification";
      case "info":
        return "Information notification";
      default:
        return "Notification";
    }
  };

  return (
    <div className="fixed top-4 right-4 z-50 animate-fade-in-up">
      <div 
        className={`${getBgColor()} text-white px-6 py-4 rounded-xl shadow-lg max-w-sm flex items-center space-x-3`}
        role="alert"
        aria-live="polite"
        aria-label={getAriaLabel()}
      >
        {/* Notification Icon */}
        <span className="text-xl" aria-hidden="true">
          {getIcon()}
        </span>
        
        {/* Message Content */}
        <div className="flex-1">
          <p className="font-medium">{message}</p>
        </div>
        
        {/* Close Button */}
        <button
          onClick={onClose}
          className="text-white/80 hover:text-white transition-colors p-1 rounded-md hover:bg-white/10 focus:outline-none focus:ring-2 focus:ring-white/50"
          aria-label="Close notification"
          type="button"
        >
          <span aria-hidden="true">✕</span>
        </button>
      </div>
    </div>
  );
}