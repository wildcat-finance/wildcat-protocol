// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

import './BaseVaultTest.sol';
import 'reference/libraries/math/WadRayMath.sol';
import 'reference/interfaces/IVaultErrors.sol';
import 'reference/libraries/math/MathUtils.sol';
import 'reference/libraries/SafeCastLib.sol';
import 'reference/libraries/VaultState.sol';
import 'solady/utils/SafeTransferLib.sol';

contract DepositsTest is BaseVaultTest {
	using stdStorage for StdStorage;
	using WadRayMath for uint256;
	using MathUtils for int256;
	using MathUtils for uint256;

	/*//////////////////////////////////////////////////////////////
                          deposit() errors
  //////////////////////////////////////////////////////////////*/

	// function testDepositUpTo_NotWhitelisted() public {
	//     vm.prank(nonalice);
	//     vm.expectRevert(WildcatVault.NotWhitelisted.selector);
	//     vault.depositUpTo(50_000e18, nonalice);
	// }

	function testDepositUpTo_TransferFail() public asAlice {
		asset.approve(address(vault), 0);
		vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
		vault.depositUpTo(50_000e18, alice);
	}

	function testDepositUpTo_MaxSupplyExceeded() public asAlice {
		vault.depositUpTo(DefaultMaximumSupply, alice);
		assertEq(vault.depositUpTo(1, alice), 0, 'depositUpTo should return 0');
	}

	/*//////////////////////////////////////////////////////////////
                          deposit() success
  //////////////////////////////////////////////////////////////*/

	function testDepositUpTo_Whitelisted() public asAlice {
		_deposit(alice, alice, 50_000e18);
	}

	function test_BalanceIncreasesOverTime() public asAlice {
		parameters.interestFeeBips = 0;
		setupVault();
		_deposit(alice, alice, 50_000e18);
		uint256 startBalance = vault.balanceOf(alice);

		_warpOneYear();
		uint256 interest = 5_000e18;

		uint256 endBalance = vault.balanceOf(alice);
		assertEq(endBalance, startBalance + interest, 'balance != prev + interest');
		assertGt(endBalance, startBalance, 'balance <= prev');

		_withdraw(alice, alice, 2_499e18);

		assertEq(vault.balanceOf(alice), (startBalance + interest) - 2_499e18);

		_withdraw(alice, alice, 1e18);
	}

	function test_BalanceIncreasesOverTimeWithFees() public asAlice {
		_deposit(alice, alice, 50_000e18);
		uint256 supply = vault.totalSupply();
		uint256 startBalance = vault.balanceOf(alice);
		assertEq(supply, startBalance, 'supply not balance');

		_warpOneYear();
		uint256 interest = 4_500e18;
		uint256 fees = 500e18;

		uint256 endBalance = vault.balanceOf(alice);
		assertEq(endBalance, startBalance + interest);
		assertTrue(endBalance > startBalance, 'Balance did not increase');

		_withdraw(alice, alice, 2_499e18);
		assertEq(vault.accruedProtocolFees(), fees);

		assertEq(vault.balanceOf(alice), (startBalance + interest) - 2_499e18);

		_withdraw(alice, alice, 1e18);
	}

	function test_Borrow() public {
		uint256 availableCollateral = vault.borrowableAssets();
		assertEq(availableCollateral, 0, 'borrowable should be 0');

		vm.prank(alice);
		vault.depositUpTo(50_000e18, alice);
    assertEq(vault.borrowableAssets(), 40_000e18, 'borrowable should be 40k');
	}
}
