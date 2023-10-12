// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { VaultState, VaultStateLib } from 'src/libraries/VaultState.sol';

library VaultStateLibExternal {
  /// @dev Returns the normalized total supply of the vault.
  function $totalSupply(VaultState memory state) external pure returns (uint256) {
    return VaultStateLib.totalSupply(state);
  }

  /// @dev Returns the maximum amount of tokens that can be deposited without
  /// reaching the maximum total supply.
  function $maximumDeposit(VaultState memory state) external pure returns (uint256) {
    return VaultStateLib.maximumDeposit(state);
  }

  /// @dev Normalize an amount of scaled tokens using the current scale factor.
  function $normalizeAmount(
    VaultState memory state,
    uint256 amount
  ) external pure returns (uint256) {
    return VaultStateLib.normalizeAmount(state, amount);
  }

  /// @dev Scale an amount of normalized tokens using the current scale factor.
  function $scaleAmount(VaultState memory state, uint256 amount) external pure returns (uint256) {
    return VaultStateLib.scaleAmount(state, amount);
  }

  /// Collateralization requires all pending withdrawals be covered
  /// and reserve ratio for remaining liquidity.
  function $liquidityRequired(
    VaultState memory state
  ) external pure returns (uint256 _liquidityRequired) {
    return VaultStateLib.liquidityRequired(state);
  }

  function $borrowableAssets(
    VaultState memory state,
    uint256 totalAssets
  ) external pure returns (uint256) {
    return VaultStateLib.borrowableAssets(state, totalAssets);
  }

  function $hasPendingExpiredBatch(VaultState memory state) external view returns (bool result) {
    return VaultStateLib.hasPendingExpiredBatch(state);
  }

  function $withdrawableProtocolFees(
    VaultState memory state,
    uint256 totalAssets
  ) external view returns (uint256) {
    return VaultStateLib.withdrawableProtocolFees(state, totalAssets);
  }
}
