// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

enum AuthRole {  UnknownMember1, UnknownMember2  }

struct VaultState {
  uint128 maxTotalSupply;
  uint104 scaledTotalSupply;
  bool isDelinquent;
  uint16 annualInterestBips;
  uint16 liquidityCoverageRatio;
  uint32 timeDelinquent;
  uint112 scaleFactor;
  uint32 lastInterestAccruedTimestamp;
}

interface IWildcatVaultToken {
  error AccountBlacklisted ();

  error BadLaunchCode ();

  error BorrowAmountTooHigh ();

  error FeeSetWithoutRecipient ();

  error InsufficientCoverageForFeeWithdrawal ();

  error InterestFeeTooHigh ();

  error InterestRateTooHigh ();

  error LiquidityCoverageRatioTooHigh ();

  error MaxSupplyExceeded ();

  error NewMaxSupplyTooLow ();

  error NoReentrantCalls ();

  error NotApprovedBorrower ();

  error NotApprovedLender ();

  error NotController ();

  error PenaltyFeeTooHigh ();

  error UnknownNameQueryError ();

  error UnknownSymbolQueryError ();

  event AnnualInterestBipsUpdated (uint256);

  event Approval (address,address,uint256);

  event AuthorizationStatusUpdated (address,AuthRole);

  event Borrow (uint256);

  event Deposit (address,uint256,uint256);

  event FeesCollected (uint256);

  event LiquidityCoverageRatioUpdated (uint256);

  event MaxSupplyUpdated (uint256);

  event StateUpdated (uint256,bool);

  event Transfer (address,address,uint256);

  event VaultClosed (uint256);

  event Withdrawal (address,uint256,uint256);

  function accruedProtocolFees () external view returns (uint256 _accruedProtocolFees);

  function allowance (address, address) external view returns (uint256);

  function annualInterestBips () external view returns (uint256);

  function approve (address spender, uint256 amount) external returns (bool);

  function asset () external view returns (address);

  function balanceOf (address account) external view returns (uint256);

  function borrow (uint256 amount) external;

  function borrowableAssets () external view returns (uint256);

  function borrower () external view returns (address);

  function closeVault () external;

  function collectFees () external;

  function controller () external view returns (address);

  function coverageLiquidity () external view returns (uint256);

  function currentState () external view returns (VaultState memory state, uint256 _accruedProtocolFees);

  function decimals () external view returns (uint8);

  function deposit (uint256 amount) external;

  function depositUpTo (uint256 amount) external returns (uint256);

  function feeRecipient () external view returns (address);

  function delinquencyGracePeriod () external view returns (uint256);

  function grantAccountAuthorization (address _account) external;

  function protocolFeeBips () external view returns (uint256);

  function lastAccruedProtocolFees () external view returns (uint256);

  function liquidityCoverageRatio () external view returns (uint256);

  function maxTotalSupply () external view returns (uint256);

  function maximumDeposit () external view returns (uint256);

  function name () external view returns (string memory);

  function nukeFromOrbit (address _account) external;

  function delinquencyFeeBips () external view returns (uint256);

  function previousState () external view returns (VaultState memory);

  function revokeAccountAuthorization (address _account) external;

  function scaleFactor () external view returns (uint256);

  function sentinel () external view returns (address);

  function setAnnualInterestBips (uint256 _annualInterestBips) external;

  function setLiquidityCoverageRatio (uint256 _liquidityCoverageRatio) external;

  function setMaxTotalSupply (uint256 _maxTotalSupply) external;

  function symbol () external view returns (string memory);

  function totalAssets () external view returns (uint256);

  function totalSupply () external view returns (uint256);

  function transferFrom (address from, address to, uint256 amount) external returns (bool);

  function withdraw (uint256 amount) external;
}