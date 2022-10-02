// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

import "./helpers/BaseVaultTest.sol";

contract VaultFactoryTest is BaseVaultTest {
    using stdStorage for StdStorage;
    using Math for uint256;
    using Math for int256;

    function test_DeployVaultAsNotWintermute() external {
      vm.expectRevert(WildcatPermissions.NotApprovedForDeploy.selector); // TODO: be more specific with the type of revert
      _deployDAIVault();
    }

    function test_DeployVaultToExpectedAddress() external {
      vm.prank(wildcatController);
      assertEq(_getVaultAddress(), address(wcDAI));
      assertEq(factory.computeVaultAddress(wintermuteController, address(perms), address(DAI), DaiSalt), address(wcDAI));
    }

    function test_DeployVaultData() public {
        // Names set with correct prefixes
        assertEq(wcDAI.name(), "Wintermute Dai Stablecoin");
        assertEq(wcDAI.symbol(), "wmtDAI");
       
        // Constructor arguments pulled from factory are correct
        // and initial values match expected
        assertEq(wcDAI.asset(), address(DAI));
        assertEq(wcDAI.totalSupply(), 0);
        assertEq(wcDAI.maxTotalSupply(), DefaultMaximumSupply);
        (
          uint256 annualInterestBips,
          uint256 scaledTotalSupply,
          uint256 scaleFactor,
          uint256 lastInterestAccruedTimestamp
        ) = wcDAI.stateParameters();
        assertEq(annualInterestBips, DefaultAPRBips);
        assertEq(scaledTotalSupply, 0);
        assertEq(scaleFactor, RayOne);
        assertEq(lastInterestAccruedTimestamp, block.timestamp);
    }

    function test_PermissionsGranted() public {
        bool allowed = perms.isWhitelisted(address(wcDAI), wlUser);
        assertTrue(allowed);
    }

    function test_PermissionsNotGranted() public {
        bool allowed = perms.isWhitelisted(address(wcDAI), nonwlUser);
        assertFalse(allowed);
    }

}