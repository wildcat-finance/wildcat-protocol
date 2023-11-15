// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import '../interfaces/IWildcatSanctionsSentinel.sol';
import '../libraries/FeeMath.sol';
import '../libraries/SafeCastLib.sol';
import './WildcatMarketBase.sol'; 
import {SphereXProtected} from "@spherex-xyz/contracts/src/SphereXProtected.sol";
 

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
  function nukeFromOrbit(address accountAddress) external nonReentrant sphereXGuardExternal(0x60f4e8f2) {
    if (!IWildcatSanctionsSentinel(sentinel).isSanctioned(borrower, accountAddress)) {
      revert BadLaunchCode();
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
  function stunningReversal(address accountAddress) external nonReentrant sphereXGuardExternal(0x0fd4fa83) {
    if (IWildcatSanctionsSentinel(sentinel).isSanctioned(borrower, accountAddress)) {
      revert NotReversedOrStunning();
    }

    Account memory account = _accounts[accountAddress];
    if (account.approval != AuthRole.Blocked) {
      revert AccountNotBlocked();
    }

    account.approval = AuthRole.WithdrawOnly;
    emit AuthorizationStatusUpdated(accountAddress, account.approval);

    _accounts[accountAddress] = account;
  }

  /* -------------------------------------------------------------------------- */
  /*                           External Config Setters                          */
  /* -------------------------------------------------------------------------- */

  /**
   * @dev Updates an account's authorization status based on whether the controller
   *      has it marked as approved. Requires that the lender *had* full access (i.e.
   *      they were previously authorized) before dropping them down to WithdrawOnly,
   *      else arbitrary accounts could grant themselves Withdraw.
   */
  function updateAccountAuthorization(
    address _account,
    bool _isAuthorized
  ) external onlyController nonReentrant sphereXGuardExternal(0xe0a58fb6) {
    MarketState memory state = _getUpdatedState();
    Account memory account = _getAccount(_account);
    if (_isAuthorized) {
      account.approval = AuthRole.DepositAndWithdraw;
    } else if (account.approval == AuthRole.DepositAndWithdraw) {
      account.approval = AuthRole.WithdrawOnly;
    }
    _accounts[_account] = account;
    _writeState(state);
    emit AuthorizationStatusUpdated(_account, account.approval);
  }

  /**
   * @dev Sets the maximum total supply - this only limits deposits and
   *      does not affect interest accrual.
   *
   *      Can not be set lower than current total supply.
   */
  function setMaxTotalSupply(uint256 _maxTotalSupply) external onlyController nonReentrant sphereXGuardExternal(0xfd0bfd91) {
    MarketState memory state = _getUpdatedState();

    if (_maxTotalSupply < state.totalSupply()) {
      revert NewMaxSupplyTooLow();
    }

    state.maxTotalSupply = _maxTotalSupply.toUint128();
    _writeState(state);
    emit MaxTotalSupplyUpdated(_maxTotalSupply);
  }

  /**
   * @dev Sets the annual interest rate earned by lenders in bips.
   */
  function setAnnualInterestBips(uint16 _annualInterestBips) public onlyController nonReentrant sphereXGuardPublic(0x850ae35d, 0x5c559e14) {
    if (_annualInterestBips > BIP) {
      revert InterestRateTooHigh();
    }

    MarketState memory state = _getUpdatedState();

    state.annualInterestBips = _annualInterestBips;
    _writeState(state);
    emit AnnualInterestBipsUpdated(_annualInterestBips);
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
  function setReserveRatioBips(uint16 _reserveRatioBips) public onlyController nonReentrant sphereXGuardPublic(0xc1a48714, 0x6dd4f521) {
    if (_reserveRatioBips > BIP) {
      revert ReserveRatioBipsTooHigh();
    }

    MarketState memory state = _getUpdatedState();

    uint256 initialReserveRatioBips = state.reserveRatioBips;

    if (_reserveRatioBips < initialReserveRatioBips) {
      if (state.liquidityRequired() > totalAssets()) {
        revert InsufficientReservesForOldLiquidityRatio();
      }
    }
    state.reserveRatioBips = _reserveRatioBips;
    if (_reserveRatioBips > initialReserveRatioBips) {
      if (state.liquidityRequired() > totalAssets()) {
        revert InsufficientReservesForNewLiquidityRatio();
      }
    }
    _writeState(state);
    emit ReserveRatioBipsUpdated(_reserveRatioBips);
  }
}
