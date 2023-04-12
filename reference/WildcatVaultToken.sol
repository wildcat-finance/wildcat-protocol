// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import './DebtTokenBase.sol';

contract WildcatVaultToken is DebtTokenBase {
	function collectFees() external {
		(VaultState memory state, ) = _getCurrentStateAndAccrueFees();
		_writeState(state);
		uint256 fees = lastAccruedProtocolFees;
		asset.safeTransfer(feeRecipient, fees);
		emit FeesCollected(fees);
		lastAccruedProtocolFees = 0;
	}

	function borrow(uint256 amount) external onlyBorrower nonReentrant {
		(VaultState memory state, ) = _getCurrentStateAndAccrueFees();
		uint256 borrowable = totalAssets().satSub(lastAccruedProtocolFees);
		if (amount > borrowable) {
			revert BorrowAmountTooHigh();
		}
		_writeState(state);
		asset.safeTransfer(msg.sender, amount);
		emit Borrow(amount);
	}

	/**
	 * @dev Sets the vault APR to 0% and transfers the outstanding balance for full redemption
	 */
	function closeVault() external onlyController nonReentrant {
		(VaultState memory state, ) = _getCurrentStateAndAccrueFees();
		state.setAnnualInterestBips(0);
		uint256 currentlyHeld = totalAssets();
		uint256 outstanding = state.getTotalSupply() - currentlyHeld;
		_writeState(state);
		asset.safeTransferFrom(msg.sender, address(this), outstanding);
		emit VaultClosed(block.timestamp);
	}
}
