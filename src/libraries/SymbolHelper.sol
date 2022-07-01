// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../interfaces/IERC20Metadata.sol";

library SymbolHelper {

  /**
   * @dev Returns the index of the lowest bit set in `self`.
   * Note: Requires that `self != 0`
   */
  function lowestBitSet(uint256 self) internal pure returns (uint256 _z) {
    require (self > 0, "Bits::lowestBitSet: Value 0 has no bits set");
    uint256 _magic = 0x00818283848586878898a8b8c8d8e8f929395969799a9b9d9e9faaeb6bedeeff;
    int256 negOne = -1;
    uint256 val;
        assembly {
        val := mul(shr(248, _magic), and(self, mul(self, negOne)))
        }
    uint256 _y = val >> 5;
    _z = (
      _y < 4
        ? _y < 2
          ? _y == 0
            ? 0x753a6d1b65325d0c552a4d1345224105391a310b29122104190a110309020100
            : 0xc976c13bb96e881cb166a933a55e490d9d56952b8d4e801485467d2362422606
          : _y == 2
            ? 0xe39ed557db96902cd38ed14fad815115c786af479b7e83247363534337271707
            : 0xf7cae577eec2a03cf3bad76fb589591debb2dd67e0aa9834bea6925f6a4a2e0e
        : _y < 6
          ? _y == 4
            ? 0xc8c0b887b0a8a4489c948c7f847c6125746c645c544c444038302820181008ff
            : 0xf6e4ed9ff2d6b458eadcdf97bd91692de2d4da8fd2d0ac50c6ae9a8272523616
          : _y == 6
            ? 0xf5ecf1b3e9debc68e1d9cfabc5997135bfb7a7a3938b7b606b5b4b3f2f1f0ffe
            : 0xf8f9cbfae6cc78fbefe7cdc3a1793dfcf4f0e8bbd8cec470b6a28a7a5a3e1efd
    );
    _z >>= (val & 0x1f) << 3;
    return _z & 0xff;
  }

  function getSymbol(address token) internal view returns (string memory) {
    (bool success, bytes memory data) = token.staticcall(abi.encodeWithSignature("symbol()"));
    if (!success) return "UNKNOWN";
    if (data.length != 32) return abi.decode(data, (string));
    uint256 symbol = abi.decode(data, (uint256));
    if (symbol == 0) return "UNKNOWN";
    uint256 emptyBits = 255 - lowestBitSet(symbol);
    uint256 size = (emptyBits / 8) + (emptyBits % 8 > 0 ? 1 : 0);
    assembly { mstore(data, size) }
    return string(data);
  }

  function getName(address token) internal view returns (string memory) {
    (bool success, bytes memory data) = token.staticcall(abi.encodeWithSignature("name()"));
    if (!success) return "UNKNOWN";
    if (data.length != 32) return abi.decode(data, (string));
    uint256 symbol = abi.decode(data, (uint256));
    if (symbol == 0) return "UNKNOWN";
    uint256 emptyBits = 255 - lowestBitSet(symbol);
    uint256 size = (emptyBits / 8) + (emptyBits % 8 > 0 ? 1 : 0);
    assembly { mstore(data, size) }
    return string(data);
  }

  function getPrefixedSymbol(string memory prefix, address token) internal view returns (string memory prefixedSymbol) {
    prefixedSymbol = string(abi.encodePacked(
      prefix,
      getSymbol(token)
    ));
  }

  function getPrefixedName(string memory prefix, address token) internal view returns (string memory prefixedName) {
    prefixedName = string(abi.encodePacked(
      prefix,
      getName(token)
    ));
  }
}