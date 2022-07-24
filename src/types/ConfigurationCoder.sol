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
//   uint96 availableCapacity;
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
      uint256 availableCapacity
    )
  {
    assembly {
      owner := shr(
        Configuration_owner_bitsAfter,
        encoded
      )
      availableCapacity := and(MaxUint96, encoded)
    }
  }

  function encode(
    address owner,
    uint256 availableCapacity
  )
    internal
    pure
    returns (Configuration encoded)
  {
    assembly {
      if gt(availableCapacity, MaxUint96) {
        mstore(0, Panic_error_signature)
        mstore(
          Panic_error_offset,
          Panic_arithmetic
        )
        revert(0, Panic_error_length)
      }
      encoded := or(
        shl(Configuration_owner_bitsAfter, owner),
        availableCapacity
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
             Configuration.availableCapacity coders
//////////////////////////////////////////////////////////////*/

  function getAvailableCapacity(
    Configuration encoded
  )
    internal
    pure
    returns (uint256 availableCapacity)
  {
    assembly {
      availableCapacity := and(MaxUint96, encoded)
    }
  }

  function setAvailableCapacity(
    Configuration old,
    uint256 availableCapacity
  )
    internal
    pure
    returns (Configuration updated)
  {
    assembly {
      if gt(availableCapacity, MaxUint96) {
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
          Configuration_availableCapacity_maskOut
        ),
        availableCapacity
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
