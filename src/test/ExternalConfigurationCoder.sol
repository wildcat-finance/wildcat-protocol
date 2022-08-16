// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import '../types/ConfigurationCoder.sol';

// ============================== NOTICE ==============================
// This library was automatically generated with stackpacker.
// Be very careful about modifying it, as doing so incorrectly could
// result in corrupted reads/writes.
// ====================================================================

contract ExternalConfigurationCoder {
	Configuration internal _configuration;

	function decode()
		external
		view
		returns (address owner, uint256 maxTotalSupply)
	{
		(owner, maxTotalSupply) = ConfigurationCoder.decode(_configuration);
	}

	function encode(address owner, uint256 maxTotalSupply) external {
		(_configuration) = ConfigurationCoder.encode(owner, maxTotalSupply);
	}

	function getOwner() external view returns (address owner) {
		(owner) = ConfigurationCoder.getOwner(_configuration);
	}

	function setOwner(address owner) external {
		(_configuration) = ConfigurationCoder.setOwner(_configuration, owner);
	}

	function getMaxTotalSupply() external view returns (uint256 maxTotalSupply) {
		(maxTotalSupply) = ConfigurationCoder.getMaxTotalSupply(_configuration);
	}

	function setMaxTotalSupply(uint256 maxTotalSupply) external {
		(_configuration) = ConfigurationCoder.setMaxTotalSupply(
			_configuration,
			maxTotalSupply
		);
	}
}
