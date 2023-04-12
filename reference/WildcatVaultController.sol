// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import './WildcatVaultToken.sol';

contract WildcatVaultController {
	mapping(address => bool) public vaults;
	struct TemporaryLiquidityCoverage {
		uint128 liquidityCoverageRatio;
		uint128 expiry;
	}
	mapping(address => TemporaryLiquidityCoverage) public temporaryExcessLiquidityCoverage;

	function canDeployVault(address, address) external pure returns (bool) {
		return true;
	}

	function onDeployedVault(address, address vault) external {
		vaults[vault] = true;
	}

	/**
	 * @dev Reduces the interest rate for a vault and increases
	 * the liquidity coverage ratio for the next two weeks.
	 */
	function reduceInterestRate(address vault, uint256 amount) external {
		require(
			msg.sender == WildcatVaultToken(vault).borrower(),
			'WildcatVaultController: Not borrower'
		);
		require(vaults[vault], 'WildcatVaultController: Not a vault');
		require(
			temporaryExcessLiquidityCoverage[vault].expiry == 0,
			'WildcatVaultController: Excess liquidity coverage already active'
		);
		uint256 liquidityCoverageRatio = WildcatVaultToken(vault).liquidityCoverageRatio();
		WildcatVaultToken(vault).setAnnualInterestBips(amount);
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
