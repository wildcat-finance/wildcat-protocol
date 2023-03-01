// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import './Math.sol';
import './SafeCastLib.sol';
import '../interfaces/IVaultErrors.sol';

using Math for uint256;
using SafeCastLib for uint256;

struct VaultState {
  // Maximum allowed token supply
  uint128 maxTotalSupply;
  // Scaled token supply (divided by scaleFactor)
	uint128 scaledTotalSupply;
  // Whether vault is currently delinquent (collateral under requirement)
	bool isDelinquent;
  // Seconds in delinquency status
	uint32 timeDelinquent;
	// Max APR is ~655%
	uint16 annualInterestBips;
	// Max scale factor is ~52m
	uint112 scaleFactor;
  // Last time vault accrued interest
	uint32 lastInterestAccruedTimestamp;
}

using VaultStateLib for VaultState global;

library VaultStateLib {
  function getTotalSupply(VaultState memory state) internal pure returns (uint256) {
    return state.normalizeAmount(state.scaledTotalSupply);
  }
  
  function getMaximumDeposit(VaultState memory state) internal pure returns (uint256) {
    return uint256(state.maxTotalSupply).subMinZero(state.getTotalSupply());
  }
  
  function setMaxTotalSupply(VaultState memory state, uint256 _maxTotalSupply) internal pure {
    // Ensure new maxTotalSupply is not less than current totalSupply
    if (_maxTotalSupply < state.getTotalSupply()) {
      revert IVaultErrors.NewMaxSupplyTooLow();
    }
    state.maxTotalSupply = _maxTotalSupply.safeCastTo128();
  }

  function normalizeAmount(VaultState memory state, uint256 amount) internal pure returns (uint256) {
    return amount.rayMul(state.scaleFactor);
  }

  function scaleAmount(VaultState memory state, uint256 amount) internal pure returns (uint256) {
    return amount.rayDiv(state.scaleFactor);
  }
}