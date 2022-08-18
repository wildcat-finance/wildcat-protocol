// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

import './interfaces/IWMPermissions.sol';
import './interfaces/IWMRegistry.sol';
import './interfaces/IWMVault.sol';

import './WMVault.sol';
import './WMRegistry.sol';

contract WMVaultFactory {
	address internal wmPermissionAddress;

	IWMRegistry internal wmRegistry;

  bytes32 public immutable VaultInitCodeHash = keccak256(type(WMVault).creationCode);

	address public factoryVaultUnderlying = address(0x00);
	address public factoryPermissionRegistry = address(0x00);

	// can shave these values down to appropriate uintX later
	uint256 public factoryVaultMaximumCapacity = 0;
	int256 public factoryVaultAnnualAPR = 0;
	uint256 public factoryVaultCollatRatio = 0;

	event WMVaultRegistered(address, address);

	modifier isWintermute() {
		address wintermute = IWMPermissions(wmPermissionAddress).wintermute();
		require(msg.sender == wintermute);
		_;
	}

	constructor(address _permissions) {
		wmPermissionAddress = _permissions;
		WMRegistry registry = new WMRegistry{ salt: bytes32(0x0) }();
		wmRegistry = IWMRegistry(address(registry));
	}

	function deployVault(
		address _underlying,
		uint256 _maxCapacity,
		int256 _annualAPR,
		uint256 _collatRatio,
		bytes32 _salt
	) public isWintermute returns (address vault) {
		// Set variables for vault creation
		factoryVaultUnderlying = _underlying;
		factoryPermissionRegistry = wmPermissionAddress;
		factoryVaultMaximumCapacity = _maxCapacity;
		factoryVaultAnnualAPR = _annualAPR;
		factoryVaultCollatRatio = _collatRatio;

		vault = address(new WMVault{ salt: _salt }());
		wmRegistry.registerVault(vault);

		// Reset variables for gas refund
		factoryVaultUnderlying = address(0x00);
		factoryPermissionRegistry = address(0x00);
		factoryVaultMaximumCapacity = 0;
		factoryVaultAnnualAPR = 0;
		factoryVaultCollatRatio = 0;
	}

	function vaultPermissionsAddress() external view returns (address) {
		return wmPermissionAddress;
	}

	function vaultRegistryAddress() external view returns (address) {
		return address(wmRegistry);
	}

  function computeVaultAddress(bytes32 salt) external view returns (address) {
    return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, VaultInitCodeHash)))));
  }
}
