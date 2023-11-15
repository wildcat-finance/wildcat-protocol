pragma solidity ^0.8.20;

import 'src/libraries/MarketState.sol';
import { StdAssertions } from 'forge-std/StdAssertions.sol';
import { LibString } from 'solady/utils/LibString.sol';

using LibString for uint256;

contract Assertions is StdAssertions {
  function assertEq(
    MarketState memory actual,
    MarketState memory expected,
    string memory key
  ) internal {
    assertEq(actual.maxTotalSupply, expected.maxTotalSupply, string.concat(key, '.maxTotalSupply'));
    assertEq(
      actual.accruedProtocolFees,
      expected.accruedProtocolFees,
      string.concat(key, '.accruedProtocolFees')
    );
    assertEq(
      actual.normalizedUnclaimedWithdrawals,
      expected.normalizedUnclaimedWithdrawals,
      string.concat(key, '.normalizedUnclaimedWithdrawals')
    );
    assertEq(
      actual.scaledTotalSupply,
      expected.scaledTotalSupply,
      string.concat(key, '.scaledTotalSupply')
    );
    assertEq(
      actual.scaledPendingWithdrawals,
      expected.scaledPendingWithdrawals,
      string.concat(key, '.scaledPendingWithdrawals')
    );
    assertEq(
      actual.pendingWithdrawalExpiry,
      expected.pendingWithdrawalExpiry,
      string.concat(key, '.pendingWithdrawalExpiry')
    );
    assertEq(actual.isDelinquent, expected.isDelinquent, string.concat(key, '.isDelinquent'));
    assertEq(actual.timeDelinquent, expected.timeDelinquent, string.concat(key, '.timeDelinquent'));
    assertEq(
      actual.annualInterestBips,
      expected.annualInterestBips,
      string.concat(key, '.annualInterestBips')
    );
    assertEq(
      actual.reserveRatioBips,
      expected.reserveRatioBips,
      string.concat(key, '.reserveRatioBips')
    );
    assertEq(actual.scaleFactor, expected.scaleFactor, string.concat(key, '.scaleFactor'));
    assertEq(
      actual.lastInterestAccruedTimestamp,
      expected.lastInterestAccruedTimestamp,
      string.concat(key, '.lastInterestAccruedTimestamp')
    );
  }

  function assertEq(MarketState memory actual, MarketState memory expected) internal {
    assertEq(actual, expected, 'MarketState');
  }
}
