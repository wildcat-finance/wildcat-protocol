// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import './WildcatMarketBase.sol';
import '../libraries/VaultState.sol';
import '../libraries/FeeMath.sol';
import '../libraries/Uint32Array.sol';

using MathUtils for uint256;
using FeeMath for VaultState;
using SafeCastLib for uint256;

contract WildcatMarketWithdrawals is WildcatMarketBase {
  using SafeTransferLib for address;
	function queueWithdrawal(uint256 amount) external nonReentrant {
		VaultState memory state = _getCurrentStateAndAccrueFees();

		// Update account
		Account memory account = _getAccount(msg.sender);
		_checkAccountAuthorization(msg.sender, account, AuthRole.WithdrawOnly);

		// Scale the actual withdrawal amount
		uint256 scaledAmount = state.scaleAmount(amount);

		// Reduce caller's balance
		account.decreaseScaledBalance(scaledAmount);
		_accounts[msg.sender] = account;

		emit Transfer(msg.sender, address(0), amount);

		// @todo add event
		_withdrawalData.addWithdrawalRequest(
			state,
			msg.sender,
			scaledAmount.safeCastTo104(),
			withdrawalBatchDuration
		);

		emit WithdrawalRequestCreated(
			uint256(state.pendingWithdrawalExpiry),
			address(msg.sender),
			uint256(scaledAmount)
		);
		// Update stored state
		_writeState(state);
	}

	function executeWithdrawal(
		address account,
		uint32 expiry
	) external nonReentrant returns (uint256 normalizedAmountWithdrawn) {
		VaultState memory state = _getCurrentStateAndAccrueFees();

		normalizedAmountWithdrawn = _withdrawalData.withdrawAvailable(state, account, expiry);

		asset.safeTransfer(account, normalizedAmountWithdrawn);

		emit WithdrawalExecuted(expiry, account, normalizedAmountWithdrawn);

		// Update stored state
		_writeState(state);
	}

	function payNextWithdrawal(uint256 scaledAmount) external nonReentrant {
		VaultState memory state = _getCurrentStateAndAccrueFees();
		_withdrawalData.processNextBatch(state, totalAssets());
		_writeState(state);
	}
}
