// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

import 'forge-std/Test.sol';
import 'forge-std/Vm.sol';

import './TestERC20.sol';

import 'src/WMPermissions.sol';
import 'src/WMRegistry.sol';
import 'src/WMVaultFactory.sol';

uint256 constant DefaultMaximumSupply = 100_000e18;
int256 constant DefaultAPRBips = 500;
uint256 constant DefaultCollateralizationRatio = 90;

bytes32 constant DaiSalt = bytes32(uint256(1));

contract BaseVaultTest is Test {
	using stdStorage for StdStorage;
	using Math for uint256;
	using Math for int256;

	int256 internal immutable DefaultInterestPerSecondRay =
		DefaultAPRBips.annualBipsToRayPerSecond();

	bytes32 internal immutable VaultInitCodeHash =
		keccak256(type(WMVault).creationCode);

	address internal wintermute = address(0x69);
	address internal wlUser = address(0x42);
	address internal nonwlUser = address(0x43);

	WMPermissions internal perms;
	WMRegistry internal registry;
	WMVaultFactory internal factory;

	TestERC20 internal DAI;
	WMVault internal wmDAI;

	function _resetContracts() internal {
		DAI = new TestERC20('Dai Stablecoin', 'DAI', 18);
		perms = new WMPermissions(wintermute);
		factory = new WMVaultFactory(address(perms));
		registry = WMRegistry(factory.vaultRegistryAddress());
	}

	function _getVaultAddress(address factory, bytes32 salt)
		internal
		view
		returns (address)
	{
		return
			address(
				uint160(
					uint256(
						keccak256(
							abi.encodePacked(bytes1(0xff), factory, salt, VaultInitCodeHash)
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
			DefaultMaximumSupply,
			DefaultAPRBips,
			DefaultCollateralizationRatio,
			DaiSalt
		);
		wmDAI = WMVault(returnedVaultAddress);
	}

	function setUp() public {
		_resetContracts();

		vm.startPrank(wintermute);
		perms.adjustWhitelist(wlUser, true);
		_deployDAIVault();
		vm.stopPrank();

		DAI.mint(wlUser, 100_000e18);
		DAI.mint(nonwlUser, 100_000e18);

		_approve(wlUser, address(wmDAI), DefaultMaximumSupply);
    _approve(nonwlUser, address(wmDAI), DefaultMaximumSupply);
	}
}
