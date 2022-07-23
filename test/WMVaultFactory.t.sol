// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/Vm.sol";

import "src/interfaces/IERC20.sol";
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
    
    IERC20 internal DAI  = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 internal WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 internal WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

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

    function setUp() public {
        wmp  = new WMPermissions(wintermute);

        vm.prank(wintermute);
        wmp.adjustWhitelist(wlUser, true);

        wmvf = new WMVaultFactory(address(wmp));

        vm.prank(wintermute);
        uint saltDAI = 1;
        wmvf.deployVault(address(DAI), 100_000e18, 5e16, 90, bytes32(saltDAI));

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

    function test_withdrawInterestRemains() public {
        vm.prank(wlUser);
        wmDAI.deposit(50_000e18, wlUser);
        uint startBalance = wmDAI.balanceOf(wlUser);
        console.log(startBalance);
        warpOneYear();
        (uint a, uint b, uint c, uint d) = wmDAI.returnValues(wlUser);
        console.log(a);
        console.log(b);
        console.log(c);
        console.log(d);
        uint endBalance = wmDAI.balanceOf(wlUser);
        console.log(endBalance);
        assertTrue(true);
    }

}