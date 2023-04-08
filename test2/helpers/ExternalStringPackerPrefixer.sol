// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "src/libraries/StringPackerPrefixer.sol";

contract ExternalStringPackerPrefixer is StringPackerPrefixer {
  function prefixString(
    string memory prefix,
    uint256 stringSize,
    uint256 stringValue
  ) external pure returns (string memory) {
    _prefixString(prefix, stringSize, stringValue);
    return prefix;
  }

  function getPackedPrefixedReturnValue(
    string memory prefix,
    address target,
    uint256 rightPaddedFunctionSelector,
    uint256 rightPaddedGenericErrorSelector
  ) external view returns (bytes32 packedString) {
    return
      _getPackedPrefixedReturnValue(
        prefix,
        target,
        rightPaddedFunctionSelector,
        rightPaddedGenericErrorSelector
      );
  }

  function getStringOrBytes32AsString(
    address target,
    uint256 rightPaddedFunctionSelector,
    uint256 rightPaddedGenericErrorSelector
  ) external view returns (uint256 size, uint256 value) {
    return
      _getStringOrBytes32AsString(
        target,
        rightPaddedFunctionSelector,
        rightPaddedGenericErrorSelector
      );
  }

  function packString(string memory unpackedString)
    external
    pure
    returns (bytes32 packedString)
  {
    return _packString(unpackedString);
  }

  function unpackString(bytes32 packedString)
    external
    pure
    returns (string memory unpackedString)
  {
    return _unpackString(packedString);
  }
}
