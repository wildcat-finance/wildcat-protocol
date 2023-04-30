// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import './DebtTokenBase.sol';

contract WildcatVaultToken is DebtTokenBase {
	using SafeTransferLib for address;
  using MathUtils for uint256;
  using VaultStateLib for VaultState;

	function collectFees() external nonReentrant {
    (VaultState memory state, ) = _getCurrentStateAndAccrueFees();
    // Coverage for deposits takes precedence over fee revenue.
    uint256 assetsRequiredForDeposits = state.liquidityRequired(0);
    if (totalAssets() < assetsRequiredForDeposits) {
      revert InsufficientCoverageForFeeWithdrawal();
    }
		_writeState(state);
		uint256 fees = lastAccruedProtocolFees;
		lastAccruedProtocolFees = 0;
		asset.safeTransfer(feeRecipient, fees);
		emit FeesCollected(fees);
	}

	function borrow(uint256 amount) external onlyBorrower nonReentrant {
		(VaultState memory state, ) = _getCurrentStateAndAccrueFees();
		uint256 borrowable = state.liquidityRequired(lastAccruedProtocolFees);
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
