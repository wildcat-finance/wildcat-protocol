// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './math/WadRayMath.sol';
import './math/MathUtils.sol';
import './SafeCastLib.sol';
import '../interfaces/IVaultErrors.sol';

using WadRayMath for uint256;
using MathUtils for uint256;
using SafeCastLib for uint256;

// scaleFactor = 112 bits
// RAY = 89 bits
// so, rayMul by scaleFactor can grow by 23 bits
// if maxTotalSupply is 128 bits, scaledTotalSupply should be 104 bits

struct VaultState {
	// Maximum allowed token supply
	uint128 maxTotalSupply;
	// Scaled token supply (divided by scaleFactor)
	uint104 scaledTotalSupply;
	// Whether vault is currently delinquent (liquidity under requirement)
	bool isDelinquent;
	// Max APR is ~655%
	uint16 annualInterestBips;
	uint16 liquidityCoverageRatio;
	// Seconds in delinquency status
	uint32 timeDelinquent;
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
		return uint256(state.maxTotalSupply).satSub(state.getTotalSupply());
	}

	function increaseScaledTotalSupply(VaultState memory state, uint256 scaledAmount) internal pure {
		state.scaledTotalSupply = (uint256(state.scaledTotalSupply) + scaledAmount).safeCastTo104();
	}

	function normalizeAmount(
		VaultState memory state,
		uint256 amount
	) internal pure returns (uint256) {
		return amount.rayMul(state.scaleFactor);
	}

	function scaleAmount(VaultState memory state, uint256 amount) internal pure returns (uint256) {
		return amount.rayDiv(state.scaleFactor);
	}

	function setMaxTotalSupply(VaultState memory state, uint256 _maxTotalSupply) internal pure {
		// Ensure new maxTotalSupply is not less than current totalSupply
		if (_maxTotalSupply < state.getTotalSupply()) {
			revert IVaultErrors.NewMaxSupplyTooLow();
		}
		state.maxTotalSupply = _maxTotalSupply.safeCastTo128();
	}

	function setLiquidityCoverageRatio(
		VaultState memory state,
		uint256 liquidityCoverageRatio
	) internal pure {
		if (liquidityCoverageRatio > BIP) {
			revert IVaultErrors.LiquidityCoverageRatioTooHigh();
		}
		state.liquidityCoverageRatio = liquidityCoverageRatio.safeCastTo16();
	}

	function setAnnualInterestBips(
		VaultState memory state,
		uint256 annualInterestBips
	) internal pure {
		if (annualInterestBips > BIP) {
			revert IVaultErrors.InterestRateTooHigh();
		}
		state.annualInterestBips = annualInterestBips.safeCastTo16();
	}

	function liquidityRequired(
		VaultState memory state
	) internal pure returns (uint256 _liquidityRequired) {
		_liquidityRequired = state.getTotalSupply().bipMul(state.liquidityCoverageRatio);
	}
}
