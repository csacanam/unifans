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
}
