import "./DebtTokenBase.sol";

struct VaultMetaData {
	address asset;
	string name;
	string symbol;
	uint256 decimals;
	address borrower;
	address controller;
	address feeRecipient;
	uint256 interestFeeBips;
	uint256 penaltyFeeBips;
	uint256 gracePeriod;
  uint256 annualInterestBips;
  uint256 liquidityCoverageRatio;
}

struct VaultStatus {
  uint256 maxTotalSupply;
  // uint256 scaledTotalSupply;
  uint256 totalSupply;
  uint256 totalAssets;
  uint256 coverageLiquidity;
  // uint256 scaleFactor;
	uint256 lastAccruedProtocolFees;
  bool isDelinquent;
  uint256 timeDelinquent;
  uint256 lastInterestAccruedTimestamp;
}

contract VaultLens {
  function getVaultMetadata(DebtTokenBase vault) external view returns (VaultMetaData memory metadata) {
    metadata.asset = vault.asset();
    metadata.name = vault.name();
    metadata.symbol = vault.symbol();
    metadata.decimals = vault.decimals();
    metadata.borrower = vault.borrower();
    metadata.controller = vault.controller();
    metadata.feeRecipient = vault.feeRecipient();
    metadata.interestFeeBips = vault.interestFeeBips();
    metadata.penaltyFeeBips = vault.penaltyFeeBips();
    metadata.gracePeriod = vault.gracePeriod();
    metadata.annualInterestBips = vault.annualInterestBips();
    metadata.liquidityCoverageRatio = vault.liquidityCoverageRatio();
  }

  function getVaultStatus(DebtTokenBase vault) external view returns (VaultStatus memory status) {
    (VaultState memory state, uint256 _accruedProtocolFees) = vault.currentState();
    status.maxTotalSupply = vault.maxTotalSupply();
    status.totalSupply = vault.totalSupply();
    status.totalAssets = vault.totalAssets();
    status.coverageLiquidity = vault.coverageLiquidity();
    status.lastAccruedProtocolFees = _accruedProtocolFees;
    status.isDelinquent = state.isDelinquent;
    status.timeDelinquent = state.timeDelinquent;
    status.lastInterestAccruedTimestamp = state.lastInterestAccruedTimestamp;
  }
}
