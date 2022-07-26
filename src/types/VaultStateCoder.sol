// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import './CoderConstants.sol';

// ============================== NOTICE ==============================
// This library was automatically generated with stackpacker.
// Be very careful about modifying it, as doing so incorrectly could
// result in corrupted reads/writes.
// ====================================================================

// struct VaultState {
//   int16 annualInterestBips;
//   uint96 scaledTotalSupply;
//   uint112 scaleFactor;
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
      int256 annualInterestBips,
      uint256 scaledTotalSupply,
      uint256 scaleFactor,
      uint256 lastInterestAccruedTimestamp
    )
  {
    assembly {
      annualInterestBips := signextend(
        0x01,
        shr(
          VaultState_annualInterestBips_bitsAfter,
          encoded
        )
      )
      scaledTotalSupply := and(
        MaxUint96,
        shr(
          VaultState_scaledTotalSupply_bitsAfter,
          encoded
        )
      )
      scaleFactor := and(
        MaxUint112,
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
    int256 annualInterestBips,
    uint256 scaledTotalSupply,
    uint256 scaleFactor,
    uint256 lastInterestAccruedTimestamp
  ) internal pure returns (VaultState encoded) {
    assembly {
      if or(
        xor(
          annualInterestBips,
          signextend(1, annualInterestBips)
        ),
        or(
          gt(scaledTotalSupply, MaxUint96),
          gt(scaleFactor, MaxUint112)
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
          VaultState_annualInterestBips_bitsAfter,
          and(annualInterestBips, MaxInt16)
        ),
        or(
          shl(
            VaultState_scaledTotalSupply_bitsAfter,
            scaledTotalSupply
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
    }
  }

  /*//////////////////////////////////////////////////////////////
                VaultState NewScaleInputs coders
//////////////////////////////////////////////////////////////*/

  function getNewScaleInputs(VaultState encoded)
    internal
    pure
    returns (
      int256 annualInterestBips,
      uint256 scaleFactor,
      uint256 lastInterestAccruedTimestamp
    )
  {
    assembly {
      annualInterestBips := signextend(
        0x01,
        shr(
          VaultState_annualInterestBips_bitsAfter,
          encoded
        )
      )
      scaleFactor := and(
        MaxUint112,
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

  /*//////////////////////////////////////////////////////////////
                VaultState NewScaleOutputs coders
//////////////////////////////////////////////////////////////*/

  function setNewScaleOutputs(
    VaultState old,
    uint256 scaleFactor,
    uint256 lastInterestAccruedTimestamp
  ) internal pure returns (VaultState updated) {
    assembly {
      if or(
        gt(scaleFactor, MaxUint112),
        gt(
          lastInterestAccruedTimestamp,
          MaxUint32
        )
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
          VaultState_NewScaleOutputs_maskOut
        ),
        or(
          shl(
            VaultState_scaleFactor_bitsAfter,
            scaleFactor
          ),
          lastInterestAccruedTimestamp
        )
      )
    }
  }

  /*//////////////////////////////////////////////////////////////
                 VaultState InitialState coders
//////////////////////////////////////////////////////////////*/

  function setInitialState(
    VaultState old,
    int256 annualInterestBips,
    uint256 scaleFactor,
    uint256 lastInterestAccruedTimestamp
  ) internal pure returns (VaultState updated) {
    assembly {
      if or(
        xor(
          annualInterestBips,
          signextend(1, annualInterestBips)
        ),
        or(
          gt(scaleFactor, MaxUint112),
          gt(
            lastInterestAccruedTimestamp,
            MaxUint32
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
      updated := or(
        and(old, VaultState_InitialState_maskOut),
        or(
          shl(
            VaultState_annualInterestBips_bitsAfter,
            and(annualInterestBips, MaxInt16)
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
               VaultState.scaledTotalSupply coders
//////////////////////////////////////////////////////////////*/

  function getScaledTotalSupply(
    VaultState encoded
  )
    internal
    pure
    returns (uint256 scaledTotalSupply)
  {
    assembly {
      scaledTotalSupply := and(
        MaxUint96,
        shr(
          VaultState_scaledTotalSupply_bitsAfter,
          encoded
        )
      )
    }
  }

  function setScaledTotalSupply(
    VaultState old,
    uint256 scaledTotalSupply
  ) internal pure returns (VaultState updated) {
    assembly {
      if gt(scaledTotalSupply, MaxUint96) {
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
          VaultState_scaledTotalSupply_maskOut
        ),
        shl(
          VaultState_scaledTotalSupply_bitsAfter,
          scaledTotalSupply
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
        MaxUint112,
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
      if gt(scaleFactor, MaxUint112) {
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
