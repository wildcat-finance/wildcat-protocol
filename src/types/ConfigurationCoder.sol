// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import './CoderConstants.sol';

// ============================== NOTICE ==============================
// This library was automatically generated with stackpacker.
// Be very careful about modifying it, as doing so incorrectly could
// result in corrupted reads/writes.
// ====================================================================

// struct Configuration {
//   address owner;
//   uint96 maxTotalSupply;
// }
type Configuration is uint256;

Configuration constant DefaultConfiguration = Configuration
  .wrap(0);

library ConfigurationCoder {
  /*//////////////////////////////////////////////////////////////
                          Configuration
//////////////////////////////////////////////////////////////*/

  function decode(Configuration encoded)
    internal
    pure
    returns (
      address owner,
      uint256 maxTotalSupply
    )
  {
    assembly {
      owner := shr(
        Configuration_owner_bitsAfter,
        encoded
      )
      maxTotalSupply := and(MaxUint96, encoded)
    }
  }

  function encode(
    address owner,
    uint256 maxTotalSupply
  )
    internal
    pure
    returns (Configuration encoded)
  {
    assembly {
      if gt(maxTotalSupply, MaxUint96) {
        mstore(0, Panic_error_signature)
        mstore(
          Panic_error_offset,
          Panic_arithmetic
        )
        revert(0, Panic_error_length)
      }
      encoded := or(
        shl(Configuration_owner_bitsAfter, owner),
        maxTotalSupply
      )
    }
  }

  /*//////////////////////////////////////////////////////////////
                   Configuration.owner coders
//////////////////////////////////////////////////////////////*/

  function getOwner(Configuration encoded)
    internal
    pure
    returns (address owner)
  {
    assembly {
      owner := shr(
        Configuration_owner_bitsAfter,
        encoded
      )
    }
  }

  function setOwner(
    Configuration old,
    address owner
  )
    internal
    pure
    returns (Configuration updated)
  {
    assembly {
      updated := or(
        and(old, Configuration_owner_maskOut),
        shl(Configuration_owner_bitsAfter, owner)
      )
    }
  }

  /*//////////////////////////////////////////////////////////////
               Configuration.maxTotalSupply coders
//////////////////////////////////////////////////////////////*/

  function getMaxTotalSupply(
    Configuration encoded
  )
    internal
    pure
    returns (uint256 maxTotalSupply)
  {
    assembly {
      maxTotalSupply := and(MaxUint96, encoded)
    }
  }

  function setMaxTotalSupply(
    Configuration old,
    uint256 maxTotalSupply
  )
    internal
    pure
    returns (Configuration updated)
  {
    assembly {
      if gt(maxTotalSupply, MaxUint96) {
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
          Configuration_maxTotalSupply_maskOut
        ),
        maxTotalSupply
      )
    }
  }

  /*//////////////////////////////////////////////////////////////
                Configuration comparison methods
//////////////////////////////////////////////////////////////*/

  function equals(
    Configuration a,
    Configuration b
  ) internal pure returns (bool _equals) {
    assembly {
      _equals := eq(a, b)
    }
  }

  function isNull(Configuration a)
    internal
    pure
    returns (bool _isNull)
  {
    _isNull = equals(a, DefaultConfiguration);
  }
}
