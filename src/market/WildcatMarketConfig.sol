// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import '../libraries/FeeMath.sol';
import '../libraries/SafeCastLib.sol';
import './WildcatMarketBase.sol';

contract WildcatMarketConfig is WildcatMarketBase {
	using SafeCastLib for uint256;

	// ===================================================================== //
	//                      External Config Getters                          //
	// ===================================================================== //

	/**
	 * @dev Returns the maximum amount of underlying asset that can
	 *      currently be deposited to the market.
	 */
	function maximumDeposit() external view returns (uint256) {
    (VaultState memory state,,) = _calculateCurrentState();
		return state.maximumDeposit();
	}

	/**
	 * @dev Returns the maximum supply the market can reach via
	 *      deposits (does not apply to interest accrual).
	 */
	function maxTotalSupply() external view returns (uint256) {
		return _state.maxTotalSupply;
	}

	/**
	 * @dev Returns the annual interest rate earned by lenders
	 *      in bips.
	 */
	function annualInterestBips() external view returns (uint256) {
		return _state.annualInterestBips;
	}

	function liquidityCoverageRatio() external view returns (uint256) {
		return _state.liquidityCoverageRatio;
	}

	// =====================================================================//
	//                        External Config Setters                       //
	// =====================================================================//

	/**
	 * @dev Revoke an account's authorization to deposit assets.
	 */
	function revokeAccountAuthorization(address _account) external onlyController nonReentrant {
		VaultState memory state = _getUpdatedState();
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
		VaultState memory state = _getUpdatedState();
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
		VaultState memory state = _getUpdatedState();
		Account memory account = _getAccount(_account);
		uint104 scaledBalance = account.scaledBalance;
		uint256 amount = state.normalizeAmount(scaledBalance);

		account.approval = AuthRole.Blocked;
		account.scaledBalance = 0;
		_accounts[_account] = account;

		if (scaledBalance > 0) {
			state.scaledTotalSupply -= scaledBalance;
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
	 *      does not affect interest accrual.
	 */
	function setMaxTotalSupply(uint256 _maxTotalSupply) external onlyController nonReentrant {
		VaultState memory state = _getUpdatedState();

		if (_maxTotalSupply < state.totalSupply()) {
			revert NewMaxSupplyTooLow();
		}

		state.maxTotalSupply = _maxTotalSupply.toUint128();
		_writeState(state);
		emit MaxTotalSupplyUpdated(_maxTotalSupply);
	}

	function setAnnualInterestBips(uint16 _annualInterestBips) public onlyController nonReentrant {
		VaultState memory state = _getUpdatedState();

		if (_annualInterestBips > BIP) {
			revert InterestRateTooHigh();
		}

		state.annualInterestBips = _annualInterestBips;
		_writeState(state);
		emit AnnualInterestBipsUpdated(_annualInterestBips);
	}

	function setLiquidityCoverageRatio(
		uint16 _liquidityCoverageRatio
	) public onlyController nonReentrant {
		VaultState memory state = _getUpdatedState();

		if (_liquidityCoverageRatio > BIP) {
			revert LiquidityCoverageRatioTooHigh();
		}
		if (state.liquidityRequired() > totalAssets()) {
			revert InsufficientCoverageForNewLiquidityRatio();
		}

		state.liquidityCoverageRatio = _liquidityCoverageRatio;
		_writeState(state);
		emit LiquidityCoverageRatioUpdated(_liquidityCoverageRatio);
	}
}
