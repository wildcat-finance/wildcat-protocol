// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

import { MockERC20 } from 'solmate/test/utils/mocks/MockERC20.sol';

import 'forge-std/Test.sol';
import 'forge-std/Vm.sol';

import 'reference/WildcatVaultController.sol';
import 'reference/WildcatVaultFactory.sol';
import './helpers/Assertions.sol';

uint256 constant DefaultMaximumSupply = 100_000e18;
uint256 constant DefaultInterest = 1000;
uint256 constant DefaultPenaltyFee = 1000;
uint256 constant DefaultLiquidityCoverage = 2000;
uint256 constant DefaultGracePeriod = 2000;
uint256 constant DefaultInterestFee = 1000;

uint256 constant DefaultInterestPerSecondRay = (DefaultInterest * 1e23) / SecondsIn365Days;

uint256 constant SecondsIn365Days = 365 days;

address constant alice = address(0xa11ce);
address constant bob = address(0xb0b);
address constant sentinel = address(0x533);
address constant feeRecipient = address(0xfee);
address constant borrower = address(0xb04405e4);

contract BaseVaultTest is Test, Assertions {
	using stdStorage for StdStorage;
	using FeeMath for VaultState;

	WildcatVaultFactory internal factory;
	WildcatVaultController internal controller;
	MockERC20 internal asset;
	WildcatVaultToken internal vault;

	address internal wildcatController = address(0x69);
	address internal wintermuteController = address(0x70);
	address internal wlUser = address(0x42);
	address internal nonwlUser = address(0x43);

	VaultParameters internal parameters;
	address internal _pranking;

	VaultState internal previousState;
	uint256 internal lastProtocolFees;
	uint256 internal lastTotalAssets;

	function setUp() public {
		factory = new WildcatVaultFactory();
		controller = new WildcatVaultController(feeRecipient, address(factory));
    controller.approveLender(alice);
		asset = new MockERC20('Token', 'TKN', 18);
		parameters = VaultParameters({
      sentinel: sentinel,
			borrower: borrower,
			asset: address(asset),
			controller: address(controller),
			namePrefix: 'Wildcat ',
			symbolPrefix: 'WC',
			maxTotalSupply: DefaultMaximumSupply,
			annualInterestBips: DefaultInterest,
			delinquencyFeeBips: DefaultPenaltyFee,
			delinquencyGracePeriod: DefaultGracePeriod,
			liquidityCoverageRatio: DefaultLiquidityCoverage,
			protocolFeeBips: DefaultInterestFee,
			feeRecipient: feeRecipient
		});
		setupVault();
	}

	function pendingState() internal view returns (VaultState memory state, uint256 protocolFees) {
		state = previousState;
		(uint256 feesAccrued, bool didUpdate) = state.calculateInterestAndFees(
			parameters.protocolFeeBips,
			parameters.delinquencyFeeBips,
			parameters.delinquencyGracePeriod
		);
		protocolFees = lastProtocolFees + feesAccrued;
	}

	function updateState(VaultState memory state, uint256 protocolFees) internal {
		state.isDelinquent = state.liquidityRequired(protocolFees) > lastTotalAssets;
		previousState = state;
		lastProtocolFees = protocolFees;
	}

	function _deposit(
		address from,
		uint256 amount
	) internal asAccount(from) returns (uint256) {
    if (_pranking != address(0)) {
      vm.stopPrank();
    }
    controller.approveLender(from);
    if (_pranking != address(0)) {
      vm.startPrank(_pranking);
    }
		(VaultState memory state, uint256 protocolFees) = pendingState();
		uint256 realAmount = MathUtils.min(amount, state.getMaximumDeposit());
		uint256 scaledAmount = state.scaleAmount(realAmount);
		state.increaseScaledTotalSupply(scaledAmount);
		uint256 actualAmount = vault.depositUpTo(amount);
		assertEq(actualAmount, realAmount, 'Actual amount deposited');
		lastTotalAssets += actualAmount;
		updateState(state, protocolFees);
		return actualAmount;
	}

	function _withdraw(address from, uint256 amount) internal asAccount(from) {
		(VaultState memory state, uint256 protocolFees) = pendingState();
		uint256 scaledAmount = state.scaleAmount(amount);
		state.decreaseScaledTotalSupply(scaledAmount);
		vault.withdraw(amount);
		updateState(state, protocolFees);
		lastTotalAssets -= amount;
		_checkState();
	}

	function _borrow(uint256 amount) internal asAccount(borrower) {
		(VaultState memory state, uint256 protocolFees) = pendingState();
		vault.borrow(amount);
		updateState(state, protocolFees);
		lastTotalAssets -= amount;
		_checkState();
	}

  function _checkState() internal {
    (VaultState memory state, uint256 _accruedProtocolFees) = vault.currentState();
    assertEq(previousState, state, 'state');
    assertEq(lastProtocolFees, _accruedProtocolFees, 'protocol fees');
    assertEq(lastProtocolFees, vault.lastAccruedProtocolFees(), 'protocol fees');
  }

	modifier asAlice() {
		vm.startPrank(alice);
		_pranking = alice;
		_;
		vm.stopPrank();
		_pranking = address(0);
	}

	function _writeTokenBalance(address who, address token, uint256 amt) internal {
		stdstore.target(token).sig(IERC20(token).balanceOf.selector).with_key(who).checked_write(amt);
	}

	modifier asAccount(address account) {
		bool resetPrank = _pranking != address(0) && account != _pranking;
		if (resetPrank) vm.stopPrank();
		if (account != _pranking) vm.startPrank(account);
		_;
		if (account != _pranking) vm.stopPrank();
		if (resetPrank) {
			vm.startPrank(_pranking);
		}
	}

	function _approve(address from, address to, uint256 amount) internal asAccount(from) {
		asset.approve(to, amount);
	}

	function _warpOneYear() internal {
		vm.warp(block.timestamp + 365 days);
	}

	function _warpOneSecond() internal {
		vm.warp(block.timestamp + 1);
	}

	function _deployVault() internal {
		vault = WildcatVaultToken(factory.deployVault(parameters));
	}

	function setupVault() internal {
		_deployVault();
		previousState = VaultState({
			maxTotalSupply: uint128(parameters.maxTotalSupply),
			scaledTotalSupply: 0,
			isDelinquent: false,
			timeDelinquent: 0,
			liquidityCoverageRatio: uint16(parameters.liquidityCoverageRatio),
			annualInterestBips: uint16(parameters.annualInterestBips),
			scaleFactor: uint112(RAY),
			lastInterestAccruedTimestamp: uint32(block.timestamp)
		});
		lastProtocolFees = 0;
		lastTotalAssets = 0;

		asset.mint(alice, type(uint128).max);
		asset.mint(bob, type(uint128).max);

		_approve(alice, address(vault), type(uint256).max);
		_approve(bob, address(vault), type(uint256).max);
	}
}
