// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "src/interfaces/IERC20.sol";
import "./helpers/TestERC20.sol";
import "src/interfaces/IWMVaultFactory.sol";
import "src/interfaces/IWMRegistry.sol";

import "src/WMPermissions.sol";
import "src/WMRegistry.sol";
import "src/WMVaultFactory.sol";

contract VaultFactoryTest is Test {
    using stdStorage for StdStorage;

    address internal wintermute = address(0x69);

    address public wlUser = address(0x42);
    address public nonwlUser = address(0x43);

    WMPermissions public wmp;
    WMRegistry public wmr;
    WMVaultFactory public wmvf;

    WMVault public wmDAI;
    
    IERC20 internal DAI;
    IERC20 internal WETH;
    IERC20 internal WBTC;

    constructor() {
      DAI = IERC20(address(new TestERC20("Dai Stablecoin", "DAI", 18)));
      WETH = IERC20(address(new TestERC20("Wrapped Ether", "WETH", 18)));
      WBTC = IERC20(address(new TestERC20("Wrapped Bitcoin", "WBTC", 8)));
    }

    function writeTokenBalance(address who, address token, uint256 amt) internal {
        stdstore
            .target(token)
            .sig(IERC20(token).balanceOf.selector)
            .with_key(who)
            .checked_write(amt);
    }

    function warpOneYear() public {
        vm.warp(block.timestamp + 365 days);
    }

    function warpOneSecond() public {
        vm.warp(block.timestamp + 1);
    }

    function setUp() public {
        wmp  = new WMPermissions(wintermute);

        vm.prank(wintermute);
        wmp.adjustWhitelist(wlUser, true);

        wmvf = new WMVaultFactory(address(wmp));

        vm.prank(wintermute);
        uint saltDAI = 1;
        wmvf.deployVault(address(DAI), 60_000e18, 500, 90, bytes32(saltDAI));

        address wmrAddr = wmvf.vaultRegistryAddress();
        wmr = WMRegistry(wmrAddr);

        address[] memory regVaults = wmr.listVaults();
        wmDAI = WMVault(regVaults[0]);

        writeTokenBalance(wlUser, address(DAI), 100_000 * 1e18);
        writeTokenBalance(nonwlUser, address(DAI), 100_000 * 1e18);

        vm.prank(wlUser);
        DAI.approve(address(wmDAI), 100_000 * 1e18);
        
        vm.prank(nonwlUser);
        DAI.approve(address(wmDAI), 100_000 * 1e18);
    }

    function test_VaultCreated() public { 
        IERC20Metadata wmDAImd = IERC20Metadata(address(wmDAI));
        string memory vaultName = wmDAImd.name();
        assertTrue(
            keccak256(abi.encodePacked(vaultName)) 
            == keccak256(abi.encodePacked("Wintermute Dai Stablecoin"))
        );
    }

    function test_PermissionsGranted() public {
        bool allowed = wmp.isWhitelisted(wlUser);
        assertTrue(allowed);
    }

    function test_PermissionsNotGranted() public {
        bool allowed = wmp.isWhitelisted(nonwlUser);
        assertFalse(allowed);
    }

    function test_SwapWhenAllowed() public {
        vm.prank(wlUser);
        wmDAI.deposit(50_000e18, wlUser);
    }

    function testFail_SwapWhenNotAllowed() public {
        vm.prank(nonwlUser);
        wmDAI.deposit(50_000e18, nonwlUser);
    }

    function test_BalanceIncreasesOverTime() public {
        vm.prank(wlUser);
        wmDAI.deposit(50_000e18, wlUser);
        uint startBalance = wmDAI.balanceOf(wlUser);
        warpOneYear();
        vm.prank(wlUser);
        wmDAI.withdraw(2_499e18, wlUser);
        uint endBalance = wmDAI.balanceOf(wlUser);
        assertTrue(endBalance > startBalance, "Balance did not increase");
    }

    // TODO: we're expecting this to only deposit up to the vault deposit limit
    // but it looks like the _mintUpTo function is just returning whatever it's given
    // and ignoring the minimum
    function test_depositUpToLimitOnly() public {
        vm.prank(wlUser);
        wmDAI.deposit(61_000e18, wlUser);
        uint startBalance = wmDAI.balanceOf(wlUser);
        console.log(startBalance);
        assertTrue(startBalance == 60_000e18, "Too much has been deposited");
    }

    function test_WithdrawCollateralImmediate() public {
        vm.prank(wlUser);
        wmDAI.deposit(50_000e18, wlUser);
        uint availableCollateral = wmDAI.maxCollateralToWithdraw();
        require(availableCollateral == 45_000e18, "Insufficient withdrawable collateral amount");
   
        vm.prank(wintermute);
        wmDAI.withdrawCollateral(wintermute, 45_000e18);
        uint availableCollateral2 = wmDAI.maxCollateralToWithdraw();
        require(availableCollateral2 == 0, "Should be zero collateral left to withdraw");
     
        warpOneYear();
        uint availableCollateral3 = wmDAI.maxCollateralToWithdraw();
        console.log(availableCollateral3);
        assertTrue(availableCollateral3 > 0, "Available collateral amount should have increased");
    }

}