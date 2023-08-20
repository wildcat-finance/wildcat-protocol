// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import './interfaces/IWildcatVaultController.sol';
import { WildcatMarket } from './market/WildcatMarket.sol';

contract WildcatVaultFactory {
	/// @dev temporary storage for vault parameters, used during vault deployment
	VaultParameters internal _tmpVaultParameters;

	constructor() {
		resetTmpVaultParameters();
	}

	function resetTmpVaultParameters() internal {
		_tmpVaultParameters = VaultParameters({
			asset: address(1),
			namePrefix: '_',
			symbolPrefix: '_',
			borrower: address(1),
			controller: address(1),
			feeRecipient: address(1),
			sentinel: address(1),
			maxTotalSupply: 1,
			protocolFeeBips: 1,
			annualInterestBips: 1,
			delinquencyFeeBips: 1,
			withdrawalBatchDuration: 1,
			liquidityCoverageRatio: 1,
			delinquencyGracePeriod: 1
		});
	}

	/// @dev hash of the vault creation code, used for computing the vault address
	bytes32 public immutable VaultInitCodeHash = keccak256(type(WildcatMarket).creationCode);

	address[] public vaults;

	function getVaultsCount() external view returns (uint256) {
		return vaults.length;
	}

	function getVaults(uint256 start, uint256 length) external view returns (address[] memory) {
		address[] memory result = new address[](length);
		for (uint256 i = start; i < length; i++) {
			result[i] = vaults[start + i];
		}
		return result;
	}

	function getVaultParameters() external view returns (VaultParameters memory) {
		return _tmpVaultParameters;
	}

	event VaultDeployed(address indexed controller, address indexed underlying, address vault);

	function deployVault(VaultParameters memory vaultParameters) external returns (address vault) {
		bytes32 salt = _deriveSalt(vaultParameters.controller, msg.sender, vaultParameters.asset);
		vault = _computeVaultAddress(salt);

		if (vaultParameters.controller != msg.sender) {
			IWildcatVaultController controller = IWildcatVaultController(vaultParameters.controller);
			// Allow controller to make modifications to the vault parameters and handle any
			// other checks or state changes prior to the vault's deployment.
			vaultParameters = controller.beforeDeployVault(vault, msg.sender, vaultParameters);
		}
		_tmpVaultParameters = vaultParameters;
		new WildcatMarket{ salt: salt }();
		resetTmpVaultParameters();

		emit VaultDeployed(vaultParameters.controller, vaultParameters.asset, vault);
	}

	function _deriveSalt(
		address controller,
		address deployer,
		address asset
	) internal pure returns (bytes32) {
		return keccak256(abi.encode(controller, deployer, asset));
	}

	function computeVaultAddress(
		address controller,
		address deployer,
		address asset
	) external view returns (address) {
		return _computeVaultAddress(_deriveSalt(controller, deployer, asset));
	}

	function _computeVaultAddress(bytes32 salt) internal view returns (address) {
		return
			address(
				uint160(
					uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, VaultInitCodeHash)))
				)
			);
	}
}
