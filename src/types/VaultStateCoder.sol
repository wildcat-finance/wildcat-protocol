// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import './CoderConstants.sol';

// ============================== NOTICE ==============================
// This library was automatically generated with stackpacker.
// Be very careful about modifying it, as doing so incorrectly could
// result in corrupted reads/writes.
// ====================================================================

// struct VaultState {
//   uint14 collateralizationRatioBips;
//   int16 annualInterestBips;
//   uint97 totalSupply;
//   uint97 scaleFactor;
//   uint32 lastInterestAccruedTimestamp;
// }
type VaultState is uint256;

VaultState constant DefaultVaultState = VaultState
  .wrap(0);

library VaultStateCoder {
  /*//////////////////////////////////////////////////////////////
                           VaultState
//////////////////////////////////////////////////////////////*/

  function decode(VaultState encoded)
    internal
    pure
    returns (
      uint256 collateralizationRatioBips,
      int256 annualInterestBips,
      uint256 totalSupply,
      uint256 scaleFactor,
      uint256 lastInterestAccruedTimestamp
    )
  {
    assembly {
      collateralizationRatioBips := shr(
        VaultState_collateralizationRatioBips_bitsAfter,
        encoded
      )
      annualInterestBips := signextend(
        0x01,
        shr(
          VaultState_annualInterestBips_bitsAfter,
          encoded
        )
      )
      totalSupply := and(
        MaxUint97,
        shr(
          VaultState_totalSupply_bitsAfter,
          encoded
        )
      )
      scaleFactor := and(
        MaxUint97,
        shr(
          VaultState_scaleFactor_bitsAfter,
          encoded
        )
      )
      lastInterestAccruedTimestamp := and(
        MaxUint32,
        encoded
      )
    }
  }

  function encode(
    uint256 collateralizationRatioBips,
    int256 annualInterestBips,
    uint256 totalSupply,
    uint256 scaleFactor,
    uint256 lastInterestAccruedTimestamp
  ) internal pure returns (VaultState encoded) {
    assembly {
      if or(
        gt(collateralizationRatioBips, MaxUint14),
        or(
          xor(
            annualInterestBips,
            signextend(1, annualInterestBips)
          ),
          or(
            gt(totalSupply, MaxUint97),
            or(
              gt(scaleFactor, MaxUint97),
              gt(
                lastInterestAccruedTimestamp,
                MaxUint32
              )
            )
          )
        )
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
          VaultState_collateralizationRatioBips_bitsAfter,
          collateralizationRatioBips
        ),
        or(
          shl(
            VaultState_annualInterestBips_bitsAfter,
            and(annualInterestBips, MaxInt16)
          ),
          or(
            shl(
              VaultState_totalSupply_bitsAfter,
              totalSupply
            ),
            or(
              shl(
                VaultState_scaleFactor_bitsAfter,
                scaleFactor
              ),
              lastInterestAccruedTimestamp
            )
          )
        )
      )
    }
  }

  /*//////////////////////////////////////////////////////////////
          VaultState.collateralizationRatioBips coders
//////////////////////////////////////////////////////////////*/

  function getCollateralizationRatioBips(
    VaultState encoded
  )
    internal
    pure
    returns (uint256 collateralizationRatioBips)
  {
    assembly {
      collateralizationRatioBips := shr(
        VaultState_collateralizationRatioBips_bitsAfter,
        encoded
      )
    }
  }

  function setCollateralizationRatioBips(
    VaultState old,
    uint256 collateralizationRatioBips
  ) internal pure returns (VaultState updated) {
    assembly {
      if gt(
        collateralizationRatioBips,
        MaxUint14
      ) {
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
          VaultState_collateralizationRatioBips_maskOut
        ),
        shl(
          VaultState_collateralizationRatioBips_bitsAfter,
          collateralizationRatioBips
        )
      )
    }
  }

  /*//////////////////////////////////////////////////////////////
              VaultState.annualInterestBips coders
//////////////////////////////////////////////////////////////*/

  function getAnnualInterestBips(
    VaultState encoded
  )
    internal
    pure
    returns (int256 annualInterestBips)
  {
    assembly {
      annualInterestBips := signextend(
        0x01,
        shr(
          VaultState_annualInterestBips_bitsAfter,
          encoded
        )
      )
    }
  }

  function setAnnualInterestBips(
    VaultState old,
    int256 annualInterestBips
  ) internal pure returns (VaultState updated) {
    assembly {
      if xor(
        annualInterestBips,
        signextend(1, annualInterestBips)
      ) {
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
          VaultState_annualInterestBips_maskOut
        ),
        shl(
          VaultState_annualInterestBips_bitsAfter,
          and(annualInterestBips, MaxInt16)
        )
      )
    }
  }

  /*//////////////////////////////////////////////////////////////
                  VaultState.totalSupply coders
//////////////////////////////////////////////////////////////*/

  function getTotalSupply(VaultState encoded)
    internal
    pure
    returns (uint256 totalSupply)
  {
    assembly {
      totalSupply := and(
        MaxUint97,
        shr(
          VaultState_totalSupply_bitsAfter,
          encoded
        )
      )
    }
  }

  function setTotalSupply(
    VaultState old,
    uint256 totalSupply
  ) internal pure returns (VaultState updated) {
    assembly {
      if gt(totalSupply, MaxUint97) {
        mstore(0, Panic_error_signature)
        mstore(
          Panic_error_offset,
          Panic_arithmetic
        )
        revert(0, Panic_error_length)
      }
      updated := or(
        and(old, VaultState_totalSupply_maskOut),
        shl(
          VaultState_totalSupply_bitsAfter,
          totalSupply
        )
      )
    }
  }

  /*//////////////////////////////////////////////////////////////
                  VaultState.scaleFactor coders
//////////////////////////////////////////////////////////////*/

  function getScaleFactor(VaultState encoded)
    internal
    pure
    returns (uint256 scaleFactor)
  {
    assembly {
      scaleFactor := and(
        MaxUint97,
        shr(
          VaultState_scaleFactor_bitsAfter,
          encoded
        )
      )
    }
  }

  function setScaleFactor(
    VaultState old,
    uint256 scaleFactor
  ) internal pure returns (VaultState updated) {
    assembly {
      if gt(scaleFactor, MaxUint97) {
        mstore(0, Panic_error_signature)
        mstore(
          Panic_error_offset,
          Panic_arithmetic
        )
        revert(0, Panic_error_length)
      }
      updated := or(
        and(old, VaultState_scaleFactor_maskOut),
        shl(
          VaultState_scaleFactor_bitsAfter,
          scaleFactor
        )
      )
    }
  }

  /*//////////////////////////////////////////////////////////////
         VaultState.lastInterestAccruedTimestamp coders
//////////////////////////////////////////////////////////////*/

  function getLastInterestAccruedTimestamp(
    VaultState encoded
  )
    internal
    pure
    returns (uint256 lastInterestAccruedTimestamp)
  {
    assembly {
      lastInterestAccruedTimestamp := and(
        MaxUint32,
        encoded
      )
    }
  }

  function setLastInterestAccruedTimestamp(
    VaultState old,
    uint256 lastInterestAccruedTimestamp
  ) internal pure returns (VaultState updated) {
    assembly {
      if gt(
        lastInterestAccruedTimestamp,
        MaxUint32
      ) {
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
          VaultState_lastInterestAccruedTimestamp_maskOut
        ),
        lastInterestAccruedTimestamp
      )
    }
  }

  /*//////////////////////////////////////////////////////////////
                  VaultState comparison methods
//////////////////////////////////////////////////////////////*/

  function equals(VaultState a, VaultState b)
    internal
    pure
    returns (bool _equals)
  {
    assembly {
      _equals := eq(a, b)
    }
  }

  function isNull(VaultState a)
    internal
    pure
    returns (bool _isNull)
  {
    _isNull = equals(a, DefaultVaultState);
  }
}
