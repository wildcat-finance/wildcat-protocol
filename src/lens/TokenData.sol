// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import '../interfaces/IERC20Metadata.sol';

using TokenMetadataLib for TokenMetadata global;

struct TokenMetadata {
  address token;
  string name;
  string symbol;
  uint256 decimals;
  bool isMock;
}

library TokenMetadataLib {
  function checkIsMock(address tokenAddress) internal view returns (bool isMock) {
    assembly {
      mstore(0, 0x28ccaa29)
      let success := staticcall(gas(), tokenAddress, 0x1c, 4, 0, 32)
      isMock := and(success, eq(mload(0), 1))
    }
  }

  function fill(TokenMetadata memory data, address tokenAddress) internal view {
    if (tokenAddress == address(0)) {
      return;
    }
    data.token = tokenAddress;
    IERC20Metadata token = IERC20Metadata(tokenAddress);
    data.name = token.name();
    data.symbol = token.symbol();
    data.decimals = token.decimals();
    data.isMock = checkIsMock(tokenAddress);
  }
}
