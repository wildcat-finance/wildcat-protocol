// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

import 'forge-std/Test.sol';
import 'forge-std/Vm.sol';

import './TestERC20.sol';

import 'src/WildcatPermissions.sol';
import 'src/WildcatVaultFactory.sol';

uint256 constant DefaultMaximumSupply = 100_000e18;
uint256 constant DefaultAPRBips = 500;
uint256 constant DefaultCollateralizationRatioBips = 9000;

bytes32 constant DaiSalt = bytes32(uint256(1));

contract BaseVaultTest is Test {
	using stdStorage for StdStorage;
	using Math for uint256;

	uint256 internal immutable DefaultInterestPerSecondRay =
		DefaultAPRBips.annualBipsToRayPerSecond();

	bytes32 internal immutable VaultInitCodeHash =
		keccak256(type(WildcatVault).creationCode);

	address internal wildcatController = address(0x69);
	address internal wintermuteController = address(0x70);
	address internal wlUser = address(0x42);
	address internal nonwlUser = address(0x43);

	WildcatPermissions internal perms;
	WildcatVaultFactory internal factory;

	TestERC20 internal DAI;
	WildcatVault internal wcDAI;

	function _deriveSalt(
		address deployer,
		address permissions,
		address asset,
		bytes32 _salt
	) internal pure returns (bytes32) {
		return keccak256(abi.encode(deployer, permissions, asset, _salt));
	}

	function _getVaultAddress()
		internal
		view
		returns (address)
	{
    bytes32 salt = _deriveSalt(wintermuteController, address(perms), address(DAI), DaiSalt);
		return
			address(
				uint160(
					uint256(
						keccak256(
							abi.encodePacked(bytes1(0xff), address(factory), salt, VaultInitCodeHash)
						)
					)
				)
			);
	}

	function _writeTokenBalance(
		address who,
		address token,
		uint256 amt
	) internal {
		stdstore
			.target(token)
			.sig(IERC20(token).balanceOf.selector)
			.with_key(who)
			.checked_write(amt);
	}

  function _approve(address from, address to, uint256 amount) internal {
    vm.prank(from);
    DAI.approve(to, amount);
  }

	function _warpOneYear() internal {
		vm.warp(block.timestamp + 365 days);
	}

	function _warpOneSecond() internal {
		vm.warp(block.timestamp + 1);
	}

	function _deployDAIVault() internal {
		address returnedVaultAddress = factory.deployVault(
			address(DAI),
			address(perms),
			DefaultMaximumSupply,
			DefaultAPRBips,
			DefaultCollateralizationRatioBips,
			"Wintermute ",
			"wmt",
			DaiSalt
		);
		wcDAI = WildcatVault(returnedVaultAddress);
	}

  function setupVault(uint256 interestFeeBips) internal {
		DAI = new TestERC20('Dai Stablecoin', 'DAI', 18);
		// @todo add fee tests
		perms = new WildcatPermissions(wildcatController, interestFeeBips);
		factory = new WildcatVaultFactory(address(perms));

		// TODO: pay the vault validation toll from one of the wl addresses
		vm.startPrank(wildcatController);
		perms.addApprovedController(wintermuteController);
		vm.stopPrank();

		vm.startPrank(wintermuteController);
		_deployDAIVault();
		vm.stopPrank();

		vm.startPrank(wildcatController);
		perms.adjustWhitelist(address(wcDAI), wlUser, true);
		vm.stopPrank();

		DAI.mint(wlUser, 100_000e18);
		DAI.mint(nonwlUser, 100_000e18);

		_approve(wlUser, address(wcDAI), DefaultMaximumSupply);
    _approve(nonwlUser, address(wcDAI), DefaultMaximumSupply);
  }

	function setUp() public {
		setupVault(0);
	}
}
