// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import 'forge-std/Test.sol';
import 'reference/WildcatVaultFactory.sol';
import 'reference/WildcatVaultController.sol';
import { MockERC20 } from 'solmate/test/utils/mocks/MockERC20.sol';

contract FactoryTest is Test {
	WildcatVaultFactory internal factory;
	WildcatVaultController internal controller;
  address internal feeRecipient = address(0xfee);
	address internal borrower = address(0xb0b);
	MockERC20 internal asset;

	function setUp() public {
		factory = new WildcatVaultFactory(feeRecipient);
		controller = new WildcatVaultController();
		asset = new MockERC20('Token', 'TKN', 18);
	}

	function testDeployVault() public {
		VaultParameters memory vaultParameters;
		vaultParameters.borrower = borrower;
		vaultParameters.asset = address(asset);
		vaultParameters.controller = address(controller);

		vaultParameters.namePrefix = "Wildcat ";
		vaultParameters.symbolPrefix = "WC";

		vaultParameters.maxTotalSupply = type(uint128).max;
		vaultParameters.annualInterestBips = 1000;
		vaultParameters.penaltyFeeBips = 1000;
		vaultParameters.gracePeriod = 1 days;
		vaultParameters.liquidityCoverageRatio = 2000;
		vaultParameters.interestFeeBips = 1000;
		vaultParameters.feeRecipient = feeRecipient;
		WildcatVaultToken vault = WildcatVaultToken(factory.deployVault(params));
    require(vault.name() == "Wildcat Token");
    require(vault.symbol() == "WCTKN");
    require(vault.maxTotalSupply() == type(uint128).max);
    require(vault.annualInterestBips() == 1000);
    require(vault.penaltyFeeBips() == 1000);
    require(vault.gracePeriod() == 1 days);
    require(vault.liquidityCoverageRatio() == 2000);
    require(vault.interestFeeBips() == 1000);
    require(vault.feeRecipient() == feeRecipient);
    require(vault.borrower() == borrower);
    require(vault.asset() == address(asset));
    require(vault.controller() == address(controller));
	}
}
