// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import '../interfaces/ISanctionsSentinel.sol';
import '../libraries/FeeMath.sol';
import '../libraries/SafeCastLib.sol';
import './WildcatMarketBase.sol';

contract WildcatMarketConfig is WildcatMarketBase {
  using SafeCastLib for uint256;
  using BoolUtils for bool;

  // ===================================================================== //
  //                      External Config Getters                          //
  // ===================================================================== //

  /**
   * @dev Returns the maximum amount of underlying asset that can
   *      currently be deposited to the market.
   */
  function maximumDeposit() external view returns (uint256) {
    VaultState memory state = currentState();
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

  /// @dev Block a sanctioned account from interacting with the market
  ///      and transfer its balance to an escrow contract.
  // ******************************************************************
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
  //  💰🤑💰 *   😅    *    😐    *    💸    `-=#$%&%$#=-'         *
  //   \|/    *   /|\    *   /|\    *  🌪         | ;  :|    🌪       *
  //   /\     * 💰/\ 💰 * 💰/\ 💰 *    _____.,-#%&$@%#&#~,._____    *
  // ******************************************************************
  function nukeFromOrbit(address accountAddress) external {
    if (!ISanctionsSentinel(sentinel).isSanctioned(accountAddress)) {
      revert BadLaunchCode();
    }
    VaultState memory state = _getUpdatedState();
    _blockAccount(state, accountAddress);
    _writeState(state);
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
    if (_liquidityCoverageRatio > BIP) {
      revert LiquidityCoverageRatioTooHigh();
    }

    VaultState memory state = _getUpdatedState();

    uint256 initialLiquidityCoverageRatio = state.liquidityCoverageRatio;

    if (_liquidityCoverageRatio < initialLiquidityCoverageRatio) {
      if (state.liquidityRequired() > totalAssets()) {
        revert InsufficientCoverageForOldLiquidityRatio();
      }
    }
    state.liquidityCoverageRatio = _liquidityCoverageRatio;
    if (_liquidityCoverageRatio > initialLiquidityCoverageRatio) {
      if (state.liquidityRequired() > totalAssets()) {
        revert InsufficientCoverageForNewLiquidityRatio();
      }
    }
    _writeState(state);
    emit LiquidityCoverageRatioUpdated(_liquidityCoverageRatio);
  }
}
