// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../types/CoderConstants.sol";

uint256 constant OneEth = 1e18;
uint256 constant RayOne = 1e26;

library Math {
  function avg(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = (a & b) + (a ^ b) / 2;
  }

  function min(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = ternary(a < b, a, b);
  }

  function max(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = ternary(a < b, b, a);
  }

  function subMinZero(uint256 a, uint256 b) internal pure returns (uint256 c) {
    unchecked {
      c = ternary(a > b, a - b, 0);
    }
  }

  function addMinZero(uint256 a, int256 b) internal pure returns (uint256 c) {
    bool underflow;
    assembly {
      c := add(a, b)
      underflow := slt(c, 0)
    }
    return ternary(underflow, 0, c);
  }

  function rayMul(uint256 x, uint256 y) internal pure returns (uint256 z) {
    z = (x * y) / RayOne;
  }

  function rayMul(uint256 x, int256 y) internal pure returns (int256 z) {
    assembly {
      z := mul(x, y)
      if iszero(eq(sdiv(z, x), y)) {
        mstore(0, Panic_error_signature)
        mstore(Panic_error_offset, Panic_arithmetic)
        revert(0, Panic_error_length)
      }
      z := sdiv(z, RayOne)
    }
  }

  function rayDiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
    z = (x * RayOne) / y;
  }

  function ternary(
    bool condition,
    uint256 valueIfTrue,
    uint256 valueIfFalse
  ) internal pure returns (uint256 c) {
    assembly {
      c := add(valueIfFalse, mul(condition, sub(valueIfTrue, valueIfFalse)))
    }
  }
}
