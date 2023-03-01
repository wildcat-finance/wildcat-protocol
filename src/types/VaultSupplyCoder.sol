// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import './CoderConstants.sol';

// ============================== NOTICE ==============================
// This library was automatically generated with stackpacker.
// Be very careful about modifying it, as doing so incorrectly could
// result in corrupted reads/writes.
// ====================================================================

// struct VaultSupply {
//   uint128 maxTotalSupply;
//   uint128 scaledTotalSupply;
// }
type VaultSupply is uint256;

VaultSupply constant DefaultVaultSupply = VaultSupply
  .wrap(0);

using VaultSupplyCoder for VaultSupply global;

library VaultSupplyCoder {
  /*//////////////////////////////////////////////////////////////
                           VaultSupply
//////////////////////////////////////////////////////////////*/

  function decode(VaultSupply encoded)
    internal
    pure
    returns (
      uint256 maxTotalSupply,
      uint256 scaledTotalSupply
    )
  {
    assembly {
      maxTotalSupply := shr(
        VaultSupply_maxTotalSupply_bitsAfter,
        encoded
      )
      scaledTotalSupply := and(
        MaxUint128,
        encoded
      )
    }
  }

  function encode(
    uint256 maxTotalSupply,
    uint256 scaledTotalSupply
  ) internal pure returns (VaultSupply encoded) {
    assembly {
      // Revert if `maxTotalSupply` or `scaledTotalSupply` overflow
      if or(
        gt(maxTotalSupply, MaxUint128),
        gt(scaledTotalSupply, MaxUint128)
      ) {
        mstore(0, Panic_error_signature)
        mstore(
          Panic_error_offset,
          Panic_arithmetic
        )
        revert(0, Panic_error_length)
      }
      encoded := or(
        shl(
          VaultSupply_maxTotalSupply_bitsAfter,
          maxTotalSupply
        ),
        scaledTotalSupply
      )
    }
  }

  /*//////////////////////////////////////////////////////////////
                VaultSupply.maxTotalSupply coders
//////////////////////////////////////////////////////////////*/

  function getMaxTotalSupply(VaultSupply encoded)
    internal
    pure
    returns (uint256 maxTotalSupply)
  {
    assembly {
      maxTotalSupply := shr(
        VaultSupply_maxTotalSupply_bitsAfter,
        encoded
      )
    }
  }

  function setMaxTotalSupply(
    VaultSupply old,
    uint256 maxTotalSupply
  ) internal pure returns (VaultSupply updated) {
    assembly {
      // Revert if `maxTotalSupply` overflows
      if gt(maxTotalSupply, MaxUint128) {
        mstore(0, Panic_error_signature)
        mstore(
          Panic_error_offset,
          Panic_arithmetic
        )
        revert(0, Panic_error_length)
      }
      updated := or(
        and(
          old,
          VaultSupply_maxTotalSupply_maskOut
        ),
        shl(
          VaultSupply_maxTotalSupply_bitsAfter,
          maxTotalSupply
        )
      )
    }
  }

  /*//////////////////////////////////////////////////////////////
              VaultSupply.scaledTotalSupply coders
//////////////////////////////////////////////////////////////*/

  function getScaledTotalSupply(
    VaultSupply encoded
  )
    internal
    pure
    returns (uint256 scaledTotalSupply)
  {
    assembly {
      scaledTotalSupply := and(
        MaxUint128,
        encoded
      )
    }
  }

  function setScaledTotalSupply(
    VaultSupply old,
    uint256 scaledTotalSupply
  ) internal pure returns (VaultSupply updated) {
    assembly {
      // Revert if `scaledTotalSupply` overflows
      if gt(scaledTotalSupply, MaxUint128) {
        mstore(0, Panic_error_signature)
        mstore(
          Panic_error_offset,
          Panic_arithmetic
        )
        revert(0, Panic_error_length)
      }
      updated := or(
        and(
          old,
          VaultSupply_scaledTotalSupply_maskOut
        ),
        scaledTotalSupply
      )
    }
  }

  /*//////////////////////////////////////////////////////////////
                 VaultSupply comparison methods
//////////////////////////////////////////////////////////////*/

  function equals(VaultSupply a, VaultSupply b)
    internal
    pure
    returns (bool _equals)
  {
    assembly {
      _equals := eq(a, b)
    }
  }

  function isNull(VaultSupply a)
    internal
    pure
    returns (bool _isNull)
  {
    _isNull = equals(a, DefaultVaultSupply);
  }
}
