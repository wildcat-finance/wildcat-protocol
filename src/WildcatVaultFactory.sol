// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

import './interfaces/IERC20.sol';

import './interfaces/IWildcatPermissions.sol';
import './interfaces/IWildcatRegistry.sol';
import './interfaces/IWildcatVault.sol';

import { SafeTransferLib } from './libraries/SafeTransferLib.sol';

import './WildcatVault.sol';
import './WildcatRegistry.sol';

contract WildcatVaultFactory {

	IWildcatRegistry internal wcRegistry;
	IWildcatPermissions internal wcPermissions;

	bytes32 public immutable VaultInitCodeHash =
		keccak256(type(WildcatVault).creationCode);

	address public factoryVaultUnderlying      = address(0x00);
	address public factoryPermissionRegistry   = address(0x00);

	uint256 public factoryVaultMaximumCapacity = 0;
	uint256 public factoryVaultAnnualAPR        = 0;
	uint256 public factoryVaultCollatRatio     = 0;
	uint256 public factoryVaultInterestFeeBips     = 0;

	string public factoryVaultNamePrefix       = "";
	string public factoryVaultSymbolPrefix     = "";

	mapping(address => mapping (address => bool)) validatedVaults;
	IERC20 erc20USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
	uint256 vaultValidationFee = 0;

	constructor(address _permissions) {
		wcPermissions = IWildcatPermissions(_permissions);
		WildcatRegistry registry = new WildcatRegistry{ salt: bytes32(0x0) }();
		wcRegistry = IWildcatRegistry(address(registry));
	}

	// Note: anyone can pay this fee on behalf of a vault controller, provided they're approved
	function validateVaultDeployment(address _controller, address _underlying) external {
		require(wcPermissions.isApprovedController(_controller),
				"given controller is not approved by wildcat to deploy");
		address recipient = wcPermissions.archRecipient();
		SafeTransferLib.safeTransferFrom(address(erc20USDC), msg.sender, recipient, vaultValidationFee);
		validatedVaults[_controller][_underlying] = true;
	}

	function deployVault(
		address _vaultOwner,
		address _underlying,
		uint256 _maxCapacity,
		uint256 _annualAPR,
		uint256 _collatRatio,
		string memory _namePrefix,
		string memory _symbolPrefix,
		bytes32 _salt
	) public returns (address vault) {

		require(validatedVaults[_vaultOwner][_underlying], "deployVault: vault not validated");

		// Set variables for vault creation
		factoryVaultUnderlying      = _underlying;
		factoryPermissionRegistry   = address(wcPermissions);
		factoryVaultMaximumCapacity = _maxCapacity;
		factoryVaultAnnualAPR       = _annualAPR;
		factoryVaultCollatRatio     = _collatRatio;
    // @todo - implement
    factoryVaultInterestFeeBips = 0;
		factoryVaultNamePrefix      = _namePrefix;
		factoryVaultSymbolPrefix    = _symbolPrefix;

		vault = address(new WildcatVault{ salt: _salt }());
		wcRegistry.registerVault(vault);
		wcPermissions.registerVaultController(vault, _vaultOwner);

		// Reset variables for gas refund
		factoryVaultUnderlying      = address(0x00);
		factoryPermissionRegistry   = address(0x00);
		factoryVaultMaximumCapacity = 0;
		factoryVaultAnnualAPR       = 0;
		factoryVaultCollatRatio     = 0;
    factoryVaultInterestFeeBips = 0;
		factoryVaultNamePrefix      = "";
		factoryVaultSymbolPrefix    = "";
	}

	function vaultPermissionsAddress() external view returns (address) {
		return address(wcPermissions);
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
