// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import '../interfaces/IWildcatSanctionsSentinel.sol';
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
   * @dev Returns whether or not a market has been closed.
   */
  function isClosed() external view returns (bool) {
    MarketState memory state = currentState();
    return state.isClosed;
  }

  /**
   * @dev Returns the maximum amount of underlying asset that can
   *      currently be deposited to the market.
   */
  function maximumDeposit() external view returns (uint256) {
    MarketState memory state = currentState();
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

  function reserveRatioBips() external view returns (uint256) {
    return _state.reserveRatioBips;
  }

  /* -------------------------------------------------------------------------- */
  /*                                  Sanctions                                 */
  /* -------------------------------------------------------------------------- */

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
  function nukeFromOrbit(address accountAddress) external nonReentrant sphereXGuardExternal {
    if (!IWildcatSanctionsSentinel(sentinel).isSanctioned(borrower, accountAddress)) {
      revert_BadLaunchCode();
    }
    MarketState memory state = _getUpdatedState();
    _blockAccount(state, accountAddress);
    _writeState(state);
  }

  /**
   * @dev Unblock an account that was previously sanctioned and blocked
   *      and has since been removed from the sanctions list or had
   *      their sanctioned status overridden by the borrower.
   */
  function stunningReversal(address accountAddress) external nonReentrant sphereXGuardExternal {
    if (IWildcatSanctionsSentinel(sentinel).isSanctioned(borrower, accountAddress)) {
      revert_NotReversedOrStunning();
    }

    Account memory account = _accounts[accountAddress];
    if (account.approval != AuthRole.Blocked) {
      revert_AccountNotBlocked();
    }

    account.approval = AuthRole.WithdrawOnly;
    emit_AuthorizationStatusUpdated(accountAddress, account.approval);

    _accounts[accountAddress] = account;
  }

  /* -------------------------------------------------------------------------- */
  /*                           External Config Setters                          */
  /* -------------------------------------------------------------------------- */

  /**
   * @dev Updates multiple accounts' authorization statuses based on whether the controller
   *      has them marked as approved. Requires that the lender *had* full access (i.e.
   *      they were previously authorized) before dropping them down to WithdrawOnly,
   *      else arbitrary accounts could grant themselves Withdraw.
   */
  function updateAccountAuthorizations(
    address[] memory accounts,
    bool authorize
  ) external onlyController nonReentrant sphereXGuardExternal {
    MarketState memory state = _getUpdatedState();
    for (uint256 i = 0; i < accounts.length; i++) {
      Account memory account = _getAccount(accounts[i]);
      if (authorize) {
        account.approval = AuthRole.DepositAndWithdraw;
      } else if (account.approval == AuthRole.DepositAndWithdraw) {
        account.approval = AuthRole.WithdrawOnly;
      }
      _accounts[accounts[i]] = account;
      emit_AuthorizationStatusUpdated(accounts[i], account.approval);
    }
    _writeState(state);
  }

  /**
   * @dev Sets the maximum total supply - this only limits deposits and
   *      does not affect interest accrual.
   *
   *      Can not be set lower than current total supply.
   */
  function setMaxTotalSupply(
    uint256 _maxTotalSupply
  ) external onlyController nonReentrant sphereXGuardExternal {
    MarketState memory state = _getUpdatedState();

    if (_maxTotalSupply < state.totalSupply()) {
      revert_NewMaxSupplyTooLow();
    }

    state.maxTotalSupply = _maxTotalSupply.toUint128();
    _writeState(state);
    emit_MaxTotalSupplyUpdated(_maxTotalSupply);
  }

  /**
   * @dev Sets the annual interest rate earned by lenders in bips.
   */
  function setAnnualInterestBips(
    uint16 _annualInterestBips
  ) public onlyController nonReentrant sphereXGuardExternal {
    MarketState memory state = _getUpdatedState();

    state.annualInterestBips = _annualInterestBips;
    _writeState(state);
    emit_AnnualInterestBipsUpdated(_annualInterestBips);
  }

  /**
   * @dev Adjust the market's reserve ratio.
   *
   *      If the new ratio is lower than the old ratio,
   *      asserts that the market is not currently delinquent.
   *
   *      If the new ratio is higher than the old ratio,
   *      asserts that the market will not become delinquent
   *      because of the change.
   */
  function setReserveRatioBips(
    uint16 _reserveRatioBips
  ) public onlyController nonReentrant sphereXGuardExternal {
    MarketState memory state = _getUpdatedState();

    uint256 initialReserveRatioBips = state.reserveRatioBips;

    if (_reserveRatioBips < initialReserveRatioBips) {
      if (state.liquidityRequired() > totalAssets()) {
        revert_InsufficientReservesForOldLiquidityRatio();
      }
    }
    state.reserveRatioBips = _reserveRatioBips;
    if (_reserveRatioBips > initialReserveRatioBips) {
      if (state.liquidityRequired() > totalAssets()) {
        revert_InsufficientReservesForNewLiquidityRatio();
      }
    }
    _writeState(state);
    emit_ReserveRatioBipsUpdated(_reserveRatioBips);
  }
}
