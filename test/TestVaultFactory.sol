// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import 'forge-std/Test.sol';
import 'reference/WildcatVaultFactory.sol';
import 'reference/WildcatVaultController.sol';
import { MockERC20 } from 'solmate/test/utils/mocks/MockERC20.sol';
import "./BaseVaultTest.sol";

contract FactoryTest is BaseVaultTest {

	function testDeployVault() public {
		assertEq(vault.name(), 'Wildcat Token', 'name');
		assertEq(vault.symbol(), 'WCTKN', 'symbol');
		require(vault.maxTotalSupply() == DefaultMaximumSupply);
		require(vault.annualInterestBips() == DefaultInterest);
		require(vault.delinquencyFeeBips() == DefaultPenaltyFee);
		require(vault.delinquencyGracePeriod() == DefaultGracePeriod);
		require(vault.liquidityCoverageRatio() == DefaultLiquidityCoverage);
		require(vault.protocolFeeBips() == DefaultInterestFee);
		require(vault.feeRecipient() == feeRecipient);
		require(vault.borrower() == borrower);
		require(vault.asset() == address(asset));
		require(vault.controller() == address(controller));
	}

	function testDeposit() external {
		asset.mint(address(this), 1e18);
    asset.approve(address(vault), 1e18);
    vault.depositUpTo(1e18);
    assertEq(vault.balanceOf(address(this)), 1e18);
	}
}