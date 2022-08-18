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

uint256 constant DefaultMaximumSupply = 100_000e18;
int256 constant DefaultAPRBips = 500;
uint256 constant DefaultCollateralizationRatio = 90;

contract VaultFactoryTest is Test {
    using stdStorage for StdStorage;
    using Math for uint256;
    using Math for int256;

    int256 internal immutable DefaultInterestPerSecondRay;

    bytes32 public immutable VaultInitCodeHash = keccak256(type(WMVault).creationCode);

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
      DefaultInterestPerSecondRay = DefaultAPRBips.annualBipsToRayPerSecond();
    }

    function _getVaultAddress(address factory, bytes32 salt) internal view returns (address) {
      return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), factory, salt, VaultInitCodeHash)))));
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
        bytes32 saltDAI = bytes32(uint256(1));
        address returnedVaultAddress = wmvf.deployVault(address(DAI), DefaultMaximumSupply, DefaultAPRBips, DefaultCollateralizationRatio, saltDAI);
        wmDAI = WMVault(returnedVaultAddress);

        // Verify vault was deployed to correct address
        assertEq(_getVaultAddress(address(wmvf), saltDAI), returnedVaultAddress);
        // Verify factory computes correct address
        assertEq(wmvf.computeVaultAddress(saltDAI), returnedVaultAddress);

        address wmrAddr = wmvf.vaultRegistryAddress();
        wmr = WMRegistry(wmrAddr);

        address[] memory regVaults = wmr.listVaults();

        // Verify registry pushes vault address
        assertEq(regVaults.length, 1);
        assertEq(regVaults[0], returnedVaultAddress);

        writeTokenBalance(wlUser, address(DAI), 100_000 * 1e18);
        writeTokenBalance(nonwlUser, address(DAI), 100_000 * 1e18);

        vm.prank(wlUser);
        DAI.approve(address(wmDAI), 100_000 * 1e18);
        
        vm.prank(nonwlUser);
        DAI.approve(address(wmDAI), 100_000 * 1e18);
    }

    function test_VaultCreated() public {
        assertEq(wmDAI.name(), "Wintermute Dai Stablecoin");
        assertEq(wmDAI.symbol(), "wmtDAI");
       
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