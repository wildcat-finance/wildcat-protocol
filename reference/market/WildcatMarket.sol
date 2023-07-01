import '../libraries/FeeMath.sol';
import './WildcatMarketBase.sol';
import './WildcatMarketConfig.sol';
import './WildcatMarketToken.sol';

contract WildcatMarket is WildcatMarketBase, WildcatMarketConfig, WildcatMarketToken {
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

	function withdraw(uint256 amount) external virtual nonReentrant {
		// Get current state
		VaultState memory state = _getCurrentStateAndAccrueFees();

		// Scale the actual mint amount
		uint256 scaledAmount = state.scaleAmount(amount);

		// Update account
		Account memory account = _getAccount(msg.sender);
		_checkAccountAuthorization(msg.sender, account, AuthRole.WithdrawOnly);

		account.decreaseScaledBalance(scaledAmount);
		_accounts[msg.sender] = account;

		// Reduce caller's balance
		emit Transfer(msg.sender, address(0), amount);
		emit Withdrawal(msg.sender, amount, scaledAmount);

		// Reduce supply
		state.decreaseScaledTotalSupply(scaledAmount);

		// Transfer withdrawn assets to `to`
		asset.safeTransfer(msg.sender, amount);

		// Update stored state
		_writeState(state);
	}
}
