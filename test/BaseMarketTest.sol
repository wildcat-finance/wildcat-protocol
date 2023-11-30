// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20;

import { MockERC20 } from 'solmate/test/utils/mocks/MockERC20.sol';

import './shared/Test.sol';
import './helpers/VmUtils.sol';
import './helpers/MockController.sol';
import './helpers/ExpectedStateTracker.sol';

contract BaseMarketTest is Test, ExpectedStateTracker {
  using stdStorage for StdStorage;
  using FeeMath for MarketState;
  using SafeCastLib for uint256;

  MockERC20 internal asset;

  address internal wildcatController = address(0x69);
  address internal wintermuteController = address(0x70);
  address internal wlUser = address(0x42);
  address internal nonwlUser = address(0x43);

  function setUp() public virtual {
    setUpContracts(false);
  }

  function setUpContracts(bool disableControllerChecks) internal {
    if (address(controller) == address(0)) {
      deployController(parameters.borrower, false, disableControllerChecks);
    }
    parameters.controller = address(controller);
    parameters.asset = address(asset = new MockERC20('Token', 'TKN', 18));
    deployMarket(parameters);
    _authorizeLender(alice);
    previousState = MarketState({
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

    _approve(alice, address(market), type(uint256).max);
    _approve(bob, address(market), type(uint256).max);
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
    // Borrow 80% of market assets
    _borrow(borrowAmount);
    // Withdraw 100% of deposits
    _requestWithdrawal(from, withdrawalAmount);
  }

  function _deposit(address from, uint256 amount) internal asAccount(from) returns (uint256) {
    _authorizeLender(from);
    MarketState memory state = pendingState();
    (uint256 currentScaledBalance, uint256 currentBalance) = _getBalance(state, from);
    asset.mint(from, amount);
    asset.approve(address(market), amount);
    (uint104 scaledAmount, uint256 expectedNormalizedAmount) = _trackDeposit(state, from, amount);
    uint256 actualNormalizedAmount = market.depositUpTo(amount);
    assertEq(actualNormalizedAmount, expectedNormalizedAmount, 'Actual amount deposited');
    _checkState();
    assertApproxEqAbs(market.balanceOf(from), currentBalance + amount, 1);
    assertEq(market.scaledBalanceOf(from), currentScaledBalance + scaledAmount);
    return actualNormalizedAmount;
  }

  function _requestWithdrawal(address from, uint256 amount) internal asAccount(from) {
    MarketState memory state = pendingState();
    (uint256 currentScaledBalance, uint256 currentBalance) = _getBalance(state, from);
    (, uint104 scaledAmount) = _trackQueueWithdrawal(state, from, amount);
    updateState(state);
    market.queueWithdrawal(amount);
    _checkState();
    assertApproxEqAbs(market.balanceOf(from), currentBalance - amount, 1, 'balance');
    assertEq(market.scaledBalanceOf(from), currentScaledBalance - scaledAmount, 'scaledBalance');
  }

  function _withdraw(address from, uint256 amount) internal asAccount(from) {
    // MarketState memory state = pendingState();
    // uint256 scaledAmount = state.scaleAmount(amount);
    // @todo fix
    /* 		MarketState memory state = pendingState();
    uint256 scaledAmount = state.scaleAmount(amount);
    state.decreaseScaledTotalSupply(scaledAmount);
    market.withdraw(amount);
    updateState(state);
    lastTotalAssets -= amount;
    _checkState(); */
  }

  function _borrow(uint256 amount) internal asAccount(borrower) {
    MarketState memory state = pendingState();

    _trackBorrow(amount);
    updateState(state);
    market.borrow(amount);
    _checkState();
  }

  function _approve(address from, address to, uint256 amount) internal asAccount(from) {
    asset.approve(to, amount);
  }
}
