// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { AuthRole } from '../interfaces/WildcatStructsAndEnums.sol';
import './MathUtils.sol';
import './SafeCastLib.sol';
import './FeeMath.sol';

using VaultStateLib for VaultState global;
using VaultStateLib for Account global;
using FeeMath for VaultState global;

struct VaultState {
  bool isClosed;
  uint128 maxTotalSupply;
  uint128 accruedProtocolFees;
  // Underlying assets reserved for withdrawals which have been paid
  // by the borrower but not yet executed.
  uint128 normalizedUnclaimedWithdrawals;
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

  /**
   * @dev Returns the normalized total supply of the vault.
   */
  function totalSupply(VaultState memory state) internal pure returns (uint256) {
    return state.normalizeAmount(state.scaledTotalSupply);
  }

  /**
   * @dev Returns the maximum amount of tokens that can be deposited without
   *      reaching the maximum total supply.
   */
  function maximumDeposit(VaultState memory state) internal pure returns (uint256) {
    return uint256(state.maxTotalSupply).satSub(state.totalSupply());
  }

  /**
   * @dev Normalize an amount of scaled tokens using the current scale factor.
   */
  function normalizeAmount(
    VaultState memory state,
    uint256 amount
  ) internal pure returns (uint256) {
    return amount.rayMul(state.scaleFactor);
  }

  /**
   * @dev Scale an amount of normalized tokens using the current scale factor.
   */
  function scaleAmount(VaultState memory state, uint256 amount) internal pure returns (uint256) {
    return amount.rayDiv(state.scaleFactor);
  }

  /**
   * @dev Collateralization requires all pending withdrawals be covered
   *      and coverage ratio for remaining liquidity.
   */
  function liquidityRequired(
    VaultState memory state
  ) internal pure returns (uint256 _liquidityRequired) {
    uint256 scaledWithdrawals = state.scaledPendingWithdrawals;
    uint256 scaledCoverageLiquidity = (state.scaledTotalSupply - scaledWithdrawals).bipMul(
      state.liquidityCoverageRatio
    ) + scaledWithdrawals;
    return
      state.normalizeAmount(scaledCoverageLiquidity) +
      state.accruedProtocolFees +
      state.normalizedUnclaimedWithdrawals;
  }

  /**
   * @dev Returns the amount of underlying assets that can be withdrawn
   *      for protocol fees. The only debts with higher priority are
   *      processed withdrawals that have not been executed.
   */
  function withdrawableProtocolFees(
    VaultState memory state,
    uint256 totalAssets
  ) internal pure returns (uint128) {
    uint256 totalAvailableAssets = totalAssets - state.normalizedUnclaimedWithdrawals;
    return uint128(MathUtils.min(totalAvailableAssets, state.accruedProtocolFees));
  }

  /**
   * @dev Returns the amount of underlying assets that can be borrowed.
   *
   *      The borrower must maintain sufficient assets in the vault to
   *      cover 100% of pending withdrawals, 100% of previously processed
   *      withdrawals (before they are executed), and the liquidity coverage
   *      ratio times the outstanding debt (deposits not pending withdrawal).
   *
   *      Any underlying assets in the market above this amount can be borrowed.
   */
  function borrowableAssets(
    VaultState memory state,
    uint256 totalAssets
  ) internal pure returns (uint256) {
    return totalAssets.satSub(state.liquidityRequired());
  }

  function hasPendingExpiredBatch(VaultState memory state) internal view returns (bool result) {
    uint256 expiry = state.pendingWithdrawalExpiry;
    assembly {
      // Equivalent to expiry > 0 && expiry <= block.timestamp
      result := gt(timestamp(), sub(expiry, 1))
    }
  }

  function totalDebts(VaultState memory state) internal pure returns (uint256) {
    return
      state.normalizeAmount(state.scaledTotalSupply) +
      state.normalizedUnclaimedWithdrawals +
      state.accruedProtocolFees;
  }
}
