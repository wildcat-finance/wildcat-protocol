// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import '../libraries/FeeMath.sol';
import './WildcatMarketBase.sol';
import './WildcatMarketConfig.sol';
import './WildcatMarketToken.sol';
import './WildcatMarketWithdrawals.sol';

contract WildcatMarket is
	WildcatMarketBase,
	WildcatMarketConfig,
	WildcatMarketToken,
	WildcatMarketWithdrawals
{
  using SafeTransferLib for address;

	function depositUpTo(
		uint256 amount
	) public virtual nonReentrant returns (uint256 /* actualAmount */) {
		// Get current state

		VaultState memory state = _getCurrentStateAndAccrueFees();

		// Reduce amount if it would exceed totalSupply
		amount = MathUtils.min(amount, state.getMaximumDeposit());

		// Scale the actual mint amount
		uint256 scaledAmount = state.scaleAmount(amount);

		// Transfer deposit from caller
		asset.safeTransferFrom(msg.sender, address(this), amount);

		// Update account
		Account memory account = _getAccount(msg.sender);
		_checkAccountAuthorization(msg.sender, account, AuthRole.DepositAndWithdraw);

		account.increaseScaledBalance(scaledAmount);
		_accounts[msg.sender] = account;

		emit Transfer(address(0), msg.sender, amount);
		emit Deposit(msg.sender, amount, scaledAmount);

		// Increase supply
		state.increaseScaledTotalSupply(scaledAmount);

		// Update stored state
		_writeState(state);

		return amount;
	}

	function deposit(uint256 amount) external virtual {
		uint256 actualAmount = depositUpTo(amount);
		if (amount != actualAmount) {
			revert MaxSupplyExceeded();
		}
	}

	function collectFees() external nonReentrant {
		VaultState memory state = _getCurrentStateAndAccrueFees();
		// Coverage for deposits takes precedence over fee revenue.
		uint256 assetsRequiredForDeposits = state.liquidityRequired();
		if (totalAssets() < assetsRequiredForDeposits) {
			revert InsufficientCoverageForFeeWithdrawal();
		}
		uint256 fees = state.accruedProtocolFees;
		_writeState(state);
		asset.safeTransfer(feeRecipient, fees);
		emit FeesCollected(fees);
	}

	function borrow(uint256 amount) external onlyBorrower nonReentrant {
		VaultState memory state = _getCurrentStateAndAccrueFees();
		uint256 borrowable = state.liquidityRequired();
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
		VaultState memory state = _getCurrentStateAndAccrueFees();
		state.setAnnualInterestBips(0);
		uint256 currentlyHeld = totalAssets();
		uint256 outstanding = state.getTotalSupply() - currentlyHeld;
		_writeState(state);
		asset.safeTransferFrom(msg.sender, address(this), outstanding);
		emit VaultClosed(block.timestamp);
	}
}
