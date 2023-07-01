// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import './WildcatMarketBase.sol';

contract WildcatMarketToken is WildcatMarketBase {
	mapping(address => mapping(address => uint256)) public allowance;

	/// @notice Returns the normalized balance of `account` with interest.
	function balanceOf(address account) public view virtual nonReentrantView returns (uint256) {
		// Get current state
		(VaultState memory state, ) = _getCurrentState();
		return state.normalizeAmount(_accounts[account].scaledBalance);
	}

	/// @notice Returns the normalized total supply with interest.
	function totalSupply() external view virtual nonReentrantView returns (uint256) {
		(VaultState memory state, ) = _getCurrentState();
		return state.getTotalSupply();
	}

	// =====================================================================//
	//                            ERC20 Actions                             //
	// =====================================================================//

	function approve(address spender, uint256 amount) external virtual returns (bool) {
		_approve(msg.sender, spender, amount);

		return true;
	}

	function transferFrom(
		address from,
		address to,
		uint256 amount
	) external virtual nonReentrant returns (bool) {
		uint256 allowed = allowance[from][msg.sender];

		// Saves gas for unlimited approvals.
		if (allowed != type(uint256).max) {
			uint256 newAllowance = allowed - amount;
			_approve(from, msg.sender, newAllowance);
		}

		_transfer(from, to, amount);

		return true;
	}

	function _approve(address approver, address spender, uint256 amount) internal virtual {
		allowance[approver][spender] = amount;
		emit Approval(approver, spender, amount);
	}

	function _transfer(address from, address to, uint256 amount) internal virtual {
		VaultState memory state = _getCurrentStateAndAccrueFees();
		uint256 scaledAmount = state.scaleAmount(amount);

		Account memory fromAccount = _getAccount(from);
		fromAccount.decreaseScaledBalance(scaledAmount);
		_accounts[from] = fromAccount;

		Account memory toAccount = _getAccount(to);
		toAccount.increaseScaledBalance(scaledAmount);
		_accounts[to] = toAccount;

		emit Transfer(from, to, amount);
	}
}
