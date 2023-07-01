// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import '../libraries/FeeMath.sol';
import './WildcatMarketBase.sol';

contract WildcatMarketConfig is WildcatMarketBase {
	/**
	 * @dev Revoke an account's authorization to deposit assets.
	 */
	function revokeAccountAuthorization(address _account) external onlyController nonReentrant {
		VaultState memory state = _getCurrentStateAndAccrueFees();
		Account memory account = _getAccount(_account);
		account.approval = AuthRole.WithdrawOnly;
		_accounts[_account] = account;
		_writeState(state);
		emit AuthorizationStatusUpdated(_account, AuthRole.WithdrawOnly);
	}

	/**
	 * @dev Restore an account's authorization to deposit assets.
	 * Can not be used to restore a blacklisted account's status.
	 */
	function grantAccountAuthorization(address _account) external onlyController nonReentrant {
		VaultState memory state = _getCurrentStateAndAccrueFees();
		Account memory account = _getAccount(_account);
		account.approval = AuthRole.DepositAndWithdraw;
		_accounts[_account] = account;
		_writeState(state);
		emit AuthorizationStatusUpdated(_account, AuthRole.DepositAndWithdraw);
	}

	/// @dev Block an account from interacting with the market and
	///      delete its balance.
	//          *  |\**/|  *          *                                *
	//          *  \ == /  *          *                                *
	//          *   | b|   *          *                                *
	//          *   | y|   *          *                                *
	//          *   \ e/   *          *                                *
	//          *    \/    *          *                                *
	//          *          *          *                                *
	//          *          *          *                                *
	//          *          *  |\**/|  *                                *
	//          *          *  \ == /  *         _.-^^---....,,--       *
	//          *          *   | b|   *    _--                  --_    *
	//          *          *   | y|   *   <                        >)  *
	//          *          *   \ e/   *   |         O-FAC!          |  *
	//          *          *    \/    *    \._                   _./   *
	//          *          *          *       ```--. . , ; .--'''      *
	//          *          *          *   💸        | |   |            *
	//          *          *          *          .-=||  | |=-.    💸   *
	//  💰🤑💰  *    😅    *    😐    *    💸    `-=#$%&%$#=-'         *
	//   \|/    *   /|\    *   /|\    *  🌪         | ;  :|    🌪      *
	//   /\     * 💰/\ 💰  * 💰/\ 💰  *    _____.,-#%&$@%#&#~,._____   *
	function nukeFromOrbit(address _account) external onlySentinel {
		VaultState memory state = _getCurrentStateAndAccrueFees();
		Account memory account = _getAccount(_account);
		uint256 scaledBalance = account.scaledBalance;
		uint256 amount = state.normalizeAmount(scaledBalance);
		delete _accounts[_account];
		if (scaledBalance > 0) {
			state.decreaseScaledTotalSupply(scaledBalance);
		}
		if (amount > 0) {
			emit Transfer(_account, address(0), amount);
		}
		_writeState(state);
		emit AuthorizationStatusUpdated(_account, AuthRole.Blocked);
	}

	// /*//////////////////////////////////////////////////////////////
	//                       Management Actions
	// //////////////////////////////////////////////////////////////*/

	/**
	 * @dev Sets the maximum total supply - this only limits deposits and
	 * does not affect interest accrual.
	 */
	function setMaxTotalSupply(uint256 _maxTotalSupply) external onlyController nonReentrant {
		VaultState memory state = _getCurrentStateAndAccrueFees();

		// Ensure new maxTotalSupply is not less than current totalSupply
		if (_maxTotalSupply < state.getTotalSupply()) {
			revert IVaultEventsAndErrors.NewMaxSupplyTooLow();
		}
		state.maxTotalSupply = _maxTotalSupply.safeCastTo128();
		_writeState(state);
		emit MaxSupplyUpdated(_maxTotalSupply);
	}

	function setAnnualInterestBips(uint256 _annualInterestBips) public onlyController nonReentrant {
		VaultState memory state = _getCurrentStateAndAccrueFees();
		state.setAnnualInterestBips(_annualInterestBips);
		_writeState(state);
		emit AnnualInterestBipsUpdated(_annualInterestBips);
	}

	function setLiquidityCoverageRatio(
		uint256 _liquidityCoverageRatio
	) public onlyController nonReentrant {
		// @todo - revert if new LCR would cause vault to be undercollateralized

		VaultState memory state = _getCurrentStateAndAccrueFees();
		state.setLiquidityCoverageRatio(_liquidityCoverageRatio);
		_writeState(state);
		emit LiquidityCoverageRatioUpdated(_liquidityCoverageRatio);
	}
}
