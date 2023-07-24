// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import './BoolUtils.sol';
import './MathUtils.sol';
import './SafeCastLib.sol';
import '../interfaces/IVaultEventsAndErrors.sol';
import { AuthRole } from '../interfaces/WildcatStructsAndEnums.sol';

using VaultStateLib for VaultState global;
using VaultStateLib for Account global;
using BoolUtils for bool;

// scaleFactor = 112 bits
// RAY = 89 bits
// so, rayMul by scaleFactor can grow by 23 bits
// if maxTotalSupply is 128 bits, scaledTotalSupply should be 104 bits

struct VaultState {
	uint128 maxTotalSupply;
	uint128 accruedProtocolFees;
	// Underlying assets reserved for protocol fees and withdrawals
	uint128 reservedAssets;
	// Scaled token supply (divided by scaleFactor)
	uint104 scaledTotalSupply;
	// Scaled token amount in withdrawal batches that have not been
	// paid by borrower yet.
	uint104 scaledPendingWithdrawals;
	uint32 pendingWithdrawalExpiry;
	// Whether vault is currently delinquent (liquidity under requirement)
	bool isDelinquent;
	// Seconds borrower has been delinquent
	uint32 timeDelinquent;
	// Annual interest rate accrued to lenders, in basis points
	uint16 annualInterestBips;
	// Percentage of outstanding balance that must be held in liquid reserves
	uint16 liquidityCoverageRatio;
	// Ratio between internal balances and underlying token amounts
	uint112 scaleFactor;
	uint32 lastInterestAccruedTimestamp;
}

struct Account {
	AuthRole approval;
	uint104 scaledBalance;
}

library VaultStateLib {
	using MathUtils for uint256;
	using SafeCastLib for uint256;

	/// @dev Returns the normalized total supply of the vault.
	function getTotalSupply(VaultState memory state) internal pure returns (uint256) {
		return state.normalizeAmount(state.scaledTotalSupply);
	}

	/// @dev Returns the maximum amount of tokens that can be deposited without
	///      reaching the maximum total supply.
	function getMaximumDeposit(VaultState memory state) internal pure returns (uint256) {
		return uint256(state.maxTotalSupply).satSub(state.getTotalSupply());
	}

	/// @dev Increase the scaled total supply.
	function increaseScaledTotalSupply(VaultState memory state, uint256 scaledAmount) internal pure {
		state.scaledTotalSupply = (uint256(state.scaledTotalSupply) + scaledAmount).safeCastTo104();
	}

	/// @dev Decrease the scaled total supply.
	function decreaseScaledTotalSupply(VaultState memory state, uint256 scaledAmount) internal pure {
		state.scaledTotalSupply = (uint256(state.scaledTotalSupply) - scaledAmount).safeCastTo104();
	}

	/// @dev Normalize an amount of scaled tokens using the current scale factor.
	function normalizeAmount(
		VaultState memory state,
		uint256 amount
	) internal pure returns (uint256) {
		return amount.rayMul(state.scaleFactor);
	}

	/// @dev Scale an amount of normalized tokens using the current scale factor.
	function scaleAmount(VaultState memory state, uint256 amount) internal pure returns (uint256) {
		return amount.rayDiv(state.scaleFactor);
	}

	function setLiquidityCoverageRatio(
		VaultState memory state,
		uint256 liquidityCoverageRatio
	) internal pure {
		if (liquidityCoverageRatio > BIP) {
			revert IVaultEventsAndErrors.LiquidityCoverageRatioTooHigh();
		}
		state.liquidityCoverageRatio = liquidityCoverageRatio.safeCastTo16();
	}

	function setAnnualInterestBips(
		VaultState memory state,
		uint256 annualInterestBips
	) internal pure {
		if (annualInterestBips > BIP) {
			revert IVaultEventsAndErrors.InterestRateTooHigh();
		}
		state.annualInterestBips = annualInterestBips.safeCastTo16();
	}

	/**
	 * Collateralization requires all pending withdrawals be covered
	 * and coverage ratio for remaining liquidity.
	 */
	function liquidityRequired(
		VaultState memory state
	) internal pure returns (uint256 _liquidityRequired) {
		uint256 scaledWithdrawals = state.scaledPendingWithdrawals;
		uint256 scaledCoverageLiquidity = (state.scaledTotalSupply - scaledWithdrawals).bipMul(
			state.liquidityCoverageRatio
		) + scaledWithdrawals;
		return state.normalizeAmount(scaledCoverageLiquidity) + state.accruedProtocolFees;
	}

	function decreaseScaledBalance(Account memory account, uint256 scaledAmount) internal pure {
		account.scaledBalance = (uint256(account.scaledBalance) - scaledAmount).safeCastTo104();
	}

	function increaseScaledBalance(Account memory account, uint256 scaledAmount) internal pure {
		account.scaledBalance = (uint256(account.scaledBalance) + scaledAmount).safeCastTo104();
	}

	function liquidAssets(
		VaultState memory state,
		uint256 totalAssets
	) internal pure returns (uint256) {
		return totalAssets.satSub(state.reservedAssets + state.accruedProtocolFees);
	}

	function hasPendingBatch(VaultState memory state) internal pure returns (bool) {
		return state.pendingWithdrawalExpiry != 0;
	}

	function hasPendingExpiredBatch(VaultState memory state) internal view returns (bool result) {
		uint256 expiry = state.pendingWithdrawalExpiry;
		assembly {
			// Equivalent to expiry > 0 && expiry <= block.timestamp
			result := gt(timestamp(), sub(expiry, 1))
		}
	}
}
