// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./shared/BaseTest.sol";
import "reference/interfaces/IWildcatVaultFactory.sol";

/* 	address asset;
	string namePrefix;
	string symbolPrefix;
	address owner;
	address controller;
	uint256 maxTotalSupply;
	uint256 annualInterestBips;
	uint256 penaltyFeeBips;
	uint256 gracePeriod;
	uint256 liquidityCoverageRatio;
	uint256 interestFeeBips; */

contract UncollateralizedDebtTokenTest is BaseTest {
  VaultParameters public getVaultParameters;

  function setUp() public virtual override {
    super.setUp();

  }

  function setVaultParameters(VaultParameters memory parameters) external  {
    getVaultParameters = parameters;
  }

  function _deployVault(FuzzContext memory input) internal {
    getVaultParameters = VaultParameters({
      asset: address(baseToken),
      namePrefix: "Wildcat ",
      symbolPrefix: "WC",
      borrower: address(this),
      controller: address(0),
      maxTotalSupply: input.state.maxTotalSupply,
      annualInterestBips: input.state.annualInterestBips,
      penaltyFeeBips: input.penaltyFeeBips,
      gracePeriod: input.gracePeriod,
      liquidityCoverageRatio: input.liquidityCoverageRatio,
      interestFeeBips: input.protocolFeeBips,
      feeRecipient: address(0)
    });
  }
}