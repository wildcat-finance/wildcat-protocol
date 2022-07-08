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

    WMPermissions public wmp;
    WMRegistry public wmr;
    WMVaultFactory public wmvf;
    
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

    function setUp() public {
        wmp  = new WMPermissions(wintermute);
        wmvf = new WMVaultFactory(address(wmp)); // TODO: permission this so that only Wintermute can create it
        
        vm.prank(wintermute);
        uint saltDAI = 1;
        wmvf.deployVault(address(DAI), 100e18, 5e16, 90, bytes32(saltDAI));

        address wmr = wmvf.vaultRegistryAddress();
        console.log(wmr);

        address[] memory regVaults = IWMRegistry(wmr).listVaults();
        console.log(regVaults[0]);
    }

    function testCreatedVaults() public {
        assertTrue(true);
    }

}