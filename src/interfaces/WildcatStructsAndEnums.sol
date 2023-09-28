// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { VaultState } from '../libraries/VaultState.sol';

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
  uint128 maxTotalSupply;
  uint16 protocolFeeBips;
  uint16 annualInterestBips;
  uint16 delinquencyFeeBips;
  uint32 withdrawalBatchDuration;
  uint16 liquidityCoverageRatio;
  uint32 delinquencyGracePeriod;
}
