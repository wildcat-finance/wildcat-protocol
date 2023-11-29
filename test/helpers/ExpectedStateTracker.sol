// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;
import { MockERC20 } from 'solmate/test/utils/mocks/MockERC20.sol';
import 'src/market/WildcatMarket.sol';
import 'src/WildcatSanctionsEscrow.sol';
import '../shared/TestConstants.sol';
import './Assertions.sol';
import '../shared/Test.sol';
import { Account as MarketAccount } from 'src/libraries/MarketState.sol';

contract ExpectedStateTracker is Test, Assertions, IMarketEventsAndErrors {
  using FeeMath for MarketState;
  using SafeCastLib for uint256;
  using MathUtils for uint256;
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableSet for EnumerableSet.UintSet;

  bytes32 public constant WildcatSanctionsEscrowInitcodeHash =
    keccak256(type(WildcatSanctionsEscrow).creationCode);

  MarketParameters internal parameters;

  MarketState internal previousState;
  WithdrawalData internal _withdrawalData;
  uint256 internal lastTotalAssets;
  EnumerableSet.AddressSet internal touchedAccounts;
  EnumerableSet.UintSet internal touchedBatches;
  mapping(uint32 => EnumerableSet.AddressSet) internal touchedAccountsByBatch;

  mapping(address => MarketAccount) private accounts;

  constructor() Test() {
    parameters = MarketParameters({
      asset: address(0),
      namePrefix: 'Wildcat ',
      symbolPrefix: 'WC',
      borrower: borrower,
      controller: address(0),
      feeRecipient: feeRecipient,
      sentinel: address(sanctionsSentinel),
      maxTotalSupply: uint128(DefaultMaximumSupply),
      protocolFeeBips: DefaultProtocolFeeBips,
      annualInterestBips: DefaultInterest,
      delinquencyFeeBips: DefaultDelinquencyFee,
      withdrawalBatchDuration: DefaultWithdrawalBatchDuration,
      reserveRatioBips: DefaultReserveRatio,
      delinquencyGracePeriod: DefaultGracePeriod,
      sphereXAdmin: address(0),
      sphereXOperator: address(0),
      sphereXEngine: address(0)
    });
  }


  function calculateEscrowAddress(
    address accountAddress,
    address asset
  ) internal view returns (address) {
    return
      address(
        uint160(
          uint256(
            keccak256(
              abi.encodePacked(
                bytes1(0xff),
                parameters.sentinel,
                keccak256(abi.encode(parameters.borrower, accountAddress, asset)),
                WildcatSanctionsEscrowInitcodeHash
              )
            )
          )
        )
      );
  }

  function pendingState() internal returns (MarketState memory state) {
    state = previousState;
    //
    if (block.timestamp > state.pendingWithdrawalExpiry && state.pendingWithdrawalExpiry != 0) {
      uint256 expiry = state.pendingWithdrawalExpiry;
      if (expiry != state.lastInterestAccruedTimestamp) {
        state.updateScaleFactorAndFees(
          parameters.protocolFeeBips,
          parameters.delinquencyFeeBips,
          parameters.delinquencyGracePeriod,
          expiry
        );
      }
      _processExpiredWithdrawalBatch(state);
    }
    if (block.timestamp != state.lastInterestAccruedTimestamp) {
      state.updateScaleFactorAndFees(
        parameters.protocolFeeBips,
        parameters.delinquencyFeeBips,
        parameters.delinquencyGracePeriod,
        block.timestamp
      );
    }
    if (state.pendingWithdrawalExpiry != 0) {
      uint32 pendingBatchExpiry = state.pendingWithdrawalExpiry;
      WithdrawalBatch storage pendingBatch = _withdrawalData.batches[pendingBatchExpiry];
      if (pendingBatch.scaledAmountBurned < pendingBatch.scaledTotalAmount) {
        // Burn as much of the withdrawal batch as possible with available liquidity.
        uint256 availableLiquidity = pendingBatch.availableLiquidityForPendingBatch(
          state,
          lastTotalAssets
        );
        if (availableLiquidity > 0) {
          _applyWithdrawalBatchPayment(pendingBatch, state, pendingBatchExpiry, availableLiquidity);
        }
      }
    }
  }

  function updateState(MarketState memory state) internal {
    state.isDelinquent = state.liquidityRequired() > lastTotalAssets;
    previousState = state;
  }

  /* -------------------------------------------------------------------------- */
  /*                                   Checks                                   */
  /* -------------------------------------------------------------------------- */

  function _checkAccount(MarketState memory state, address accountAddress) internal {
    (uint104 scaledBalance, uint256 normalizedBalance) = _getBalance(state, accountAddress);
    assertEq(market.scaledBalanceOf(accountAddress), scaledBalance, 'scaledBalance');
    assertEq(market.balanceOf(accountAddress), normalizedBalance, 'normalizedBalance');
  }

  function _checkWithdrawalBatch(uint32 expiry) internal {
    WithdrawalBatch storage expectedBatch = _getWithdrawalBatch(expiry);
    WithdrawalBatch memory actualBatch = market.getWithdrawalBatch(expiry);
    string memory key = string.concat('Batch ', LibString.toString(expiry), ': ');
    assertEq(
      actualBatch.scaledTotalAmount,
      expectedBatch.scaledTotalAmount,
      string.concat(key, 'scaledTotalAmount')
    );
    assertEq(
      actualBatch.scaledAmountBurned,
      expectedBatch.scaledAmountBurned,
      string.concat(key, 'scaledAmountBurned')
    );
    assertEq(
      actualBatch.normalizedAmountPaid,
      expectedBatch.normalizedAmountPaid,
      string.concat(key, 'normalizedAmountPaid')
    );
  }

  function _checkWithdrawalStatus(uint32 expiry, address accountAddress) internal {
    AccountWithdrawalStatus storage expectedStatus = _getWithdrawalStatus(expiry, accountAddress);
    AccountWithdrawalStatus memory actualStatus = market.getAccountWithdrawalStatus(
      accountAddress,
      expiry
    );
    assertEq(actualStatus.scaledAmount, expectedStatus.scaledAmount, 'scaledAmount');
    assertEq(
      actualStatus.normalizedAmountWithdrawn,
      expectedStatus.normalizedAmountWithdrawn,
      'normalizedAmountWithdrawn'
    );
  }

  function _checkState(string memory key) internal {
    assertEq(market.previousState(), previousState, string.concat(key, 'previousState'));
    MarketState memory state = pendingState();
    updateState(state);
    assertEq(market.currentState(), state, string.concat(key, 'currentState'));
    assertEq(market.totalAssets(), lastTotalAssets, string.concat(key, 'totalAssets'));

    address[] memory accountsTouched = touchedAccounts.values();
    for (uint256 i = 0; i < accountsTouched.length; i++) {
      _checkAccount(state, accountsTouched[i]);
    }
    uint256[] memory batchesTouched = touchedBatches.values();
    for (uint256 i = 0; i < batchesTouched.length; i++) {
      uint32 expiry = uint32(batchesTouched[i]);
      _checkWithdrawalBatch(expiry);
      address[] memory accountsTouchedByBatch = touchedAccountsByBatch[expiry].values();
      for (uint256 j = 0; j < accountsTouchedByBatch.length; j++) {
        _checkWithdrawalStatus(expiry, accountsTouchedByBatch[j]);
      }
    }
    uint32[] memory unpaidBatches = _withdrawalData.unpaidBatches.values();
    assertEq(market.getUnpaidBatchExpiries(), unpaidBatches, string.concat(key, 'unpaidBatches'));
  }

  function _checkState() internal {
    _checkState('');
  }

  /* -------------------------------------------------------------------------- */
  /*                               Tracked Getters                              */
  /* -------------------------------------------------------------------------- */

  function _getAccount(address accountAddress) internal returns (MarketAccount storage) {
    touchedAccounts.add(accountAddress);
    return accounts[accountAddress];
  }

  function _getWithdrawalBatch(uint32 expiry) internal returns (WithdrawalBatch storage) {
    touchedBatches.add(uint256(expiry));
    return _withdrawalData.batches[expiry];
  }

  function _getWithdrawalStatus(
    uint32 expiry,
    address accountAddress
  ) internal returns (AccountWithdrawalStatus storage) {
    touchedAccountsByBatch[expiry].add(accountAddress);
    return _withdrawalData.accountStatuses[expiry][accountAddress];
  }

  function _getBalance(
    MarketState memory state,
    address accountAddress
  ) internal returns (uint104 scaledBalance, uint256 normalizedBalance) {
    MarketAccount storage account = _getAccount(accountAddress);
    scaledBalance = account.scaledBalance;
    if (scaledBalance == 0) {
      return (0, 0);
    }
    normalizedBalance = state.normalizeAmount(scaledBalance);
  }

  /* -------------------------------------------------------------------------- */
  /*                               Action Trackers                              */
  /* -------------------------------------------------------------------------- */

  function _trackBlockAccount(MarketState memory state, address accountAddress) internal {
    vm.expectEmit(address(market));
    emit AuthorizationStatusUpdated(accountAddress, AuthRole.Blocked);

    MarketAccount storage account = _getAccount(accountAddress);

    uint104 scaledBalance = account.scaledBalance;
    if (scaledBalance > 0) {
      uint256 normalizedBalance = state.normalizeAmount(scaledBalance);
      account.scaledBalance = 0;
      account.approval = AuthRole.Blocked;
      address escrowAddress = calculateEscrowAddress(accountAddress, address(market));
      _getAccount(escrowAddress).scaledBalance += scaledBalance;
      vm.expectEmit(address(market));
      emit Transfer(accountAddress, escrowAddress, normalizedBalance);
      vm.expectEmit(address(market));
      emit SanctionedAccountAssetsSentToEscrow(accountAddress, escrowAddress, normalizedBalance);
    }
  }

  function _trackDeposit(
    MarketState memory state,
    address accountAddress,
    uint256 normalizedAmount
  ) internal returns (uint104 scaledAmount, uint256 actualNormalizedAmount) {
    actualNormalizedAmount = MathUtils.min(normalizedAmount, state.maximumDeposit());

    scaledAmount = state.scaleAmount(actualNormalizedAmount).toUint104();
    MarketAccount storage account = _getAccount(accountAddress);

    account.scaledBalance += scaledAmount;
    state.scaledTotalSupply += scaledAmount;
    lastTotalAssets += actualNormalizedAmount;

    updateState(state);
  }

  function _trackQueueWithdrawal(
    MarketState memory state,
    address accountAddress,
    uint256 normalizedAmount
  ) internal returns (uint32 expiry, uint104 scaledAmount) {
    scaledAmount = state.scaleAmount(normalizedAmount).toUint104();

    _getAccount(accountAddress).scaledBalance -= scaledAmount;
    vm.expectEmit(address(market));
    emit Transfer(accountAddress, address(market), normalizedAmount);

    if (state.pendingWithdrawalExpiry == 0) {
      state.pendingWithdrawalExpiry = uint32(block.timestamp + parameters.withdrawalBatchDuration);
      vm.expectEmit(address(market));
      emit WithdrawalBatchCreated(state.pendingWithdrawalExpiry);
    }
    expiry = state.pendingWithdrawalExpiry;

    _getWithdrawalStatus(expiry, accountAddress).scaledAmount += scaledAmount;
    WithdrawalBatch storage batch = _getWithdrawalBatch(expiry);
    batch.scaledTotalAmount += scaledAmount;
    state.scaledPendingWithdrawals += scaledAmount;

    vm.expectEmit(address(market));
    emit WithdrawalQueued(expiry, accountAddress, scaledAmount, normalizedAmount);

    uint256 availableLiquidity = _availableLiquidityForPendingBatch(batch, state);
    if (availableLiquidity > 0) {
      _applyWithdrawalBatchPayment(batch, state, expiry, availableLiquidity);
    }

    updateState(state);
  }

  function _trackExecuteWithdrawal(
    MarketState memory state,
    uint32 expiry,
    address accountAddress,
    uint256 withdrawalAmount,
    bool willBeBlocked,
    bool willBeEscrowed
  ) internal {
    // bool isSanctioned = sanctionsSentinel.isSanctioned(borrower, accountAddress);
    // bool willBeBlocked = isSanctioned && market.getAccountRole(accountAddress) != AuthRole.Blocked;
    if (willBeBlocked) {
      _trackBlockAccount(state, accountAddress);
    }

    if (willBeEscrowed) {
      address escrow = calculateEscrowAddress(accountAddress, parameters.asset);
      vm.expectEmit(parameters.asset);
      emit Transfer(address(market), escrow, withdrawalAmount);
      vm.expectEmit(address(market));
      emit SanctionedAccountWithdrawalSentToEscrow(
        accountAddress,
        escrow,
        expiry,
        withdrawalAmount
      );
    } else {
      vm.expectEmit(parameters.asset);
      emit Transfer(address(market), accountAddress, withdrawalAmount);
    }

    lastTotalAssets -= withdrawalAmount;
    _getWithdrawalStatus(expiry, accountAddress).normalizedAmountWithdrawn += uint128(
      withdrawalAmount
    );
    state.normalizedUnclaimedWithdrawals -= uint128(withdrawalAmount);

    vm.expectEmit(address(market));
    emit WithdrawalExecuted(expiry, accountAddress, withdrawalAmount);
  }

  function _trackExecuteWithdrawal(
    MarketState memory state,
    uint32 expiry,
    address accountAddress
  ) internal {
    WithdrawalBatch memory batch = _getWithdrawalBatch(expiry);
    AccountWithdrawalStatus storage status = _getWithdrawalStatus(expiry, accountAddress);

    uint128 newTotalWithdrawn = uint128(
      MathUtils.mulDiv(batch.normalizedAmountPaid, status.scaledAmount, batch.scaledTotalAmount)
    );

    uint128 normalizedAmountWithdrawn = newTotalWithdrawn - status.normalizedAmountWithdrawn;
    MarketAccount storage account = _getAccount(accountAddress);
    bool isSanctioned = sanctionsSentinel.isSanctioned(borrower, accountAddress);
    bool willBeBlocked = isSanctioned && market.getAccountRole(accountAddress) != AuthRole.Blocked;
    _trackExecuteWithdrawal(
      state,
      expiry,
      accountAddress,
      normalizedAmountWithdrawn,
      willBeBlocked,
      isSanctioned
    );
  }

  function _trackRepay(
    MarketState memory state,
    address accountAddress,
    uint256 normalizedAmount
  ) internal {
    vm.expectEmit(parameters.asset);
    emit Transfer(accountAddress, address(market), normalizedAmount);
    vm.expectEmit(address(market));
    emit DebtRepaid(accountAddress, normalizedAmount);
    lastTotalAssets += normalizedAmount;
  }

  function _trackBorrow(uint256 normalizedAmount) internal {
    vm.expectEmit(parameters.asset);
    emit Transfer(address(market), parameters.borrower, normalizedAmount);
    vm.expectEmit(address(market));
    emit Borrow(normalizedAmount);
    lastTotalAssets -= normalizedAmount;
  }

  function _trackProcessUnpaidWithdrawalBatch(MarketState memory state) internal {
    uint32 expiry = _withdrawalData.unpaidBatches.first();
    WithdrawalBatch storage batch = _getWithdrawalBatch(expiry);
    uint256 availableLiquidity = lastTotalAssets -
      (state.normalizedUnclaimedWithdrawals + state.accruedProtocolFees);
    if (availableLiquidity > 0) {
      _applyWithdrawalBatchPayment(batch, state, expiry, availableLiquidity);
    }
    if (batch.scaledTotalAmount == batch.scaledAmountBurned) {
      _withdrawalData.unpaidBatches.shift();
      vm.expectEmit(address(market));
      emit WithdrawalBatchClosed(expiry);
    }
    // updateState(state);
  }

  /**
   * @dev When a withdrawal batch expires, the market will checkpoint the scale factor
   *      as of the time of expiry and retrieve the current liquid assets in the market
   * (assets which are not already owed to protocol fees or prior withdrawal batches).
   */
  function _processExpiredWithdrawalBatch(MarketState memory state) internal {
    WithdrawalBatch storage batch = _getWithdrawalBatch(state.pendingWithdrawalExpiry);

    if (batch.scaledAmountBurned < batch.scaledTotalAmount) {
      // Get the liquidity which is not already reserved for prior withdrawal batches
      // or owed to protocol fees.
      uint256 availableLiquidity = _availableLiquidityForPendingBatch(batch, state);
      if (availableLiquidity > 0) {
        _applyWithdrawalBatchPayment(
          batch,
          state,
          state.pendingWithdrawalExpiry,
          availableLiquidity
        );
      }
    }
    // vm.expectEmit(address(market));
    emit WithdrawalBatchExpired(
      state.pendingWithdrawalExpiry,
      batch.scaledTotalAmount,
      batch.scaledAmountBurned,
      batch.normalizedAmountPaid
    );

    if (batch.scaledAmountBurned < batch.scaledTotalAmount) {
      _withdrawalData.unpaidBatches.push(state.pendingWithdrawalExpiry);
    } else {
      // vm.expectEmit(address(market));
      emit WithdrawalBatchClosed(state.pendingWithdrawalExpiry);
    }

    state.pendingWithdrawalExpiry = 0;
  }

  function _availableLiquidityForPendingBatch(
    WithdrawalBatch storage batch,
    MarketState memory state
  ) internal view returns (uint256) {
    uint104 scaledAmountOwed = batch.scaledTotalAmount - batch.scaledAmountBurned;
    uint256 unavailableAssets = state.normalizedUnclaimedWithdrawals +
      state.accruedProtocolFees +
      state.normalizeAmount(state.scaledPendingWithdrawals - scaledAmountOwed);

    return lastTotalAssets.satSub(unavailableAssets);
  }

  /**
   * @dev Process withdrawal payment, burning market tokens and reserving
   *      underlying assets so they are only available for withdrawals.
   */
  function _applyWithdrawalBatchPayment(
    WithdrawalBatch storage batch,
    MarketState memory state,
    uint32 expiry,
    uint256 availableLiquidity
  ) internal {
    uint104 scaledAvailableLiquidity = state.scaleAmount(availableLiquidity).toUint104();
    uint104 scaledAmountOwed = batch.scaledTotalAmount - batch.scaledAmountBurned;
    if (scaledAmountOwed == 0) {
      return;
    }
    uint104 scaledAmountBurned = uint104(MathUtils.min(scaledAvailableLiquidity, scaledAmountOwed));
    uint128 normalizedAmountPaid = state.normalizeAmount(scaledAmountBurned).toUint128();

    batch.scaledAmountBurned += scaledAmountBurned;
    batch.normalizedAmountPaid += normalizedAmountPaid;
    state.scaledPendingWithdrawals -= scaledAmountBurned;

    // Update normalizedUnclaimedWithdrawals so the tokens are only accessible for withdrawals.
    state.normalizedUnclaimedWithdrawals += normalizedAmountPaid;

    // Burn market tokens to stop interest accrual upon withdrawal payment.
    state.scaledTotalSupply -= scaledAmountBurned;

    // Emit transfer for external trackers to indicate burn.
    // vm.expectEmit(address(market));
    emit Transfer(address(market), address(0), normalizedAmountPaid);
    // vm.expectEmit(address(market));
    emit WithdrawalBatchPayment(expiry, scaledAmountBurned, normalizedAmountPaid);
  }
}
