// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import './CoderConstants.sol';

// ============================== NOTICE ==============================
// This library was automatically generated with stackpacker.
// Be very careful about modifying it, as doing so incorrectly could
// result in corrupted reads/writes.
// ====================================================================

// struct ScaleParameters {
//   bool isDelinquent;
//   uint32 timeDelinquent;
//   uint16 annualInterestBips;
//   uint112 scaleFactor;
//   uint32 lastInterestAccruedTimestamp;
// }
type ScaleParameters is uint256;

ScaleParameters constant DefaultScaleParameters = ScaleParameters
  .wrap(0);

using ScaleParametersCoder for ScaleParameters global;

library ScaleParametersCoder {
  /*//////////////////////////////////////////////////////////////
                         ScaleParameters
//////////////////////////////////////////////////////////////*/

  function decode(ScaleParameters encoded)
    internal
    pure
    returns (
      bool isDelinquent,
      uint256 timeDelinquent,
      uint256 annualInterestBips,
      uint256 scaleFactor,
      uint256 lastInterestAccruedTimestamp
    )
  {
    assembly {
      isDelinquent := shr(
        ScaleParameters_isDelinquent_bitsAfter,
        encoded
      )
      timeDelinquent := and(
        MaxUint32,
        shr(
          ScaleParameters_timeDelinquent_bitsAfter,
          encoded
        )
      )
      annualInterestBips := and(
        MaxUint16,
        shr(
          ScaleParameters_annualInterestBips_bitsAfter,
          encoded
        )
      )
      scaleFactor := and(
        MaxUint112,
        shr(
          ScaleParameters_scaleFactor_bitsAfter,
          encoded
        )
      )
      lastInterestAccruedTimestamp := and(
        MaxUint32,
        shr(
          ScaleParameters_lastInterestAccruedTimestamp_bitsAfter,
          encoded
        )
      )
    }
  }

  function encode(
    bool isDelinquent,
    uint256 timeDelinquent,
    uint256 annualInterestBips,
    uint256 scaleFactor,
    uint256 lastInterestAccruedTimestamp
  )
    internal
    pure
    returns (ScaleParameters encoded)
  {
    assembly {
      // Revert if `timeDelinquent`, `annualInterestBips` or `scaleFactor` overflow
      if or(
        gt(timeDelinquent, MaxUint32),
        or(
          gt(annualInterestBips, MaxUint16),
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
          ScaleParameters_isDelinquent_bitsAfter,
          isDelinquent
        ),
        or(
          shl(
            ScaleParameters_timeDelinquent_bitsAfter,
            timeDelinquent
          ),
          or(
            shl(
              ScaleParameters_annualInterestBips_bitsAfter,
              annualInterestBips
            ),
            or(
              shl(
                ScaleParameters_scaleFactor_bitsAfter,
                scaleFactor
              ),
              shl(
                ScaleParameters_lastInterestAccruedTimestamp_bitsAfter,
                lastInterestAccruedTimestamp
              )
            )
          )
        )
      )
    }
  }

  /*//////////////////////////////////////////////////////////////
              ScaleParameters NewScaleInputs coders
//////////////////////////////////////////////////////////////*/

  function getNewScaleInputs(
    ScaleParameters encoded
  )
    internal
    pure
    returns (
      uint256 annualInterestBips,
      uint256 scaleFactor,
      uint256 lastInterestAccruedTimestamp
    )
  {
    assembly {
      annualInterestBips := and(
        MaxUint16,
        shr(
          ScaleParameters_annualInterestBips_bitsAfter,
          encoded
        )
      )
      scaleFactor := and(
        MaxUint112,
        shr(
          ScaleParameters_scaleFactor_bitsAfter,
          encoded
        )
      )
      lastInterestAccruedTimestamp := and(
        MaxUint32,
        shr(
          ScaleParameters_lastInterestAccruedTimestamp_bitsAfter,
          encoded
        )
      )
    }
  }

  /*//////////////////////////////////////////////////////////////
             ScaleParameters NewScaleOutputs coders
//////////////////////////////////////////////////////////////*/

  function setNewScaleOutputs(
    ScaleParameters old,
    uint256 scaleFactor,
    uint256 lastInterestAccruedTimestamp
  )
    internal
    pure
    returns (ScaleParameters updated)
  {
    assembly {
      // Revert if `scaleFactor` or `lastInterestAccruedTimestamp` overflow
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
          ScaleParameters_NewScaleOutputs_maskOut
        ),
        or(
          shl(
            ScaleParameters_scaleFactor_bitsAfter,
            scaleFactor
          ),
          shl(
            ScaleParameters_lastInterestAccruedTimestamp_bitsAfter,
            lastInterestAccruedTimestamp
          )
        )
      )
    }
  }

  /*//////////////////////////////////////////////////////////////
               ScaleParameters InitialState coders
//////////////////////////////////////////////////////////////*/

  function setInitialState(
    ScaleParameters old,
    uint256 annualInterestBips,
    uint256 scaleFactor,
    uint256 lastInterestAccruedTimestamp
  )
    internal
    pure
    returns (ScaleParameters updated)
  {
    assembly {
      // Revert if `annualInterestBips`, `scaleFactor` or `lastInterestAccruedTimestamp` overflow
      if or(
        gt(annualInterestBips, MaxUint16),
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
        and(
          old,
          ScaleParameters_InitialState_maskOut
        ),
        or(
          shl(
            ScaleParameters_annualInterestBips_bitsAfter,
            annualInterestBips
          ),
          or(
            shl(
              ScaleParameters_scaleFactor_bitsAfter,
              scaleFactor
            ),
            shl(
              ScaleParameters_lastInterestAccruedTimestamp_bitsAfter,
              lastInterestAccruedTimestamp
            )
          )
        )
      )
    }
  }

  /*//////////////////////////////////////////////////////////////
               ScaleParameters Delinquency coders
//////////////////////////////////////////////////////////////*/

  function setDelinquency(
    ScaleParameters old,
    bool isDelinquent,
    uint256 timeDelinquent
  )
    internal
    pure
    returns (ScaleParameters updated)
  {
    assembly {
      // Revert if `timeDelinquent` overflows
      if gt(timeDelinquent, MaxUint32) {
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
          ScaleParameters_Delinquency_maskOut
        ),
        or(
          shl(
            ScaleParameters_isDelinquent_bitsAfter,
            isDelinquent
          ),
          shl(
            ScaleParameters_timeDelinquent_bitsAfter,
            timeDelinquent
          )
        )
      )
    }
  }

  function getDelinquency(ScaleParameters encoded)
    internal
    pure
    returns (
      bool isDelinquent,
      uint256 timeDelinquent
    )
  {
    assembly {
      isDelinquent := shr(
        ScaleParameters_isDelinquent_bitsAfter,
        encoded
      )
      timeDelinquent := and(
        MaxUint32,
        shr(
          ScaleParameters_timeDelinquent_bitsAfter,
          encoded
        )
      )
    }
  }

  /*//////////////////////////////////////////////////////////////
               ScaleParameters.isDelinquent coders
//////////////////////////////////////////////////////////////*/

  function getIsDelinquent(
    ScaleParameters encoded
  ) internal pure returns (bool isDelinquent) {
    assembly {
      isDelinquent := shr(
        ScaleParameters_isDelinquent_bitsAfter,
        encoded
      )
    }
  }

  function setIsDelinquent(
    ScaleParameters old,
    bool isDelinquent
  )
    internal
    pure
    returns (ScaleParameters updated)
  {
    assembly {
      updated := or(
        and(
          old,
          ScaleParameters_isDelinquent_maskOut
        ),
        shl(
          ScaleParameters_isDelinquent_bitsAfter,
          isDelinquent
        )
      )
    }
  }

  /*//////////////////////////////////////////////////////////////
              ScaleParameters.timeDelinquent coders
//////////////////////////////////////////////////////////////*/

  function getTimeDelinquent(
    ScaleParameters encoded
  )
    internal
    pure
    returns (uint256 timeDelinquent)
  {
    assembly {
      timeDelinquent := and(
        MaxUint32,
        shr(
          ScaleParameters_timeDelinquent_bitsAfter,
          encoded
        )
      )
    }
  }

  function setTimeDelinquent(
    ScaleParameters old,
    uint256 timeDelinquent
  )
    internal
    pure
    returns (ScaleParameters updated)
  {
    assembly {
      // Revert if `timeDelinquent` overflows
      if gt(timeDelinquent, MaxUint32) {
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
          ScaleParameters_timeDelinquent_maskOut
        ),
        shl(
          ScaleParameters_timeDelinquent_bitsAfter,
          timeDelinquent
        )
      )
    }
  }

  /*//////////////////////////////////////////////////////////////
            ScaleParameters.annualInterestBips coders
//////////////////////////////////////////////////////////////*/

  function getAnnualInterestBips(
    ScaleParameters encoded
  )
    internal
    pure
    returns (uint256 annualInterestBips)
  {
    assembly {
      annualInterestBips := and(
        MaxUint16,
        shr(
          ScaleParameters_annualInterestBips_bitsAfter,
          encoded
        )
      )
    }
  }

  function setAnnualInterestBips(
    ScaleParameters old,
    uint256 annualInterestBips
  )
    internal
    pure
    returns (ScaleParameters updated)
  {
    assembly {
      // Revert if `annualInterestBips` overflows
      if gt(annualInterestBips, MaxUint16) {
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
          ScaleParameters_annualInterestBips_maskOut
        ),
        shl(
          ScaleParameters_annualInterestBips_bitsAfter,
          annualInterestBips
        )
      )
    }
  }

  /*//////////////////////////////////////////////////////////////
               ScaleParameters.scaleFactor coders
//////////////////////////////////////////////////////////////*/

  function getScaleFactor(ScaleParameters encoded)
    internal
    pure
    returns (uint256 scaleFactor)
  {
    assembly {
      scaleFactor := and(
        MaxUint112,
        shr(
          ScaleParameters_scaleFactor_bitsAfter,
          encoded
        )
      )
    }
  }

  function setScaleFactor(
    ScaleParameters old,
    uint256 scaleFactor
  )
    internal
    pure
    returns (ScaleParameters updated)
  {
    assembly {
      // Revert if `scaleFactor` overflows
      if gt(scaleFactor, MaxUint112) {
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
          ScaleParameters_scaleFactor_maskOut
        ),
        shl(
          ScaleParameters_scaleFactor_bitsAfter,
          scaleFactor
        )
      )
    }
  }

  /*//////////////////////////////////////////////////////////////
       ScaleParameters.lastInterestAccruedTimestamp coders
//////////////////////////////////////////////////////////////*/

  function getLastInterestAccruedTimestamp(
    ScaleParameters encoded
  )
    internal
    pure
    returns (uint256 lastInterestAccruedTimestamp)
  {
    assembly {
      lastInterestAccruedTimestamp := and(
        MaxUint32,
        shr(
          ScaleParameters_lastInterestAccruedTimestamp_bitsAfter,
          encoded
        )
      )
    }
  }

  function setLastInterestAccruedTimestamp(
    ScaleParameters old,
    uint256 lastInterestAccruedTimestamp
  )
    internal
    pure
    returns (ScaleParameters updated)
  {
    assembly {
      updated := or(
        and(
          old,
          ScaleParameters_lastInterestAccruedTimestamp_maskOut
        ),
        shl(
          ScaleParameters_lastInterestAccruedTimestamp_bitsAfter,
          lastInterestAccruedTimestamp
        )
      )
    }
  }

  /*//////////////////////////////////////////////////////////////
               ScaleParameters comparison methods
//////////////////////////////////////////////////////////////*/

  function equals(
    ScaleParameters a,
    ScaleParameters b
  ) internal pure returns (bool _equals) {
    assembly {
      _equals := eq(a, b)
    }
  }

  function isNull(ScaleParameters a)
    internal
    pure
    returns (bool _isNull)
  {
    _isNull = equals(a, DefaultScaleParameters);
  }
}
