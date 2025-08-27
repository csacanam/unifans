import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

/**
 * Geist Sans font configuration for modern, clean typography
 */
const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

/**
 * Geist Mono font configuration for code and monospace elements
 */
const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

/**
 * Application metadata for SEO and browser display
 */
export const metadata: Metadata = {
  title: "UniFans - Connecting Fans with Events Through Tokens",
  description: "Join the future of event experiences. Buy tokens, unlock exclusive benefits, and connect with fellow fans through blockchain technology.",
  keywords: ["events", "tokens", "fans", "blockchain", "web3", "concert", "exclusive access"],
  authors: [{ name: "UniFans Team" }],
  openGraph: {
    title: "UniFans - Connecting Fans with Events Through Tokens",
    description: "Join the future of event experiences. Buy tokens, unlock exclusive benefits, and connect with fellow fans.",
    type: "website",
    locale: "en_US",
  },
  twitter: {
    card: "summary_large_image",
    title: "UniFans - Connecting Fans with Events Through Tokens",
    description: "Join the future of event experiences. Buy tokens, unlock exclusive benefits, and connect with fellow fans.",
  },
  viewport: "width=device-width, initial-scale=1",
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#8B5CF6" },
    { media: "(prefers-color-scheme: dark)", color: "#3B82F6" },
  ],
};

/**
 * @component RootLayout
 * @description Root layout component for the Next.js application
 * 
 * Features:
 * - Modern font loading with Geist font family
 * - Dark mode support through CSS variables
 * - Responsive design foundation
 * - Accessibility improvements with proper HTML structure
 * - SEO optimization with comprehensive metadata
 * 
 * @param {Object} props - Component props
 * @param {React.ReactNode} props.children - Child components to render
 * @returns {JSX.Element} Root HTML structure with layout
 */
export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <link rel="icon" href="/favicon.ico" />
      </head>
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased bg-white dark:bg-gray-900 transition-colors duration-200`}
        suppressHydrationWarning
      >
        {children}
      </body>
    </html>
  );
}