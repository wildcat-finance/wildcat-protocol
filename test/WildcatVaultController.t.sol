// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

import './BaseVaultTest.sol';
import 'src/interfaces/IVaultEventsAndErrors.sol';
import 'src/libraries/MathUtils.sol';
import 'src/libraries/SafeCastLib.sol';
import 'src/libraries/VaultState.sol';
import 'solady/utils/SafeTransferLib.sol';

contract WildcatVaultControllerTest is BaseVaultTest {

  function _check(uint256 apr, uint256 coverage, uint256 cachedCoverage, uint256 tmpExpiry) internal {
    (uint256 liquidityCoverageRatio, uint256 expiry) = controller.temporaryExcessLiquidityCoverage(
      address(vault)
    );

    assertEq(vault.annualInterestBips(), apr, 'APR');
    assertEq(vault.liquidityCoverageRatio(), coverage, 'Liquidity coverage ratio');

    assertEq(liquidityCoverageRatio, cachedCoverage, 'Previous liquidity coverage');
    assertEq(expiry, tmpExpiry, 'Temporary coverage expiry');
  }

	function test_setAnnualInterestBips_UnknownVault() public {
		vm.prank(borrower);
		vm.expectRevert(bytes(''));
		controller.setAnnualInterestBips(address(1), DefaultInterest + 1);
	}

	function test_setAnnualInterestBips_NotBorrower() public {
		vm.expectRevert('WildcatVaultController: Not owner or borrower');
		controller.setAnnualInterestBips(address(vault), DefaultInterest + 1);
	}

	function test_setAnnualInterestBips_Decrease() public {
		vm.prank(borrower);
		controller.setAnnualInterestBips(address(vault), DefaultInterest - 1);
    _check(DefaultInterest - 1, 9000, DefaultLiquidityCoverage, block.timestamp + 2 weeks);
	}

	function test_setAnnualInterestBips_Decrease_AlreadyPending() public {
		vm.prank(borrower);
		controller.setAnnualInterestBips(address(vault), DefaultInterest - 1);

    uint256 expiry = block.timestamp + 2 weeks;
		_check(DefaultInterest - 1, 9000, DefaultLiquidityCoverage, expiry);

    _warp(2 weeks);
    vm.prank(borrower);
		controller.setAnnualInterestBips(address(vault), DefaultInterest - 2);
		_check(DefaultInterest - 2, 9000, DefaultLiquidityCoverage, expiry + 2 weeks);
	}

	function test_setAnnualInterestBips_Decrease_Undercollateralized() public {
    _deposit(alice, 50_000e18);
		vm.prank(borrower);
		vault.borrow(5_000e18 + 1);

		vm.startPrank(borrower);
		vm.expectRevert(IVaultEventsAndErrors.InsufficientCoverageForNewLiquidityRatio.selector);
		controller.setAnnualInterestBips(address(vault), DefaultInterest - 1);
	}

	function test_setAnnualInterestBips_Increase() public {
		vm.prank(borrower);
		controller.setAnnualInterestBips(address(vault), DefaultInterest + 1);

    _check(DefaultInterest + 1, DefaultLiquidityCoverage, 0, 0);
	}

	function test_setAnnualInterestBips_Increase_Undercollateralized() public {
		_deposit(alice, 50_000e18);
		vm.prank(borrower);
		vault.borrow(5_000e18 + 1);

		vm.prank(borrower);
		controller.setAnnualInterestBips(address(vault), DefaultInterest + 1);
	}

	function test_resetLiquidityCoverage_NotPending() public {
		vm.expectRevert('WildcatVaultController: No APR decrease pending');
		controller.resetLiquidityCoverage(address(vault));
	}

	function test_resetLiquidityCoverage_StillActive() public {
		vm.prank(borrower);
		controller.setAnnualInterestBips(address(vault), DefaultInterest - 1);

		vm.expectRevert('WildcatVaultController: Excess liquidity coverage still active');
		controller.resetLiquidityCoverage(address(vault));
	}

	function test_resetLiquidityCoverage() public {
		vm.prank(borrower);
		controller.setAnnualInterestBips(address(vault), DefaultInterest - 1);

		_warp(2 weeks);
		controller.resetLiquidityCoverage(address(vault));

		assertEq(
			vault.liquidityCoverageRatio(),
			DefaultLiquidityCoverage,
			'Liquidity coverage ratio not reset'
		);

    _check(DefaultInterest - 1, DefaultLiquidityCoverage, 0, 0);
	}
}
