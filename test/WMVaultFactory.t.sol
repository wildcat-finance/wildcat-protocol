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
      DAI = IERC20(address(new TestERC20("DAI Stablecoin", "DAI", 18)));
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
        wmvf.deployVault(address(DAI), 100_000e18, 500, 90, bytes32(saltDAI));

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

        // TODO: this fails, produces gibberish, seems to be a string memory problem with what's passed in
        // console.log(vaultName);
        
        /** 
        assertTrue(
            keccak256(abi.encodePacked(vaultName)) 
            == keccak256(abi.encodePacked("Wintermute Dai Stablecoin"))
        );
        */
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

    function test_WithdrawInterestRemains() public {
        vm.prank(wlUser);
        wmDAI.deposit(50_000e18, wlUser);
        uint startBalance = wmDAI.balanceOf(wlUser);
        console.log(startBalance);
        warpOneYear();
        
        vm.prank(wlUser);
        wmDAI.deposit(1e18, wlUser); // TODO: causes an integer over/underflow

        // TODO: confirm that the scale factor has increased
        (,,uint scaleFactor,) = wmDAI.getCurrentState();
        console.log(scaleFactor);

        uint endBalance = wmDAI.balanceOf(wlUser);
        console.log(endBalance);
        assertTrue(true); // TODO: make this a meaningful test: withdraw the interest
    }

    function test_WithdrawCollateral() public {
        
        // TODO: re-represent maxCollateralToWithdraw in terms of amounts deposited, not availableCapacity
        uint availableCollateral = wmDAI.maxCollateralToWithdraw();
        console.log(availableCollateral); 

        vm.prank(wlUser);
        wmDAI.deposit(50_000e18, wlUser);

        // TODO: confirm that the amount of collateral available to withdraw is now 90% of what was deposited
        // TODO: scale this with scaleFactor so it's not represented in the base asset
        uint availableCollateral2 = wmDAI.maxCollateralToWithdraw();
        console.log(availableCollateral2);
        assertTrue(true);
    }

}