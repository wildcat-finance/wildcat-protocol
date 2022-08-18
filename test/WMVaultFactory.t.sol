// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

// import "src/WMPermissions.sol";
// import "src/WMRegistry.sol";
// import "src/WMVaultFactory.sol";
import "./helpers/BaseVaultTest.sol";

contract VaultFactoryTest is BaseVaultTest {
    using stdStorage for StdStorage;
    using Math for uint256;
    using Math for int256;

    function test_DeployVaultAsNotWintermute() external {
      vm.expectRevert(WMVaultFactory.NotWintermute.selector);
      _deployDAIVault();
    }

    function test_DeployVaultToExpectedAddress() external {
      vm.prank(wintermute);
      assertEq(_getVaultAddress(address(factory), DaiSalt), address(wmDAI));
      assertEq(factory.computeVaultAddress(DaiSalt), address(wmDAI));
    }

    function test_DeployVaultData() public {
        // Names set with correct prefixes
        assertEq(wmDAI.name(), "Wintermute Dai Stablecoin");
        assertEq(wmDAI.symbol(), "wmtDAI");
       
        // Constructor arguments pulled from factory are correct
        // and initial values match expected
        assertEq(wmDAI.asset(), address(DAI));
        assertEq(wmDAI.totalSupply(), 0);
        assertEq(wmDAI.maxTotalSupply(), DefaultMaximumSupply);
        (
          int256 annualInterestBips,
          uint256 scaledTotalSupply,
          uint256 scaleFactor,
          uint256 lastInterestAccruedTimestamp
        ) = wmDAI.getState();
        assertEq(annualInterestBips, DefaultAPRBips);
        assertEq(scaledTotalSupply, 0);
        assertEq(scaleFactor, RayOne);
        assertEq(lastInterestAccruedTimestamp, block.timestamp);

        // Vault added to registry
        address[] memory regVaults = registry.listVaults();
        assertEq(regVaults.length, 1);
        assertEq(regVaults[0], address(wmDAI));
    }

    function test_PermissionsGranted() public {
        bool allowed = perms.isWhitelisted(wlUser);
        assertTrue(allowed);
    }

    function test_PermissionsNotGranted() public {
        bool allowed = perms.isWhitelisted(nonwlUser);
        assertFalse(allowed);
    }

}