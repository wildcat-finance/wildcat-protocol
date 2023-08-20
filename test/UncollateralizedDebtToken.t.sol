// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "./shared/BaseTest.sol";
// import "src/interfaces/IWildcatVaultFactory.sol";

// /* 	address asset;
// 	string namePrefix;
// 	string symbolPrefix;
// 	address owner;
// 	address controller;
// 	uint256 maxTotalSupply;
// 	uint256 annualInterestBips;
// 	uint256 delinquencyFeeBips;
// 	uint256 delinquencyGracePeriod;
// 	uint256 liquidityCoverageRatio;
// 	uint256 protocolFeeBips; */

// contract UncollateralizedDebtTokenTest is BaseTest {
//   VaultParameters public getFinalVaultParameters;

//   function setUp() public virtual override {
//     super.setUp();

//   }

//   function setVaultParameters(VaultParameters memory parameters) external  {
//     getFinalVaultParameters = parameters;
//   }

//   function _deployVault(FuzzContext memory input) internal {
//     getFinalVaultParameters = VaultParameters({
//       asset: address(asset),
//       namePrefix: "Wildcat ",
//       symbolPrefix: "WC",
//       borrower: address(this),
//       controller: address(0),
//       maxTotalSupply: input.state.maxTotalSupply,
//       annualInterestBips: input.state.annualInterestBips,
//       delinquencyFeeBips: input.delinquencyFeeBips,
//       delinquencyGracePeriod: input.delinquencyGracePeriod,
//       liquidityCoverageRatio: input.liquidityCoverageRatio,
//       protocolFeeBips: input.protocolFeeBips,
//       feeRecipient: address(0)
//     });
//   }
// }
