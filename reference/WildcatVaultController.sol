// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import './WildcatVaultToken.sol';
import './interfaces/IWildcatVaultFactory.sol';
import 'solady/auth/Ownable.sol';

struct TemporaryLiquidityCoverage {
	uint128 liquidityCoverageRatio;
	uint128 expiry;
}

contract WildcatVaultController is Ownable {
	address public immutable factory;
  address public immutable feeRecipient;

	mapping(address => bool) public vaults;

	mapping(address => TemporaryLiquidityCoverage) public temporaryExcessLiquidityCoverage;

	constructor(address _feeRecipient, address _factory) {
		_initializeOwner(msg.sender);
    feeRecipient = _feeRecipient;
		factory = _factory;
	}

	function checkGte(
		uint256 value,
		uint256 defaultValue,
		string memory err
	) internal pure returns (uint256) {
		if (value == 0) return defaultValue;
		require(value >= defaultValue, err);
		return value;
	}

	function checkLte(
		uint256 value,
		uint256 defaultValue,
		string memory err
	) internal pure returns (uint256) {
		if (value == 0) return defaultValue;
		require(value <= defaultValue, err);
		return value;
	}

	function getVaultParameters(
		address /* deployer */,
		VaultParameters memory vaultParameters
	) public view returns (VaultParameters memory) {
		// Doesn't do anything when called by the factory
		require(vaultParameters.controller == address(this), 'WildcatVaultController: Not controller');

		vaultParameters.feeRecipient = feeRecipient;

		vaultParameters.gracePeriod = checkLte(
			vaultParameters.gracePeriod,
			1 days,
			'WildcatVaultController: Grace period too long'
		);

		vaultParameters.liquidityCoverageRatio = checkGte(
			vaultParameters.liquidityCoverageRatio,
			1000,
			'WildcatVaultController: Liquidity coverage ratio too low'
		);

		vaultParameters.penaltyFeeBips = checkGte(
			vaultParameters.penaltyFeeBips,
			1000,
			'WildcatVaultController: Penalty fee too low'
		);

		return vaultParameters;
	}

	function handleDeployVault(
		address vault,
		address deployer,
		VaultParameters memory vaultParameters
	) external returns (VaultParameters memory) {
		require(msg.sender == factory, 'WildcatVaultController: Not factory');

		vaults[vault] = true;

		return getVaultParameters(deployer, vaultParameters);
	}

	/**
	 * @dev Reduces the interest rate for a vault and increases
	 * the liquidity coverage ratio for the next two weeks.
	 */
	function reduceInterestRate(address vault, uint256 amount) external {
		require(
			msg.sender == WildcatVaultToken(vault).borrower(),
			'WildcatVaultController: Not owner or borrower'
		);

		require(vaults[vault], 'WildcatVaultController: Unknown vault');

		require(
			temporaryExcessLiquidityCoverage[vault].expiry == 0,
			'WildcatVaultController: Excess liquidity coverage already active'
		);

		uint256 liquidityCoverageRatio = WildcatVaultToken(vault).liquidityCoverageRatio();
		WildcatVaultToken(vault).setAnnualInterestBips(amount);

		// Require 90% liquidity coverage for the next 2 weeks
		WildcatVaultToken(vault).setLiquidityCoverageRatio(9000);

		temporaryExcessLiquidityCoverage[vault] = TemporaryLiquidityCoverage(
			uint128(liquidityCoverageRatio),
			uint128(block.timestamp + 2 weeks)
		);
	}

	function resetLiquidityCoverage(address vault) external {
		TemporaryLiquidityCoverage memory tmp = temporaryExcessLiquidityCoverage[vault];
		require(
			block.timestamp >= tmp.expiry,
			'WildcatVaultController: Excess liquidity coverage still active'
		);
		WildcatVaultToken(vault).setLiquidityCoverageRatio(tmp.liquidityCoverageRatio);
		delete temporaryExcessLiquidityCoverage[vault];
	}
}
