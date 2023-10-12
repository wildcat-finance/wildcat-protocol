// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { MockERC20 } from 'solmate/test/utils/mocks/MockERC20.sol';

import './shared/Test.sol';
import './helpers/VmUtils.sol';
import './helpers/MockController.sol';
import './helpers/ExpectedStateTracker.sol';

contract BaseVaultTest is Test, ExpectedStateTracker {
  using stdStorage for StdStorage;
  using FeeMath for VaultState;
  using SafeCastLib for uint256;

  MockERC20 internal asset;

  address internal wildcatController = address(0x69);
  address internal wintermuteController = address(0x70);
  address internal wlUser = address(0x42);
  address internal nonwlUser = address(0x43);

  function setUp() public {
    setUpContracts(false);
  }

  function setUpContracts(bool disableControllerChecks) internal {
    if (address(controller) == address(0)) {
      deployController(parameters.borrower, false, disableControllerChecks);
    }
    parameters.controller = address(controller);
    parameters.asset = address(asset = new MockERC20('Token', 'TKN', 18));
    deployVault(parameters);
    _authorizeLender(alice);
    previousState = VaultState({
      isClosed: false,
      maxTotalSupply: parameters.maxTotalSupply,
      scaledTotalSupply: 0,
      isDelinquent: false,
      timeDelinquent: 0,
      reserveRatioBips: parameters.reserveRatioBips,
      annualInterestBips: parameters.annualInterestBips,
      scaleFactor: uint112(RAY),
      lastInterestAccruedTimestamp: uint32(block.timestamp),
      scaledPendingWithdrawals: 0,
      pendingWithdrawalExpiry: 0,
      normalizedUnclaimedWithdrawals: 0,
      accruedProtocolFees: 0
    });
    lastTotalAssets = 0;

    asset.mint(alice, type(uint128).max);
    asset.mint(bob, type(uint128).max);

    _approve(alice, address(vault), type(uint256).max);
    _approve(bob, address(vault), type(uint256).max);
  }

  function _authorizeLender(address account) internal asAccount(parameters.borrower) {
    address[] memory lenders = new address[](1);
    lenders[0] = account;
    controller.authorizeLenders(lenders);
  }

  function _deauthorizeLender(address account) internal asAccount(parameters.borrower) {
    address[] memory lenders = new address[](1);
    lenders[0] = account;
    controller.deauthorizeLenders(lenders);
  }

  function _depositBorrowWithdraw(
    address from,
    uint256 depositAmount,
    uint256 borrowAmount,
    uint256 withdrawalAmount
  ) internal asAccount(from) {
    _deposit(from, depositAmount);
    // Borrow 80% of vault assets
    _borrow(borrowAmount);
    // Withdraw 100% of deposits
    _requestWithdrawal(from, withdrawalAmount);
  }

  function _deposit(address from, uint256 amount) internal asAccount(from) returns (uint256) {
    _authorizeLender(from);
    uint256 currentBalance = vault.balanceOf(from);
    uint256 currentScaledBalance = vault.scaledBalanceOf(from);
    asset.mint(from, amount);
    asset.approve(address(vault), amount);
    VaultState memory state = pendingState();
    uint256 expectedNormalizedAmount = MathUtils.min(amount, state.maximumDeposit());
    uint256 scaledAmount = state.scaleAmount(expectedNormalizedAmount);
    state.scaledTotalSupply += scaledAmount.toUint104();
    uint256 actualNormalizedAmount = vault.depositUpTo(amount);
    assertEq(actualNormalizedAmount, expectedNormalizedAmount, 'Actual amount deposited');
    lastTotalAssets += actualNormalizedAmount;
    updateState(state);
    _checkState();
    assertApproxEqAbs(vault.balanceOf(from), currentBalance + amount, 1);
    assertEq(vault.scaledBalanceOf(from), currentScaledBalance + scaledAmount);
    return actualNormalizedAmount;
  }

  function _requestWithdrawal(address from, uint256 amount) internal asAccount(from) {
    VaultState memory state = pendingState();
    uint256 currentBalance = vault.balanceOf(from);
    uint256 currentScaledBalance = vault.scaledBalanceOf(from);
    uint104 scaledAmount = state.scaleAmount(amount).toUint104();

    if (state.pendingWithdrawalExpiry == 0) {
      // vm.expectEmit(address(vault));
      state.pendingWithdrawalExpiry = uint32(block.timestamp + parameters.withdrawalBatchDuration);
      emit WithdrawalBatchCreated(state.pendingWithdrawalExpiry);
    }
    WithdrawalBatch storage batch = _withdrawalData.batches[state.pendingWithdrawalExpiry];
    batch.scaledTotalAmount += scaledAmount;
    state.scaledPendingWithdrawals += scaledAmount;
    _withdrawalData
    .accountStatuses[state.pendingWithdrawalExpiry][from].scaledAmount += scaledAmount;

    // vm.expectEmit(address(vault));
    emit WithdrawalQueued(state.pendingWithdrawalExpiry, from, scaledAmount);

    uint256 availableLiquidity = _availableLiquidityForPendingBatch(batch, state);
    if (availableLiquidity > 0) {
      _applyWithdrawalBatchPayment(batch, state, state.pendingWithdrawalExpiry, availableLiquidity);
    }
    vault.queueWithdrawal(amount);
    updateState(state);
    _checkState();
    assertApproxEqAbs(vault.balanceOf(from), currentBalance - amount, 1, 'balance');
    assertEq(vault.scaledBalanceOf(from), currentScaledBalance - scaledAmount, 'scaledBalance');
  }

  function _withdraw(address from, uint256 amount) internal asAccount(from) {
    // VaultState memory state = pendingState();
    // uint256 scaledAmount = state.scaleAmount(amount);
    // @todo fix
    /* 		VaultState memory state = pendingState();
    uint256 scaledAmount = state.scaleAmount(amount);
    state.decreaseScaledTotalSupply(scaledAmount);
    vault.withdraw(amount);
    updateState(state);
    lastTotalAssets -= amount;
    _checkState(); */
  }

  event DebtRepaid(uint256 assetAmount);

  function _borrow(uint256 amount) internal asAccount(borrower) {
    VaultState memory state = pendingState();

    // vm.expectEmit(address(vault));
    emit Borrow(amount);
    // _expectTransfer(address(asset), borrower, address(vault), amount);
    vault.borrow(amount);

    lastTotalAssets -= amount;
    updateState(state);
    _checkState();
  }

  function _approve(address from, address to, uint256 amount) internal asAccount(from) {
    asset.approve(to, amount);
  }
}
