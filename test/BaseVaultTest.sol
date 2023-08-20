// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { MockERC20 } from 'solmate/test/utils/mocks/MockERC20.sol';

import 'forge-std/Test.sol';
import 'forge-std/Vm.sol';

import 'src/WildcatVaultController.sol';
import 'src/WildcatVaultFactory.sol';
import './helpers/Assertions.sol';
import './helpers/MockController.sol';
import './shared/TestConstants.sol';

contract BaseVaultTest is Test, Assertions {
	using stdStorage for StdStorage;
	using FeeMath for VaultState;
	using SafeCastLib for uint256;

	WildcatVaultFactory internal factory;
	WildcatVaultController internal controller;
	MockERC20 internal asset;
	WildcatMarket internal vault;

	address internal wildcatController = address(0x69);
	address internal wintermuteController = address(0x70);
	address internal wlUser = address(0x42);
	address internal nonwlUser = address(0x43);

	VaultParameters internal parameters;
	address internal _pranking;

	VaultState internal previousState;
	WithdrawalData internal _withdrawalData;
	uint256 internal lastProtocolFees;
	uint256 internal lastTotalAssets;

	function setUp() public {
		factory = new WildcatVaultFactory();
		controller = new MockController(feeRecipient, address(factory));
		controller.authorizeLender(alice);
		asset = new MockERC20('Token', 'TKN', 18);
		parameters = VaultParameters({
			asset: address(asset),
			namePrefix: 'Wildcat ',
			symbolPrefix: 'WC',
			borrower: borrower,
			controller: address(controller),
			feeRecipient: feeRecipient,
			sentinel: sentinel,
			maxTotalSupply: uint128(DefaultMaximumSupply),
			protocolFeeBips: DefaultProtocolFeeBips,
			annualInterestBips: DefaultInterest,
			delinquencyFeeBips: DefaultDelinquencyFee,
			withdrawalBatchDuration: DefaultWithdrawalBatchDuration,
			liquidityCoverageRatio: DefaultLiquidityCoverage,
			delinquencyGracePeriod: DefaultGracePeriod
		});
		setupVault();
	}

	/**
	 * @dev When a withdrawal batch expires, the vault will checkpoint the scale factor
	 *      as of the time of expiry and retrieve the current liquid assets in the vault
	 * (assets which are not already owed to protocol fees or prior withdrawal batches).
	 */
	function _processExpiredWithdrawalBatch(VaultState memory state) internal {
		WithdrawalBatch storage batch = _withdrawalData.batches[state.pendingWithdrawalExpiry];

		// Get the liquidity which is not already reserved for prior withdrawal batches
		// or owed to protocol fees.
		uint256 availableLiquidity = batch.availableLiquidityForBatch(state, lastTotalAssets);

		uint104 scaledTotalAmount = batch.scaledTotalAmount;

		uint128 normalizedOwedAmount = state.normalizeAmount(scaledTotalAmount).toUint128();

		(uint104 scaledAmountBurned, uint128 normalizedAmountPaid) = (availableLiquidity >=
			normalizedOwedAmount)
			? (scaledTotalAmount, normalizedOwedAmount)
			: (state.scaleAmount(availableLiquidity).toUint104(), availableLiquidity.toUint128());

		batch.scaledAmountBurned = scaledAmountBurned;
		batch.normalizedAmountPaid = normalizedAmountPaid;

		if (scaledAmountBurned < scaledTotalAmount) {
			_withdrawalData.unpaidBatches.push(state.pendingWithdrawalExpiry);
		}

		state.pendingWithdrawalExpiry = 0;
		state.reservedAssets += normalizedAmountPaid;

		if (scaledAmountBurned > 0) {
			state.scaledPendingWithdrawals -= scaledAmountBurned;
			state.scaledTotalSupply -= scaledAmountBurned;
		}
	}

	function pendingState() internal returns (VaultState memory state) {
		state = previousState;
		if (block.timestamp >= state.pendingWithdrawalExpiry && state.pendingWithdrawalExpiry != 0) {
			uint256 expiry = state.pendingWithdrawalExpiry;
			state.updateScaleFactorAndFees(
				parameters.protocolFeeBips,
				parameters.delinquencyFeeBips,
				parameters.delinquencyGracePeriod,
				expiry
			);
			_processExpiredWithdrawalBatch(state);
		}
		state.updateScaleFactorAndFees(
			parameters.protocolFeeBips,
			parameters.delinquencyFeeBips,
			parameters.delinquencyGracePeriod,
			block.timestamp
		);
		// (uint256 feesAccrued, bool didUpdate) = state.calculateInterestAndFees(
		// 	parameters.protocolFeeBips,
		// 	parameters.delinquencyFeeBips,
		// 	parameters.delinquencyGracePeriod
		// );
		// protocolFees = lastProtocolFees + feesAccrued;
	}

	function updateState(VaultState memory state) internal {
		state.isDelinquent = state.liquidityRequired() > lastTotalAssets;
		previousState = state;
	}

	function _deposit(address from, uint256 amount) internal asAccount(from) returns (uint256) {
		if (_pranking != address(0)) {
			vm.stopPrank();
		}
		controller.authorizeLender(from);
		if (_pranking != address(0)) {
			vm.startPrank(_pranking);
		}
		asset.mint(from, amount);
		asset.approve(address(vault), amount);
		VaultState memory state = pendingState();
		uint256 expectedNormalizedAmount = MathUtils.min(amount, state.maximumDeposit());
		uint256 scaledAmount = state.scaleAmount(expectedNormalizedAmount);
		state.increaseScaledTotalSupply(scaledAmount);
		uint256 actualNormalizedAmount = vault.depositUpTo(amount);
		assertEq(actualNormalizedAmount, expectedNormalizedAmount, 'Actual amount deposited');
		lastTotalAssets += actualNormalizedAmount;
		updateState(state);
		return actualNormalizedAmount;
	}

	function _withdraw(address from, uint256 amount) internal asAccount(from) {
		// @todo fix
		/* 		VaultState memory state = pendingState();
    uint256 scaledAmount = state.scaleAmount(amount);
    state.decreaseScaledTotalSupply(scaledAmount);
    vault.withdraw(amount);
    updateState(state);
    lastTotalAssets -= amount;
    _checkState(); */
	}

	event Borrow(uint256 assetAmount);
	event DebtRepaid(uint256 assetAmount);
	event Transfer(address indexed from, address indexed to, uint256 value);

	function _borrow(uint256 amount) internal asAccount(borrower) {
		VaultState memory state = pendingState();

		vm.expectEmit(address(vault));
		emit Borrow(amount);
		// _expectTransfer(address(asset), borrower, address(vault), amount);
		vault.borrow(amount);

		lastTotalAssets -= amount;
		updateState(state);
		_checkState();
	}

	function _checkState() internal {
		VaultState memory state = vault.currentState();
		assertEq(previousState, state, 'state');
		// assertEq(lastProtocolFees, state., 'protocol fees');
		// assertEq(lastProtocolFees, vault.lastAccruedProtocolFees(), 'protocol fees');
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
		address previousPrank = _pranking;
		if (account != previousPrank) {
			if (previousPrank != address(0)) vm.stopPrank();
			vm.startPrank(account);
			_pranking = account;
			_;
			vm.stopPrank();
			if (previousPrank != address(0)) vm.startPrank(previousPrank);
			_pranking = previousPrank;
		} else {
			_;
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

	function _warp(uint256 time) internal {
		vm.warp(block.timestamp + time);
	}

	function _deployVault() internal {
		vault = WildcatMarket(factory.deployVault(parameters));
	}

	function setupVault() internal {
		_deployVault();
		// @todo fix
		/* 		previousState = VaultState({
    maxTotalSupply: uint128(parameters.maxTotalSupply),
    scaledTotalSupply: 0,
    isDelinquent: false,
    timeDelinquent: 0,
    liquidityCoverageRatio: uint16(parameters.liquidityCoverageRatio),
    annualInterestBips: uint16(parameters.annualInterestBips),
    scaleFactor: uint112(RAY),
    lastInterestAccruedTimestamp: uint32(block.timestamp)
    }); */
		lastProtocolFees = 0;
		lastTotalAssets = 0;

		asset.mint(alice, type(uint128).max);
		asset.mint(bob, type(uint128).max);

		_approve(alice, address(vault), type(uint256).max);
		_approve(bob, address(vault), type(uint256).max);
	}
}
