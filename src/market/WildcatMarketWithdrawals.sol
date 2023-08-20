// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import './WildcatMarketBase.sol';
import '../libraries/VaultState.sol';
import '../libraries/FeeMath.sol';
import '../libraries/FIFOQueue.sol';

using MathUtils for uint256;
using FeeMath for VaultState;
using SafeCastLib for uint256;

contract WildcatMarketWithdrawals is WildcatMarketBase {
	using SafeTransferLib for address;

	function getExpiredBatches() external view returns (uint32[] memory) {
		return _withdrawalData.unpaidBatches.values();
	}

	function _processNextUnpaidBatch(VaultState memory state) internal {
		uint32 expiry = _withdrawalData.unpaidBatches.first();
		WithdrawalBatch storage batch = _withdrawalData.batches[expiry];

		uint256 availableLiquidity = state.liquidAssets(totalAssets());
		uint104 scaledAmountBurned = state.scaleAmount(availableLiquidity).toUint104();
		{
			uint104 scaledOwedAmount = batch.scaledTotalAmount - batch.scaledAmountBurned;

			if (scaledAmountBurned >= scaledOwedAmount) {
				scaledAmountBurned = scaledOwedAmount;
				_withdrawalData.unpaidBatches.shift();
				emit IVaultEventsAndErrors.WithdrawalBatchClosed(expiry);
			}
		}

		uint128 normalizedAmountPaid = state.normalizeAmount(scaledAmountBurned).toUint128();

		emit IVaultEventsAndErrors.WithdrawalBatchPayment(
			state.pendingWithdrawalExpiry,
			scaledAmountBurned,
			normalizedAmountPaid
		);

		batch.scaledAmountBurned += scaledAmountBurned;
		batch.normalizedAmountPaid += normalizedAmountPaid;

		// Tokens can be burned now that the withdrawal is redeemable.
		state.scaledPendingWithdrawals -= scaledAmountBurned;
		state.reservedAssets += normalizedAmountPaid;
		state.scaledTotalSupply -= scaledAmountBurned;

		// Emit transfer for external trackers to indicate burn
		emit Transfer(address(this), address(0), normalizedAmountPaid);
	}

	/**
	 * @dev Create a withdrawal request for a lender.
	 *      Adds the withdrawal to the pending batch, if any.
	 */
	function queueWithdrawal(uint256 amount) external nonReentrant {
		VaultState memory state = _getUpdatedState();

		// Update account
		Account memory account = _getAccount(msg.sender);
		_checkAccountAuthorization(msg.sender, account, AuthRole.WithdrawOnly);

		// Scale the actual withdrawal amount
		uint256 scaledAmount = state.scaleAmount(amount);

		if (scaledAmount == 0) {
			revert NullBurnAmount();
		}

		// Reduce caller's balance
		account.decreaseScaledBalance(scaledAmount);
		_accounts[msg.sender] = account;

		emit Transfer(msg.sender, address(this), amount);

		_withdrawalData.addWithdrawalRequest(
			state,
			msg.sender,
			scaledAmount.toUint104(),
			withdrawalBatchDuration
		);

		// Update stored state
		_writeState(state);
	}

	function executeWithdrawal(
		address account,
		uint32 expiry
	) external nonReentrant returns (uint256 normalizedAmountWithdrawn) {
		VaultState memory state = _getUpdatedState();

		normalizedAmountWithdrawn = _withdrawalData.withdrawAvailable(state, account, expiry);

		asset.safeTransfer(account, normalizedAmountWithdrawn);

		emit WithdrawalExecuted(expiry, account, normalizedAmountWithdrawn);

		// Update stored state
		_writeState(state);
	}

	function processWithdrawals() external nonReentrant onlyBorrower {
		VaultState memory state = _getUpdatedState();
		_processNextUnpaidBatch(state);
		_writeState(state);
	}

	/*   function repayAllWithdrawals() external nonReentrant onlyBorrower {
    VaultState memory state = _getUpdatedState();
    uint256 amountMissing = 
    uint256 expiryIndex = _withdrawalData.unpaidBatches.startIndex;
    uint256 finalIndex = _withdrawalData.unpaidBatches.nextIndex;
    while (expiryIndex < finalIndex) {
      uint32 expiry = _withdrawalData.unpaidBatches.data[expiryIndex];

      expiryIndex++;
    }
    
    _writeState(state);
  } */
}
