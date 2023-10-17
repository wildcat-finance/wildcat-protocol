// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

address constant alice = address(0xa11ce);
address constant bob = address(0xb0b);
address constant feeRecipient = address(0xfee);
address constant borrower = address(0xb04405e4);

uint128 constant DefaultMaximumSupply = 100_000e18;
uint16 constant DefaultInterest = 1000;
uint16 constant DefaultDelinquencyFee = 1000;
uint16 constant DefaultReserveRatio = 2000;
uint32 constant DefaultGracePeriod = 2000;
uint16 constant DefaultProtocolFeeBips = 1000;
uint32 constant DefaultWithdrawalBatchDuration = 86400;

uint32 constant MinimumDelinquencyGracePeriod = 0;
uint32 constant MaximumDelinquencyGracePeriod = 86_400;

uint16 constant MinimumReserveRatioBips = 1_000;
uint16 constant MaximumReserveRatioBips = 10_000;

uint16 constant MinimumDelinquencyFeeBips = 1_000;
uint16 constant MaximumDelinquencyFeeBips = 10_000;

uint32 constant MinimumWithdrawalBatchDuration = 0;
uint32 constant MaximumWithdrawalBatchDuration = 365 days;

uint16 constant MinimumAnnualInterestBips = 0;
uint16 constant MaximumAnnualInterestBips = 10_000;
