// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { VaultState } from "../libraries/VaultState.sol";

enum AuthRole {
	Null,
	Blocked,
	WithdrawOnly,
	DepositAndWithdraw
}

struct VaultParameters {
	address asset;
	string namePrefix;
	string symbolPrefix;
	
  address borrower;
	address controller;
  address feeRecipient;
  address sentinel;

	uint256 maxTotalSupply;

	uint256 protocolFeeBips;
	uint256 annualInterestBips;
	uint256 delinquencyFeeBips;

  uint256 withdrawalBatchDuration;
	uint256 liquidityCoverageRatio;
	uint256 delinquencyGracePeriod;
}