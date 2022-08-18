// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

import "../helpers/BaseVaultTest.sol";

contract DepositsTest is BaseVaultTest {
    using stdStorage for StdStorage;
    using Math for uint256;
    using Math for int256;

  /*//////////////////////////////////////////////////////////////
                          deposit() errors
  //////////////////////////////////////////////////////////////*/

    function testDeposit_NotWhitelisted() public {
        vm.prank(nonwlUser);
        vm.expectRevert(WMVault.NotWhitelisted.selector);
        wmDAI.deposit(50_000e18, nonwlUser);
    }

    function testDeposit_TransferFail() public {
        vm.startPrank(wlUser);
        DAI.approve(address(wmDAI), 0);
        vm.expectRevert('TRANSFER_FROM_FAILED');
        wmDAI.deposit(50_000e18, nonwlUser);
        vm.stopPrank();
    }

    function test_MaxSupplyExceeded() public {
      vm.startPrank(wlUser);
      wmDAI.deposit(DefaultMaximumSupply, wlUser);
      DAI.mint(wlUser, 1);
      DAI.approve(address(wmDAI), 1);
      vm.expectRevert(ScaledBalanceToken.MaxSupplyExceeded.selector);
      wmDAI.deposit(1, wlUser);
      vm.stopPrank();
    }

  /*//////////////////////////////////////////////////////////////
                          deposit() success
  //////////////////////////////////////////////////////////////*/

    function testDeposit_Whitelisted() public {
        vm.prank(wlUser);
        wmDAI.deposit(50_000e18, wlUser);
    }

    function test_BalanceIncreasesOverTime() public {
        vm.prank(wlUser);
        wmDAI.deposit(50_000e18, wlUser);
        uint startBalance = wmDAI.balanceOf(wlUser);

        _warpOneYear();
        uint256 interest = uint256(startBalance.rayMul(DefaultInterestPerSecondRay * SecondsIn365Days));

        uint endBalance = wmDAI.balanceOf(wlUser);
        assertEq(endBalance, startBalance + interest);
        assertTrue(endBalance > startBalance, "Balance did not increase");
        
        // The deposit of 1e18 is what ACTUALLY adjusts the scale factor, the balanceOf call just projects it
        vm.prank(wlUser);
        wmDAI.withdraw(2_499e18, wlUser);

        assertEq(wmDAI.balanceOf(wlUser), (startBalance + interest) - 2_499e18);

        vm.prank(wlUser);
        wmDAI.withdraw(1e18, wlUser);
    }

    function test_WithdrawCollateral() public {
        
        // TODO: re-represent maxCollateralToWithdraw in terms of amounts deposited, not availableCapacity
        uint availableCollateral = wmDAI.maxCollateralToWithdraw();
        console2.log(availableCollateral); 

        vm.prank(wlUser);
        wmDAI.deposit(50_000e18, wlUser);

        // TODO: confirm that the amount of collateral available to withdraw is now 90% of what was deposited
        // TODO: scale this with scaleFactor so it's not represented in the base asset
        uint availableCollateral2 = wmDAI.maxCollateralToWithdraw();
        console2.log(availableCollateral2);
        assertTrue(true);
    }

}