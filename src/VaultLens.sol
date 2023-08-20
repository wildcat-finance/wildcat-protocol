// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import './market/WildcatMarket.sol';

// struct VaultMetaData {
// 	address asset;
// 	string name;
// 	string symbol;
// 	uint256 decimals;
// 	address borrower;
// 	address controller;
// 	address feeRecipient;
// 	uint256 protocolFeeBips;
// 	uint256 delinquencyFeeBips;
// 	uint256 delinquencyGracePeriod;
//   uint256 annualInterestBips;
//   uint256 liquidityCoverageRatio;
// }

// struct VaultStatus {
//   uint256 maxTotalSupply;
//   // uint256 scaledTotalSupply;
//   uint256 totalSupply;
//   uint256 totalAssets;
//   uint256 coverageLiquidity;
//   // uint256 scaleFactor;
// 	uint256 lastAccruedProtocolFees;
//   bool isDelinquent;
//   uint256 timeDelinquent;
//   uint256 lastInterestAccruedTimestamp;
// }

// contract VaultLensOld {
//   function getVaultMetadata(WildcatMarket vault) external view returns (VaultMetaData memory metadata) {
//     metadata.asset = vault.asset();
//     metadata.name = vault.name();
//     metadata.symbol = vault.symbol();
//     metadata.decimals = vault.decimals();
//     metadata.borrower = vault.borrower();
//     metadata.controller = vault.controller();
//     metadata.feeRecipient = vault.feeRecipient();
//     metadata.protocolFeeBips = vault.protocolFeeBips();
//     metadata.delinquencyFeeBips = vault.delinquencyFeeBips();
//     metadata.delinquencyGracePeriod = vault.delinquencyGracePeriod();
//     metadata.annualInterestBips = vault.annualInterestBips();
//     metadata.liquidityCoverageRatio = vault.liquidityCoverageRatio();
//   }

//   function getVaultStatus(WildcatMarket vault) external view returns (VaultStatus memory status) {
//     (VaultState memory state, uint256 _accruedProtocolFees) = vault.currentState();
//     status.maxTotalSupply = vault.maxTotalSupply();
//     status.totalSupply = vault.totalSupply();
//     status.totalAssets = vault.totalAssets();
//     status.coverageLiquidity = vault.coverageLiquidity();
//     status.lastAccruedProtocolFees = _accruedProtocolFees;
//     status.isDelinquent = state.isDelinquent;
//     status.timeDelinquent = state.timeDelinquent;
//     status.lastInterestAccruedTimestamp = state.lastInterestAccruedTimestamp;
//   }
// }

struct AccountVaultInfo {
	uint256 scaledBalance;
	uint256 normalizedBalance;
	uint256 underlyingBalance;
	uint256 underlyingApproval;
}

struct ControlStatus {
	bool temporaryLiquidityCoverage;
	uint256 originalLiquidityCoverageRatio;
	uint256 temporaryLiquidityCoverageExpiry;
}

struct TokenMetadata {
	address token;
	string name;
	string symbol;
	uint256 decimals;
}

struct VaultData {
	TokenMetadata vaultToken;
	TokenMetadata underlyingToken;
	address borrower;
	address controller;
	address feeRecipient;
	uint256 interestFeeBips;
	uint256 penaltyFeeBips;
	uint256 gracePeriod;
	uint256 annualInterestBips;
	uint256 liquidityCoverageRatio;
	bool temporaryLiquidityCoverage;
	uint256 originalLiquidityCoverageRatio;
	uint256 temporaryLiquidityCoverageExpiry;
	uint256 borrowableAssets;
	uint256 maxTotalSupply;
	uint256 scaledTotalSupply;
	uint256 totalSupply;
	uint256 totalAssets;
	uint256 coverageLiquidity;
	uint256 scaleFactor;
	uint256 lastAccruedProtocolFees;
	bool isDelinquent;
	uint256 timeDelinquent;
	uint256 lastInterestAccruedTimestamp;
}

contract VaultLens {
	function getAccountVaultInfo(
		WildcatMarket vault,
		address account
	) external view returns (AccountVaultInfo memory info) {}

	function getControlStatus(
		WildcatMarket vault
	) external view returns (ControlStatus memory status) {}

	function getTokenInfo(WildcatMarket token) external view returns (TokenMetadata memory info) {}

	function getVaultData(WildcatMarket vault) external view returns (VaultData memory data) {}

	function getVaultsMetadata(
		address[] calldata vaults
	) external view returns (VaultData[] memory data) {}
}
