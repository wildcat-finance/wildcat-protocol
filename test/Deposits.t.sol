// SPDX-License-Identifier: NONE
pragma solidity >=0.8.20;

import './BaseVaultTest.sol';
import 'src/interfaces/IVaultEventsAndErrors.sol';
import 'src/libraries/MathUtils.sol';
import 'src/libraries/SafeCastLib.sol';
import 'src/libraries/VaultState.sol';
import 'solady/utils/SafeTransferLib.sol';

contract DepositsTest is BaseVaultTest {
	using stdStorage for StdStorage;
	// using WadRayMath for uint256;
	using MathUtils for int256;
	using MathUtils for uint256;

	/*//////////////////////////////////////////////////////////////
                          deposit() errors
    //////////////////////////////////////////////////////////////*/

	function testDepositUpTo_NotApprovedLender() public asAccount(bob) {
      asset.mint(bob, 1e18);
      asset.approve(address(vault), 1e18);
      vm.expectRevert(IVaultEventsAndErrors.NotApprovedLender.selector);
      vault.depositUpTo(1e18);
	}

	function testDepositUpTo_TransferFail() public asAccount(alice) {
		asset.approve(address(vault), 0);
		vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
		vault.depositUpTo(50_000e18);
	}

	function testDepositUpTo_MaxSupplyExceeded() public asAccount(alice) {
		vault.depositUpTo(DefaultMaximumSupply);
		vm.expectRevert(IVaultEventsAndErrors.NullMintAmount.selector);
		vault.depositUpTo(1);
	}

	function testDeposit_MaxSupplyExceeded() public asAccount(alice) {
		vault.deposit(DefaultMaximumSupply - 1);
		vm.expectRevert(IVaultEventsAndErrors.MaxSupplyExceeded.selector);
		vault.deposit(2);
	}

	/*//////////////////////////////////////////////////////////////
                          deposit() success
    //////////////////////////////////////////////////////////////*/

	function testDepositUpTo_Whitelisted() public asAccount(alice) {
		_deposit(alice, 50_000e18);
	}

	function test_BalanceIncreasesOverTime() public asAccount(alice) {
		parameters.protocolFeeBips = 0;
		setupVault();
		_deposit(alice, 50_000e18);
		uint256 startBalance = vault.balanceOf(alice);

		fastForward(365 days);
		uint256 interest = 5_000e18;

		uint256 endBalance = vault.balanceOf(alice);
		assertEq(endBalance, startBalance + interest, 'balance != prev + interest');
		// assertGt(endBalance, startBalance, 'balance <= prev');

		/* _withdraw(alice, 2_499e18);

		assertEq(vault.balanceOf(alice), (startBalance + interest) - 2_499e18);

		_withdraw(alice, 1e18); */
	}

	function test_BalanceIncreasesOverTimeWithFees() public asAccount(alice) {
		_deposit(alice, 50_000e18);
		uint256 supply = vault.totalSupply();
		uint256 startBalance = vault.balanceOf(alice);
		assertEq(supply, startBalance, 'supply not balance');

		fastForward(365 days);
		uint256 interest = 5_000e18;
		uint256 fees = 500e18;

		uint256 endBalance = vault.balanceOf(alice);
		assertEq(endBalance, startBalance + interest, 'balance != prev + interest');

		// _withdraw(alice, 2_499e18);
		assertEq(vault.accruedProtocolFees(), fees, 'accrued fees != 10% of interest');

		// assertEq(vault.balanceOf(alice), (startBalance + interest) - 2_499e18);

		// _withdraw(alice, 1e18);
	}

	function test_Borrow() public {
		uint256 availableCollateral = vault.borrowableAssets();
		assertEq(availableCollateral, 0, 'borrowable should be 0');

		vm.prank(alice);
		vault.depositUpTo(50_000e18);
		assertEq(vault.borrowableAssets(), 40_000e18, 'borrowable should be 40k');
	}
}
