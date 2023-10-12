// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import 'src/market/WildcatMarket.sol';
import '../shared/TestConstants.sol';
import './Assertions.sol';
import '../shared/Test.sol';

contract ExpectedStateTracker is Test, Assertions, IVaultEventsAndErrors {
  using FeeMath for VaultState;
  using SafeCastLib for uint256;
  using MathUtils for uint256;

  VaultParameters internal parameters =
    VaultParameters({
      asset: address(0),
      namePrefix: 'Wildcat ',
      symbolPrefix: 'WC',
      borrower: borrower,
      controller: address(0),
      feeRecipient: feeRecipient,
      sentinel: address(sanctionsSentinel),
      maxTotalSupply: uint128(DefaultMaximumSupply),
      protocolFeeBips: DefaultProtocolFeeBips,
      annualInterestBips: DefaultInterest,
      delinquencyFeeBips: DefaultDelinquencyFee,
      withdrawalBatchDuration: DefaultWithdrawalBatchDuration,
      reserveRatioBips: DefaultReserveRatio,
      delinquencyGracePeriod: DefaultGracePeriod
    });
  VaultState internal previousState;
  WithdrawalData internal _withdrawalData;
  uint256 internal lastTotalAssets;
  address[] internal accountsAffected;
  mapping(address => Account) internal accounts;

  function pendingState() internal returns (VaultState memory state) {
    state = previousState;
    if (block.timestamp >= state.pendingWithdrawalExpiry && state.pendingWithdrawalExpiry != 0) {
      uint256 expiry = state.pendingWithdrawalExpiry;
      state.updateScaleFactorAndFees(
        parameters.protocolFeeBips,
        parameters.delinquencyFeeBips,
        parameters.delinquencyGracePeriod,
        expiry
      );
      _processExpiredWithdrawalBatch(state);
    }
    state.updateScaleFactorAndFees(
      parameters.protocolFeeBips,
      parameters.delinquencyFeeBips,
      parameters.delinquencyGracePeriod,
      block.timestamp
    );
  }

  function updateState(VaultState memory state) internal {
    state.isDelinquent = state.liquidityRequired() > lastTotalAssets;
    previousState = state;
  }

  function _checkState() internal {
    assertEq(vault.previousState(), previousState, 'previousState');
    assertEq(vault.currentState(), pendingState(), 'currentState');

    // assertEq(lastProtocolFees, vault.lastAccruedProtocolFees(), 'protocol fees');
  }

  /**
   * @dev When a withdrawal batch expires, the vault will checkpoint the scale factor
   *      as of the time of expiry and retrieve the current liquid assets in the vault
   * (assets which are not already owed to protocol fees or prior withdrawal batches).
   */
  function _processExpiredWithdrawalBatch(VaultState memory state) internal {
    WithdrawalBatch storage batch = _withdrawalData.batches[state.pendingWithdrawalExpiry];

    // Get the liquidity which is not already reserved for prior withdrawal batches
    // or owed to protocol fees.
    uint256 availableLiquidity = _availableLiquidityForPendingBatch(batch, state);
    if (availableLiquidity > 0) {
      _applyWithdrawalBatchPayment(batch, state, state.pendingWithdrawalExpiry, availableLiquidity);
    }
    // vm.expectEmit(address(vault));
    emit WithdrawalBatchExpired(
      state.pendingWithdrawalExpiry,
      batch.scaledTotalAmount,
      batch.scaledAmountBurned,
      batch.normalizedAmountPaid
    );

    if (batch.scaledAmountBurned < batch.scaledTotalAmount) {
      _withdrawalData.unpaidBatches.push(state.pendingWithdrawalExpiry);
    } else {
      // vm.expectEmit(address(vault));
      emit WithdrawalBatchClosed(state.pendingWithdrawalExpiry);
    }

    state.pendingWithdrawalExpiry = 0;
  }

  function _availableLiquidityForPendingBatch(
    WithdrawalBatch storage batch,
    VaultState memory state
  ) internal view returns (uint256) {
    uint104 scaledAmountOwed = batch.scaledTotalAmount - batch.scaledAmountBurned;
    uint256 unavailableAssets = state.normalizedUnclaimedWithdrawals +
      state.accruedProtocolFees +
      state.normalizeAmount(state.scaledPendingWithdrawals - scaledAmountOwed);

    return lastTotalAssets.satSub(unavailableAssets);
  }

  /**
   * @dev Process withdrawal payment, burning vault tokens and reserving
   *      underlying assets so they are only available for withdrawals.
   */
  function _applyWithdrawalBatchPayment(
    WithdrawalBatch storage batch,
    VaultState memory state,
    uint32 expiry,
    uint256 availableLiquidity
  ) internal {
    uint104 scaledAvailableLiquidity = state.scaleAmount(availableLiquidity).toUint104();
    uint104 scaledAmountOwed = batch.scaledTotalAmount - batch.scaledAmountBurned;
    if (scaledAmountOwed == 0) {
      return;
    }
    uint104 scaledAmountBurned = uint104(MathUtils.min(scaledAvailableLiquidity, scaledAmountOwed));
    uint128 normalizedAmountPaid = state.normalizeAmount(scaledAmountBurned).toUint128();

    batch.scaledAmountBurned += scaledAmountBurned;
    batch.normalizedAmountPaid += normalizedAmountPaid;
    state.scaledPendingWithdrawals -= scaledAmountBurned;

    // Update normalizedUnclaimedWithdrawals so the tokens are only accessible for withdrawals.
    state.normalizedUnclaimedWithdrawals += normalizedAmountPaid;

    // Burn vault tokens to stop interest accrual upon withdrawal payment.
    state.scaledTotalSupply -= scaledAmountBurned;

    // Emit transfer for external trackers to indicate burn.
    // vm.expectEmit(address(vault));
    emit Transfer(address(this), address(0), normalizedAmountPaid);
    // vm.expectEmit(address(vault));
    emit WithdrawalBatchPayment(expiry, scaledAmountBurned, normalizedAmountPaid);
  }
}
