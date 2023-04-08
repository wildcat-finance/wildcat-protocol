// SPDX-License-Identifier: NONE
pragma solidity ^0.8.17;

import './interfaces/IERC20.sol';
import './interfaces/IWildcatPermissions.sol';
import './interfaces/IWildcatVault.sol';
import { SafeTransferLib } from './libraries/SafeTransferLib.sol';
import './WildcatVault.sol';
import './libraries/StringPackerPrefixer.sol';

contract WildcatVaultFactory is StringPackerPrefixer {
	bytes32 public immutable VaultInitCodeHash =
		keccak256(type(WildcatVault).creationCode);

	constructor() {
		_resetVaultParameters();
	}

	address internal _vaultOwner;
	address internal _vaultAsset;
	bytes32 internal _vaultNamePrefix;
	bytes32 internal _vaultSymbolPrefix;
	address internal _controller;
	uint256 internal _vaultMaxTotalSupply;
	uint256 internal _vaultAnnualInterestBips;
	uint256 internal _vaultliquidityCoverageRatio;

	function _resetVaultParameters() internal {
		_vaultOwner = address(1);
		_vaultAsset = address(1);
		_vaultNamePrefix = bytes32(uint256(1));
		_vaultSymbolPrefix = bytes32(uint256(1));
		_controller = address(1);
		_vaultMaxTotalSupply = 1;
		_vaultAnnualInterestBips = 1;
		_vaultliquidityCoverageRatio = 1;
	}

	function getVaultParameters()
		external
		view
		returns (
			address asset,
			bytes32 namePrefix,
			bytes32 symbolPrefix,
			address owner,
			address controller,
			uint256 maxTotalSupply,
			uint256 annualInterestBips,
			uint256 liquidityCoverageRatio,
			uint256 interestFeeBips
		)
	{
		asset = _vaultAsset;
		owner = _vaultOwner;
		controller = _controller;
		if (controller != address(0)) {
			interestFeeBips = IWildcatPermissions(controller)
				.getInterestFeeBips(owner, asset, msg.sender);
		}
		return (
			asset,
			_vaultNamePrefix,
			_vaultSymbolPrefix,
			owner,
			controller,
			_vaultMaxTotalSupply,
			_vaultAnnualInterestBips,
			_vaultliquidityCoverageRatio,
			interestFeeBips
		);
	}

	function deployVault(
		address _asset,
		address _permissions,
		uint256 _maxTotalSupply,
		uint256 _annualInterestBips,
		uint256 _liquidityCoverageRatio,
		string memory _namePrefix,
		string memory _symbolPrefix,
		bytes32 _salt
	) public returns (address vault) {
		bytes32 salt = _deriveSalt(msg.sender, _permissions, _asset, _salt);
		IWildcatPermissions(_permissions).onDeployVault(
			msg.sender,
			_asset,
			_computeVaultAddress(salt),
			_liquidityCoverageRatio,
			_annualInterestBips
		);
		// Set variables for vault creation
		_vaultOwner = msg.sender;
		_vaultAsset = _asset;
		_vaultNamePrefix = _packString(_namePrefix);
		_vaultSymbolPrefix = _packString(_symbolPrefix);
		_controller = _permissions;
		_vaultMaxTotalSupply = _maxTotalSupply;
		_vaultAnnualInterestBips = _annualInterestBips;
		_vaultliquidityCoverageRatio = _liquidityCoverageRatio;
		vault = address(new WildcatVault{ salt: salt }());
		_resetVaultParameters();
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
		return
			_computeVaultAddress(_deriveSalt(deployer, permissions, asset, _salt));
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
