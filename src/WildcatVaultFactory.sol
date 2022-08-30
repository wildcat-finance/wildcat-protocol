// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

import './interfaces/IWildcatPermissions.sol';
import './interfaces/IWildcatRegistry.sol';
import './interfaces/IWildcatVault.sol';

import './WildcatVault.sol';
import './WildcatRegistry.sol';

contract WildcatVaultFactory {
	error NotController();

	address internal wcPermissionAddress;

	IWildcatRegistry internal wcRegistry;

	bytes32 public immutable VaultInitCodeHash =
		keccak256(type(WildcatVault).creationCode);

	address public factoryVaultUnderlying      = address(0x00);
	address public factoryPermissionRegistry   = address(0x00);

	uint256 public factoryVaultMaximumCapacity = 0;
	int256 public factoryVaultAnnualAPR        = 0;
	uint256 public factoryVaultCollatRatio     = 0;

	string public factoryVaultNamePrefix       = "";
	string public factoryVaultSymbolPrefix     = "";

	event WMVaultRegistered(address, address);

	modifier isWildcatController() {
		if (msg.sender != IWildcatPermissions(wcPermissionAddress).controller()) {
			revert NotController();
		}
		_;
	}

	constructor(address _permissions) {
		wcPermissionAddress = _permissions;
		WildcatRegistry registry = new WildcatRegistry{ salt: bytes32(0x0) }();
		wcRegistry = IWildcatRegistry(address(registry));
	}

	function deployVault(
		address _underlying,
		uint256 _maxCapacity,
		int256 _annualAPR,
		uint256 _collatRatio,
		string memory _namePrefix,
		string memory _symbolPrefix,
		bytes32 _salt
	) public isWildcatController returns (address vault) {
		// Set variables for vault creation
		factoryVaultUnderlying      = _underlying;
		factoryPermissionRegistry   = wcPermissionAddress;
		factoryVaultMaximumCapacity = _maxCapacity;
		factoryVaultAnnualAPR       = _annualAPR;
		factoryVaultCollatRatio     = _collatRatio;
		factoryVaultNamePrefix      = _namePrefix;
		factoryVaultSymbolPrefix    = _symbolPrefix;

		vault = address(new WMVault{ salt: _salt }());
		wmRegistry.registerVault(vault);

		// Reset variables for gas refund
		factoryVaultUnderlying      = address(0x00);
		factoryPermissionRegistry   = address(0x00);
		factoryVaultMaximumCapacity = 0;
		factoryVaultAnnualAPR       = 0;
		factoryVaultCollatRatio     = 0;
		factoryVaultNamePrefix      = "";
		factoryVaultSymbolPrefix    = "";
	}

	function vaultPermissionsAddress() external view returns (address) {
		return wcPermissionAddress;
	}

	function vaultRegistryAddress() external view returns (address) {
		return address(wcRegistry);
	}

	function computeVaultAddress(bytes32 salt) external view returns (address) {
		return
			address(
				uint160(
					uint256(
						keccak256(
							abi.encodePacked(
								bytes1(0xff),
								address(this),
								salt,
								VaultInitCodeHash
							)
						)
					)
				)
			);
	}
}
