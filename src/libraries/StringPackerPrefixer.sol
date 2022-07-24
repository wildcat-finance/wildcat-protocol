// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

uint256 constant InvalidStringSize_selector = 0xfa29c04700000000000000000000000000000000000000000000000000000000;

contract StringPackerPrefixer {
  error InvalidNullValue();
  error InvalidStringSize();
  error InvalidCompactString();

  /*//////////////////////////////////////////////////////////////
                          String Prefixing
  //////////////////////////////////////////////////////////////*/

  function prefixString(string memory prefix, uint256 stringSize, uint256 stringValue) internal pure {
    // Do not use this function without an additional check that the new size does not
    // exceed 32 bytes, otherwise it will produce corrupted data.
    // In this contract, strings exceeding 31 bytes will be caught in `packString`
    assembly {
      let prefixSize := mload(prefix)
      mstore(prefix, add(prefixSize, stringSize))
      let prefixValue := mload(add(prefix, 0x20))
      let prefixBits := div(prefixSize, 0x08)
      mstore(add(prefix, 0x20), or(prefixValue, shr(prefixBits, stringValue)))
    }
  }

  function getPackedPrefixedReturnValue(
    string memory prefix,
    address target,
    uint256 rightPaddedFunctionSelector,
    uint256 rightPaddedGenericErrorSelector
  ) internal view returns (bytes32 packedString) {
    (uint256 stringSize, uint256 stringValue) = getStringOrBytes32AsString(
      target,
      rightPaddedFunctionSelector,
      rightPaddedGenericErrorSelector
    );
    prefixString(prefix, stringSize, stringValue);
    return packString(prefix);
  }

  /*//////////////////////////////////////////////////////////////
                          Bit Manipulation
  //////////////////////////////////////////////////////////////*/

  function lowestBitSet(uint256 self) internal pure returns (uint256 _z) {
    if (self == 0) {
      revert InvalidNullValue();
    }
    uint256 _magic = 0x00818283848586878898a8b8c8d8e8f929395969799a9b9d9e9faaeb6bedeeff;
    uint256 val;
    assembly {
      val := shr(248, mul(and(self, sub(0, self)), _magic))
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

  /*//////////////////////////////////////////////////////////////
                    External String Query Handler
  //////////////////////////////////////////////////////////////*/

  function getStringOrBytes32AsString(
    address target,
    uint256 rightPaddedFunctionSelector,
    uint256 rightPaddedGenericErrorSelector
  ) internal view returns (uint256 size, uint256 value) {
    bool isBytes32;
    assembly {
      // Cache the free memory pointer to restore it after it is overwritten
      mstore(0, rightPaddedFunctionSelector)
      let status := staticcall(gas(), target, 0, 0x04, 0, 0)
      isBytes32 := eq(returndatasize(), 0x20)
      // If call fails or function returns invalid data, revert.
      // Strings are always right padded to full words - if the returndata
      // is not 32 bytes (string encoded as bytes32) or 96 bytes (abi encoded string)
      // it is either an invalid string or too large.
      if or(iszero(status), iszero(or(isBytes32, eq(returndatasize(), 0x60)))) {
        // Check if call failed
        if iszero(status) {
          // Check if any revert data was given
          if returndatasize() {
            returndatacopy(0, 0, returndatasize())
            revert(0, returndatasize())
          }
          // If not, throw a generic error
          mstore(0, rightPaddedGenericErrorSelector)
          revert(0, 0x04)
        }
        // If the returndata is the wrong size, throw InvalidStringSize
        mstore(0, InvalidStringSize_selector)
        revert(0, 0x04)
      }
    }
    if (isBytes32) {
      assembly {
        returndatacopy(0x00, 0x00, 0x20)
        value := mload(0)
      }
      unchecked {
        uint256 sizeInBits = 255 - lowestBitSet(value);
        size = (sizeInBits + 7) / 8;
      }
    } else {
      // If returndata is a string, copy the length and value
      assembly {
        returndatacopy(0, 0x20, 0x40)
        size := mload(0)
        value := mload(0x20)
      }
    }
  }

  /*//////////////////////////////////////////////////////////////
                         Packed String Coder
  //////////////////////////////////////////////////////////////*/

  function packString(string memory unpackedString)
    internal
    pure
    returns (bytes32 packedString)
  {
    if (bytes(unpackedString).length > 31) {
      revert InvalidCompactString();
    }
    assembly {
      packedString := mload(add(unpackedString, 31))
    }
  }

  function unpackString(bytes32 packedString)
    internal
    pure
    returns (string memory unpackedString)
  {
    assembly {
      // Get free memory pointer
      let freeMemPtr := mload(0x40)
      // Increase free memory pointer by 64 bytes
      mstore(0x40, add(freeMemPtr, 0x40))
      // Set pointer to string
      unpackedString := freeMemPtr
      // Overwrite buffer with zeroes in case it has already been used
      mstore(freeMemPtr, 0)
      mstore(add(freeMemPtr, 0x20), 0)
      // Write length and name to string
      mstore(add(freeMemPtr, 0x1f), packedString)
    }
  }
}
