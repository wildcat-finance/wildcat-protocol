// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;
import './interfaces/IWildcatVaultFactory.sol';
import './interfaces/IController.sol';
import './WildcatVaultToken.sol';

contract WildcatVaultFactory {
	address public immutable feeRecipient;
	VaultParameters public getVaultParameters;

	constructor(address _feeRecipient) {
		feeRecipient = _feeRecipient;
	}

	event VaultDeployed(address indexed controller, address indexed underlying, address vault);

	function deployVault(VaultParameters memory vaultParameters) external returns (address vault) {
		require(
			IController(vaultParameters.controller).canDeployVault(
				vaultParameters.borrower,
				vaultParameters.asset
			),
			'VaultFactory: Cannot deploy vault'
		);
		getVaultParameters = vaultParameters;
		getVaultParameters.feeRecipient = feeRecipient;
		vault = address(new WildcatVaultToken());
		emit VaultDeployed(vaultParameters.controller, vaultParameters.asset, vault);
		IController(vaultParameters.controller).onDeployedVault(vaultParameters.borrower, vault);
	}
}
