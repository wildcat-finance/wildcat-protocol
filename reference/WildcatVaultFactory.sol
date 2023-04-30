// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;
import './interfaces/IWildcatVaultFactory.sol';
import './interfaces/IWildcatVaultController.sol';
import './WildcatVaultToken.sol';

contract WildcatVaultFactory {
	/// @dev temporary storage for vault parameters, used during vault deployment
	VaultParameters internal _tmpVaultParameters;

	/// @dev hash of the vault creation code, used for computing the vault address
	bytes32 public immutable VaultInitCodeHash = keccak256(type(WildcatVaultToken).creationCode);

	function getVaultParameters() external view returns (VaultParameters memory) {
		return _tmpVaultParameters;
	}

	event VaultDeployed(address indexed controller, address indexed underlying, address vault);

	function deployVault(VaultParameters memory vaultParameters) external returns (address vault) {
		if (vaultParameters.controller == address(0)) {
			vaultParameters.controller = msg.sender;
		}
		bytes32 salt = _deriveSalt(vaultParameters.controller, msg.sender, vaultParameters.asset);
		vault = _computeVaultAddress(salt);
		if (
			vaultParameters.controller != msg.sender &&
			address(vaultParameters.controller).code.length > 0
		) {
			IWildcatVaultController controller = IWildcatVaultController(vaultParameters.controller);
			// Allow controller to make any modifications to the vault parameters
			vaultParameters = controller.handleDeployVault(vault, msg.sender, vaultParameters);
		}
		_tmpVaultParameters = vaultParameters;
		require(
			vault == address(new WildcatVaultToken{ salt: salt }()),
			'Sanity check failed: vault address'
		);
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
