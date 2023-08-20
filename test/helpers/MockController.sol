// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.20;

import 'src/WildcatVaultController.sol';

contract MockController is WildcatVaultController {
	constructor(
		address _feeRecipient,
		address _factory
	) WildcatVaultController(_feeRecipient, _factory) {}

	function isAuthorizedLender(address) external view virtual override returns (bool) {
		return true;
	}
}
