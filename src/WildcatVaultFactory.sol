// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

import './interfaces/IERC20.sol';
import './interfaces/IWildcatPermissions.sol';
import './interfaces/IWildcatRegistry.sol';
import './interfaces/IWildcatVault.sol';
import { SafeTransferLib } from './libraries/SafeTransferLib.sol';
import './WildcatVault.sol';
import './WildcatRegistry.sol';
import "./libraries/StringPackerPrefixer.sol";

contract WildcatVaultFactory is StringPackerPrefixer {

	IWildcatRegistry internal wcRegistry;
	IWildcatPermissions internal wcPermissions;

	bytes32 public immutable VaultInitCodeHash =
		keccak256(type(WildcatVault).creationCode);

	// Temporary storage of vault initialization parameters
	// address public factoryVaultUnderlying      = address(0x00);
	// address public factoryPermissionRegistry   = address(0x00);
	// uint256 public factoryVaultMaximumCapacity = 0;
	// uint256 public factoryVaultAnnualAPR        = 0;
	// uint256 public factoryVaultCollatRatio     = 0;
	// uint256 public factoryVaultInterestFeeBips     = 0;

	// string public factoryVaultNamePrefix       = "";
	// string public factoryVaultSymbolPrefix     = "";

	mapping(address => mapping (address => bool)) internal validatedVaults;
	IERC20 internal erc20USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
	uint256 public vaultValidationFee = 0;

	constructor(address _permissions) {
		wcPermissions = IWildcatPermissions(_permissions);
		WildcatRegistry registry = new WildcatRegistry{ salt: bytes32(0x0) }();
		wcRegistry = IWildcatRegistry(address(registry));
		_resetVaultParameters();
	}

	// Note: anyone can pay this fee on behalf of a vault controller, provided they're approved
	function validateVaultDeployment(address _controller, address _underlying) external {
		require(wcPermissions.isApprovedController(_controller),
				"given controller is not approved by wildcat to deploy");
		address recipient = wcPermissions.archRecipient();
		SafeTransferLib.safeTransferFrom(address(erc20USDC), msg.sender, recipient, vaultValidationFee);
		validatedVaults[_controller][_underlying] = true;
	}

	// function validateConfig(address deployer, address vault, uint collatRatio, uint annualInterestBips)
	address internal _vaultOwner;
	address internal _vaultAsset;
	bytes32 internal _vaultNamePrefix;
	bytes32 internal _vaultSymbolPrefix;
	address internal _vaultPermissions;
	uint256 internal _vaultMaxTotalSupply;
	uint256 internal _vaultAnnualInterestBips;
	uint256 internal _vaultCollateralizationRatioBips;

	function _resetVaultParameters() internal {
		_vaultOwner = address(1);
		_vaultAsset = address(1);
		_vaultNamePrefix = bytes32(uint256(1));
		_vaultSymbolPrefix = bytes32(uint256(1));
		_vaultPermissions = address(1);
		_vaultMaxTotalSupply = 1;
		_vaultAnnualInterestBips = 1;
		_vaultCollateralizationRatioBips = 1;
	}

	function getVaultParameters() external view returns (
		address asset,
		bytes32 namePrefix,
		bytes32 symbolPrefix,
		address owner,
		address vaultPermissions,
		uint256 maxTotalSupply,
		uint256 annualInterestBips,
		uint256 collateralizationRatioBips,
		uint256 interestFeeBips
	) {
		asset = _vaultAsset;
		owner = _vaultOwner;
		vaultPermissions = _vaultPermissions;
		if (vaultPermissions != address(0)) {
			interestFeeBips = IWildcatPermissions(vaultPermissions).getInterestFeeBips(owner, asset, msg.sender);
		}
		return (
			asset,
			_vaultNamePrefix,
			_vaultSymbolPrefix,
			owner,
			vaultPermissions,
			_vaultMaxTotalSupply,
			_vaultAnnualInterestBips,
			_vaultCollateralizationRatioBips,
			interestFeeBips
		);
	}

	function deployVault(
		address _asset,
		address _permissions,
		uint256 _maxTotalSupply,
		uint256 _annualInterestBips,
		uint256 _collateralizationRatioBips,
		string memory _namePrefix,
		string memory _symbolPrefix,
		bytes32 _salt
	) public returns (address vault) {
		bytes32 salt = _deriveSalt(msg.sender, _permissions, _asset, _salt);
		IWildcatPermissions(_permissions).onDeployVault(
			msg.sender,
			_asset,
			_computeVaultAddress(salt),
			_collateralizationRatioBips,
			_annualInterestBips
		);
		// Set variables for vault creation
		_vaultOwner = msg.sender;
		_vaultAsset = _asset;
		_vaultNamePrefix = _packString(_namePrefix);
		_vaultSymbolPrefix = _packString(_symbolPrefix);
		_vaultPermissions = _permissions;
		_vaultMaxTotalSupply = _maxTotalSupply;
		_vaultAnnualInterestBips = _annualInterestBips;
		_vaultCollateralizationRatioBips = _collateralizationRatioBips;
		vault = address(new WildcatVault{ salt: salt }());
		_resetVaultParameters();
	}

	function vaultRegistryAddress() external view returns (address) {
		return address(wcRegistry);
	}

	function _deriveSalt(
		address deployer,
		address permissions,
		address asset,
		bytes32 _salt
	) internal pure returns (bytes32) {
		return keccak256(abi.encode(deployer, permissions, asset, _salt));
	}

	function computeVaultAddress(
		address deployer,
		address permissions,
		address asset,
		bytes32 _salt
	) external view returns (address) {
		return _computeVaultAddress(_deriveSalt(deployer, permissions, asset, _salt));
	}

	function _computeVaultAddress(bytes32 salt) internal view returns (address) {
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
