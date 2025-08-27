// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/console.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {FullMath} from "v4-core/libraries/FullMath.sol";

library EventCoinHookTestUtils {
    using PoolIdLibrary for PoolKey;

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) >> 1;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) >> 1;
        }
    }

    function priceToSqrtPriceX96_RAW(
        uint256 amount1Raw,
        uint256 amount0Raw
    ) internal pure returns (uint160) {
        require(amount0Raw > 0, "den=0");
        uint256 ratioX192 = FullMath.mulDiv(amount1Raw, 1 << 192, amount0Raw);
        uint256 sqrtX96 = sqrt(ratioX192);
        require(sqrtX96 <= type(uint160).max, "overflow");
        return uint160(sqrtX96);
    }

    function log18(string memory label, uint256 amountWei) internal pure {
        console.log(string.concat(label, ": "), amountWei / 1e18, " tokens");
    }

    function log6(string memory label, uint256 amount6d) internal pure {
        console.log(string.concat(label, ": "), amount6d / 1e6, " USDC");
    }

    function logPrice(uint160 sqrtPriceX96, string memory label) internal pure {
        uint256 priceRaw = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) >>
            192;
        console.log(label, " price (raw):", priceRaw);
    }

    // ============================================================================
    // ADDITIONAL UTILITY FUNCTIONS
    // ============================================================================

    /**
     * @notice Calculate price ratio between two amounts accounting for decimals
     * @dev Useful for validating price calculations in tests with different decimal tokens
     *
     * @param amount1 Amount of token1 (numerator)
     * @param decimals1 Decimal places of token1
     * @param amount0 Amount of token0 (denominator)
     * @param decimals0 Decimal places of token0
     * @return ratio The price ratio normalized to 18 decimals
     */
    function calculatePriceRatio(
        uint256 amount1,
        uint8 decimals1,
        uint256 amount0,
        uint8 decimals0
    ) internal pure returns (uint256 ratio) {
        require(amount0 > 0, "Cannot divide by zero");

        // Normalize both amounts to 18 decimals for calculation
        uint256 normalized1 = decimals1 <= 18
            ? amount1 * (10 ** (18 - decimals1))
            : amount1 / (10 ** (decimals1 - 18));

        uint256 normalized0 = decimals0 <= 18
            ? amount0 * (10 ** (18 - decimals0))
            : amount0 / (10 ** (decimals0 - 18));

        return FullMath.mulDiv(normalized1, 1e18, normalized0);
    }

    /**
     * @notice Format large numbers with thousand separators for logging
     * @dev Helps make large token amounts more readable in test output
     * @param amount The amount to format
     * @return formatted String representation with commas (simplified)
     */
    function formatLargeNumber(
        uint256 amount
    ) internal pure returns (string memory) {
        // Simplified formatting - in a real implementation you'd add comma separation
        if (amount >= 1e9) {
            return string(abi.encodePacked(uint2str(amount / 1e9), "B"));
        } else if (amount >= 1e6) {
            return string(abi.encodePacked(uint2str(amount / 1e6), "M"));
        } else if (amount >= 1e3) {
            return string(abi.encodePacked(uint2str(amount / 1e3), "K"));
        }
        return uint2str(amount);
    }

    /**
     * @notice Convert uint256 to string
     * @dev Helper function for number formatting
     * @param value The number to convert
     * @return String representation of the number
     */
    function uint2str(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
