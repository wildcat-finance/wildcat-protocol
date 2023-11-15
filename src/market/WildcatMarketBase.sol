// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import '../libraries/FeeMath.sol';
import '../libraries/Withdrawal.sol';
import { queryName, querySymbol } from '../libraries/StringQuery.sol';
import '../interfaces/IMarketEventsAndErrors.sol';
import '../interfaces/IWildcatMarketController.sol';
import '../interfaces/IWildcatSanctionsSentinel.sol';
import { IERC20, IERC20Metadata } from '../interfaces/IERC20Metadata.sol';
import '../ReentrancyGuard.sol';
import '../libraries/BoolUtils.sol'; 
import {SphereXProtected} from "@spherex-xyz/contracts/src/SphereXProtected.sol";
 

contract WildcatMarketBase is ReentrancyGuard, IMarketEventsAndErrors {
  using WithdrawalLib for MarketState;
  using SafeCastLib for uint256;
  using MathUtils for uint256;
  using BoolUtils for bool;

  // ==================================================================== //
  //                       Market Config (immutable)                       //
  // ==================================================================== //

  string public constant version = '1.0';

  /// @dev Account with blacklist control, used for blocking sanctioned addresses.
  address public immutable sentinel;

  /// @dev Account with authority to borrow assets from the market.
  address public immutable borrower;

  /// @dev Account that receives protocol fees.
  address public immutable feeRecipient;

  /// @dev Protocol fee added to interest paid by borrower.
  uint256 public immutable protocolFeeBips;

  /// @dev Penalty fee added to interest earned by lenders, does not affect protocol fee.
  uint256 public immutable delinquencyFeeBips;

  /// @dev Time after which delinquency incurs penalty fee.
  uint256 public immutable delinquencyGracePeriod;

  /// @dev Address of the Market Controller.
  address public immutable controller;

  /// @dev Address of the underlying asset.
  address public immutable asset;

  /// @dev Time before withdrawal batches are processed.
  uint256 public immutable withdrawalBatchDuration;

  /// @dev Token decimals (same as underlying asset).
  uint8 public immutable decimals;

  /// @dev Token name (prefixed name of underlying asset).
  string public name;

  /// @dev Token symbol (prefixed symbol of underlying asset).
  string public symbol;

  // ===================================================================== //
  //                             Market State                               //
  // ===================================================================== //

  MarketState internal _state;

  mapping(address => Account) internal _accounts;

  WithdrawalData internal _withdrawalData;

  // ===================================================================== //
  //                             Constructor                               //
  // ===================================================================== //

  constructor() {
    MarketParameters memory parameters = IWildcatMarketController(msg.sender).getMarketParameters();

    if ((parameters.protocolFeeBips > 0).and(parameters.feeRecipient == address(0))) {
      revert FeeSetWithoutRecipient();
    }
    if (parameters.annualInterestBips > BIP) {
      revert InterestRateTooHigh();
    }
    if (parameters.reserveRatioBips > BIP) {
      revert ReserveRatioBipsTooHigh();
    }
    if (parameters.protocolFeeBips > BIP) {
      revert InterestFeeTooHigh();
    }
    if (parameters.delinquencyFeeBips > BIP) {
      revert PenaltyFeeTooHigh();
    }

    // Set asset metadata
    asset = parameters.asset;
    name = string.concat(parameters.namePrefix, queryName(parameters.asset));
    symbol = string.concat(parameters.symbolPrefix, querySymbol(parameters.asset));
    decimals = IERC20Metadata(parameters.asset).decimals();

    _state = MarketState({
      isClosed: false,
      maxTotalSupply: parameters.maxTotalSupply,
      accruedProtocolFees: 0,
      normalizedUnclaimedWithdrawals: 0,
      scaledTotalSupply: 0,
      scaledPendingWithdrawals: 0,
      pendingWithdrawalExpiry: 0,
      isDelinquent: false,
      timeDelinquent: 0,
      annualInterestBips: parameters.annualInterestBips,
      reserveRatioBips: parameters.reserveRatioBips,
      scaleFactor: uint112(RAY),
      lastInterestAccruedTimestamp: uint32(block.timestamp)
    });

    sentinel = parameters.sentinel;
    borrower = parameters.borrower;
    controller = parameters.controller;
    feeRecipient = parameters.feeRecipient;
    protocolFeeBips = parameters.protocolFeeBips;
    delinquencyFeeBips = parameters.delinquencyFeeBips;
    delinquencyGracePeriod = parameters.delinquencyGracePeriod;
    withdrawalBatchDuration = parameters.withdrawalBatchDuration;
  }

  // ===================================================================== //
  //                              Modifiers                                //
  // ===================================================================== //

  modifier onlyBorrower() {
    if (msg.sender != borrower) revert NotApprovedBorrower();
    _;
  }

  modifier onlyController() {
    if (msg.sender != controller) revert NotController();
    _;
  }

  // ===================================================================== //
  //                       Internal State Getters                          //
  // ===================================================================== //

  /**
   * @dev Retrieve an account from storage.
   *
   *      Reverts if account is blocked.
   */
  function _getAccount(address accountAddress) internal view returns (Account memory account) {
    account = _accounts[accountAddress];
    if (account.approval == AuthRole.Blocked) {
      revert AccountBlacklisted();
    }
  }

  /**
   * @dev Block an account and transfer its balance of market tokens
   *      to an escrow contract.
   *
   *      If the account is already blocked, this function does nothing.
   */
  function _blockAccount(MarketState memory state, address accountAddress) internal sphereXGuardInternal(0x4c77e603) {
    Account memory account = _accounts[accountAddress];
    if (account.approval != AuthRole.Blocked) {
      uint104 scaledBalance = account.scaledBalance;
      account.approval = AuthRole.Blocked;
      emit AuthorizationStatusUpdated(accountAddress, AuthRole.Blocked);

      if (scaledBalance > 0) {
        account.scaledBalance = 0;
        address escrow = IWildcatSanctionsSentinel(sentinel).createEscrow(
          borrower,
          accountAddress,
          address(this)
        );
        emit Transfer(accountAddress, escrow, state.normalizeAmount(scaledBalance));
        _accounts[escrow].scaledBalance += scaledBalance;
        emit SanctionedAccountAssetsSentToEscrow(
          accountAddress,
          escrow,
          state.normalizeAmount(scaledBalance)
        );
      }
      _accounts[accountAddress] = account;
    }
  }

  /**
   * @dev Retrieve an account from storage and assert that it has at
   *      least the required role.
   *
   *      If the account's role is not set, queries the controller to
   *      determine if it is an approved lender; if it is, its role
   *      is initialized to DepositAndWithdraw.
   */
  function _getAccountWithRole(
    address accountAddress,
    AuthRole requiredRole
  ) internal sphereXGuardInternal(0x34aa4264) returns (Account memory account) {
    account = _getAccount(accountAddress);
    // If account role is null, see if it is authorized on controller.
    if (account.approval == AuthRole.Null) {
      if (IWildcatMarketController(controller).isAuthorizedLender(accountAddress)) {
        account.approval = AuthRole.DepositAndWithdraw;
        emit AuthorizationStatusUpdated(accountAddress, AuthRole.DepositAndWithdraw);
      }
    }
    // If account role is insufficient, revert.
    if (uint256(account.approval) < uint256(requiredRole)) {
      revert NotApprovedLender();
    }
  }

  // ===================================================================== //
  //                       External State Getters                          //
  // ===================================================================== //

  /**
   * @dev Returns the amount of underlying assets the borrower is obligated
   *      to maintain in the market to avoid delinquency.
   */
  function coverageLiquidity() external view nonReentrantView returns (uint256) {
    return currentState().liquidityRequired();
  }

  /**
   * @dev Returns the scale factor (in ray) used to convert scaled balances
   *      to normalized balances.
   */
  function scaleFactor() external view nonReentrantView returns (uint256) {
    return currentState().scaleFactor;
  }

  /**
   * @dev Total balance in underlying asset.
   */
  function totalAssets() public view returns (uint256) {
    return IERC20(asset).balanceOf(address(this));
  }

  /**
   * @dev Returns the amount of underlying assets the borrower is allowed
   *      to borrow.
   *
   *      This is the balance of underlying assets minus:
   *      - pending (unpaid) withdrawals
   *      - paid withdrawals
   *      - reserve ratio times the portion of the supply not pending withdrawal
   *      - protocol fees
   */
  function borrowableAssets() external view nonReentrantView returns (uint256) {
    return currentState().borrowableAssets(totalAssets());
  }

  /**
   * @dev Returns the amount of protocol fees (in underlying asset amount)
   *      that have accrued and are pending withdrawal.
   */
  function accruedProtocolFees() external view nonReentrantView returns (uint256) {
    return currentState().accruedProtocolFees;
  }

  function totalDebts() external view nonReentrantView returns (uint256) {
    return currentState().totalDebts();
  }

  function outstandingDebt() external view nonReentrantView returns (uint256) {
    return currentState().totalDebts().satSub(totalAssets());
  }

  function delinquentDebt() external view nonReentrantView returns (uint256) {
    return currentState().liquidityRequired().satSub(totalAssets());
  }

  /**
   * @dev Returns the state of the market as of the last update.
   */
  function previousState() external view returns (MarketState memory) {
    return _state;
  }

  /**
   * @dev Return the state the market would have at the current block after applying
   *      interest and fees accrued since the last update and processing the pending
   *      withdrawal batch if it is expired.
   */
  function currentState() public view nonReentrantView returns (MarketState memory state) {
    (state, , ) = _calculateCurrentState();
  }

  /**
   * @dev Returns the scaled total supply the vaut would have at the current block
   *      after applying interest and fees accrued since the last update and burning
   *      market tokens for the pending withdrawal batch if it is expired.
   */
  function scaledTotalSupply() external view nonReentrantView returns (uint256) {
    return currentState().scaledTotalSupply;
  }

  /**
   * @dev Returns the scaled balance of `account`
   */
  function scaledBalanceOf(address account) external view nonReentrantView returns (uint256) {
    return _accounts[account].scaledBalance;
  }

  /**
   * @dev Returns current role of `account`.
   */
  function getAccountRole(address account) external view nonReentrantView returns (AuthRole) {
    return _accounts[account].approval;
  }

  /**
   * @dev Returns the amount of protocol fees that are currently
   *      withdrawable by the fee recipient.
   */
  function withdrawableProtocolFees() external view returns (uint128) {
    return currentState().withdrawableProtocolFees(totalAssets());
  }

  /**
   * @dev Calculate effective interest rate currently paid by borrower.
   *      Borrower pays base APR, protocol fee (on base APR) and delinquency
   *      fee (if delinquent beyond grace period).
   *
   * @return apr paid by borrower in ray
   */
  function effectiveBorrowerAPR() external view returns (uint256) {
    MarketState memory state = currentState();
    // apr + (apr * protocolFee)
    uint256 apr = MathUtils.bipToRay(state.annualInterestBips).bipMul(BIP + protocolFeeBips);
    if (state.timeDelinquent > delinquencyGracePeriod) {
      apr += MathUtils.bipToRay(delinquencyFeeBips);
    }
    return apr;
  }

  /**
   * @dev Calculate effective interest rate currently earned by lenders.
   *     Lenders earn base APR and delinquency fee (if delinquent beyond grace period)
   *
   * @return apr earned by lender in ray
   */
  function effectiveLenderAPR() external view returns (uint256) {
    MarketState memory state = currentState();
    uint256 apr = state.annualInterestBips;
    if (state.timeDelinquent > delinquencyGracePeriod) {
      apr += delinquencyFeeBips;
    }
    return MathUtils.bipToRay(apr);
  }

  // /*//////////////////////////////////////////////////////////////
  //                     Internal State Handlers
  // //////////////////////////////////////////////////////////////*/

  /**
   * @dev Returns cached MarketState after accruing interest and delinquency / protocol fees
   *      and processing expired withdrawal batch, if any.
   *
   *      Used by functions that make additional changes to `state`.
   *
   *      NOTE: Returned `state` does not match `_state` if interest is accrued
   *            Calling function must update `_state` or revert.
   *
   * @return state Market state after interest is accrued.
   */
  function _getUpdatedState() internal sphereXGuardInternal(0xd43ccb27) returns (MarketState memory state) {
    state = _state;
    // Handle expired withdrawal batch
    if (state.hasPendingExpiredBatch()) {
      uint256 expiry = state.pendingWithdrawalExpiry;
      // Only accrue interest if time has passed since last update.
      // This will only be false if withdrawalBatchDuration is 0.
      uint32 lastInterestAccruedTimestamp = state.lastInterestAccruedTimestamp;
      if (expiry != lastInterestAccruedTimestamp) {
        (uint256 baseInterestRay, uint256 delinquencyFeeRay, uint256 protocolFee) = state
          .updateScaleFactorAndFees(
            protocolFeeBips,
            delinquencyFeeBips,
            delinquencyGracePeriod,
            expiry
          );
        emit InterestAndFeesAccrued(
          lastInterestAccruedTimestamp,
          expiry,
          state.scaleFactor,
          baseInterestRay,
          delinquencyFeeRay,
          protocolFee
        );
      }
      _processExpiredWithdrawalBatch(state);
    }
    uint32 lastInterestAccruedTimestamp = state.lastInterestAccruedTimestamp;
    // Apply interest and fees accrued since last update (expiry or previous tx)
    if (block.timestamp != lastInterestAccruedTimestamp) {
      (uint256 baseInterestRay, uint256 delinquencyFeeRay, uint256 protocolFee) = state
        .updateScaleFactorAndFees(
          protocolFeeBips,
          delinquencyFeeBips,
          delinquencyGracePeriod,
          block.timestamp
        );
      emit InterestAndFeesAccrued(
        lastInterestAccruedTimestamp,
        block.timestamp,
        state.scaleFactor,
        baseInterestRay,
        delinquencyFeeRay,
        protocolFee
      );
    }

    // If there is a pending withdrawal batch which is not fully paid off, set aside
    // up to the available liquidity for that batch.
    if (state.pendingWithdrawalExpiry != 0) {
      uint32 expiry = state.pendingWithdrawalExpiry;
      WithdrawalBatch memory batch = _withdrawalData.batches[expiry];
      if (batch.scaledAmountBurned < batch.scaledTotalAmount) {
        // Burn as much of the withdrawal batch as possible with available liquidity.
        uint256 availableLiquidity = batch.availableLiquidityForPendingBatch(state, totalAssets());
        if (availableLiquidity > 0) {
          _applyWithdrawalBatchPayment(batch, state, expiry, availableLiquidity);
          _withdrawalData.batches[expiry] = batch;
        }
      }
    }
  }

  /**
   * @dev Calculate the current state, applying fees and interest accrued since
   *      the last state update as well as the effects of withdrawal batch expiry
   *      on the market state.
   *      Identical to _getUpdatedState() except it does not modify storage or
   *      or emit events.
   *      Returns expired batch data, if any, so queries against batches have
   *      access to the most recent data.
   */
  function _calculateCurrentState()
    internal
    view
    returns (
      MarketState memory state,
      uint32 pendingBatchExpiry,
      WithdrawalBatch memory pendingBatch
    )
  {
    state = _state;
    // Handle expired withdrawal batch
    if (state.hasPendingExpiredBatch()) {
      pendingBatchExpiry = state.pendingWithdrawalExpiry;
      // Only accrue interest if time has passed since last update.
      // This will only be false if withdrawalBatchDuration is 0.
      if (pendingBatchExpiry != state.lastInterestAccruedTimestamp) {
        state.updateScaleFactorAndFees(
          protocolFeeBips,
          delinquencyFeeBips,
          delinquencyGracePeriod,
          pendingBatchExpiry
        );
      }

      pendingBatch = _withdrawalData.batches[pendingBatchExpiry];
      uint256 availableLiquidity = pendingBatch.availableLiquidityForPendingBatch(
        state,
        totalAssets()
      );
      if (availableLiquidity > 0) {
        _applyWithdrawalBatchPaymentView(pendingBatch, state, availableLiquidity);
      }
      state.pendingWithdrawalExpiry = 0;
    }

    if (state.lastInterestAccruedTimestamp != block.timestamp) {
      state.updateScaleFactorAndFees(
        protocolFeeBips,
        delinquencyFeeBips,
        delinquencyGracePeriod,
        block.timestamp
      );
    }

    // If there is a pending withdrawal batch which is not fully paid off, set aside
    // up to the available liquidity for that batch.
    if (state.pendingWithdrawalExpiry != 0) {
      pendingBatchExpiry = state.pendingWithdrawalExpiry;
      pendingBatch = _withdrawalData.batches[pendingBatchExpiry];
      if (pendingBatch.scaledAmountBurned < pendingBatch.scaledTotalAmount) {
        // Burn as much of the withdrawal batch as possible with available liquidity.
        uint256 availableLiquidity = pendingBatch.availableLiquidityForPendingBatch(
          state,
          totalAssets()
        );
        if (availableLiquidity > 0) {
          _applyWithdrawalBatchPaymentView(pendingBatch, state, availableLiquidity);
        }
      }
    }
  }

  /**
   * @dev Writes the cached MarketState to storage and emits an event.
   *      Used at the end of all functions which modify `state`.
   */
  function _writeState(MarketState memory state) internal sphereXGuardInternal(0xe4b993bf) {
    bool isDelinquent = state.liquidityRequired() > totalAssets();
    state.isDelinquent = isDelinquent;
    _state = state;
    emit StateUpdated(state.scaleFactor, isDelinquent);
  }

  /**
   * @dev Handles an expired withdrawal batch:
   *      - Retrieves the amount of underlying assets that can be used to pay for the batch.
   *      - If the amount is sufficient to pay the full amount owed to the batch, the batch
   *        is closed and the total withdrawal amount is reserved.
   *      - If the amount is insufficient to pay the full amount owed to the batch, the batch
   *        is recorded as an unpaid batch and the available assets are reserved.
   *      - The assets reserved for the batch are scaled by the current scale factor and that
   *        amount of scaled tokens is burned, ensuring borrowers do not continue paying interest
   *        on withdrawn assets.
   */
  function _processExpiredWithdrawalBatch(MarketState memory state) internal sphereXGuardInternal(0x0efe0e5b) {
    uint32 expiry = state.pendingWithdrawalExpiry;
    WithdrawalBatch memory batch = _withdrawalData.batches[expiry];

    if (batch.scaledAmountBurned < batch.scaledTotalAmount) {
      // Burn as much of the withdrawal batch as possible with available liquidity.
      uint256 availableLiquidity = batch.availableLiquidityForPendingBatch(state, totalAssets());
      if (availableLiquidity > 0) {
        _applyWithdrawalBatchPayment(batch, state, expiry, availableLiquidity);
      }
    }

    emit WithdrawalBatchExpired(
      expiry,
      batch.scaledTotalAmount,
      batch.scaledAmountBurned,
      batch.normalizedAmountPaid
    );

    if (batch.scaledAmountBurned < batch.scaledTotalAmount) {
      _withdrawalData.unpaidBatches.push(expiry);
    } else {
      emit WithdrawalBatchClosed(expiry);
    }

    state.pendingWithdrawalExpiry = 0;

    _withdrawalData.batches[expiry] = batch;
  }

  /**
   * @dev Process withdrawal payment, burning market tokens and reserving
   *      underlying assets so they are only available for withdrawals.
   */
  function _applyWithdrawalBatchPayment(
    WithdrawalBatch memory batch,
    MarketState memory state,
    uint32 expiry,
    uint256 availableLiquidity
  ) internal sphereXGuardInternal(0x358cb018) {
    uint104 scaledAmountOwed = batch.scaledTotalAmount - batch.scaledAmountBurned;
    // Do nothing if batch is already paid
    if (scaledAmountOwed == 0) {
      return;
    }

    uint256 scaledAvailableLiquidity = state.scaleAmount(availableLiquidity);
    uint104 scaledAmountBurned = MathUtils
      .min(scaledAvailableLiquidity, scaledAmountOwed)
      .toUint104();
    uint128 normalizedAmountPaid = state.normalizeAmount(scaledAmountBurned).toUint128();

    batch.scaledAmountBurned += scaledAmountBurned;
    batch.normalizedAmountPaid += normalizedAmountPaid;
    state.scaledPendingWithdrawals -= scaledAmountBurned;

    // Update normalizedUnclaimedWithdrawals so the tokens are only accessible for withdrawals.
    state.normalizedUnclaimedWithdrawals += normalizedAmountPaid;

    // Burn market tokens to stop interest accrual upon withdrawal payment.
    state.scaledTotalSupply -= scaledAmountBurned;

    // Emit transfer for external trackers to indicate burn.
    emit Transfer(address(this), address(0), normalizedAmountPaid);
    emit WithdrawalBatchPayment(expiry, scaledAmountBurned, normalizedAmountPaid);
  }

  function _applyWithdrawalBatchPaymentView(
    WithdrawalBatch memory batch,
    MarketState memory state,
    uint256 availableLiquidity
  ) internal pure {
    uint104 scaledAmountOwed = batch.scaledTotalAmount - batch.scaledAmountBurned;
    // Do nothing if batch is already paid
    if (scaledAmountOwed == 0) {
      return;
    }
    uint256 scaledAvailableLiquidity = state.scaleAmount(availableLiquidity);
    uint104 scaledAmountBurned = MathUtils
      .min(scaledAvailableLiquidity, scaledAmountOwed)
      .toUint104();
    uint128 normalizedAmountPaid = state.normalizeAmount(scaledAmountBurned).toUint128();

    batch.scaledAmountBurned += scaledAmountBurned;
    batch.normalizedAmountPaid += normalizedAmountPaid;
    state.scaledPendingWithdrawals -= scaledAmountBurned;

    // Update normalizedUnclaimedWithdrawals so the tokens are only accessible for withdrawals.
    state.normalizedUnclaimedWithdrawals += normalizedAmountPaid;

    // Burn market tokens to stop interest accrual upon withdrawal payment.
    state.scaledTotalSupply -= scaledAmountBurned;
  }
}
