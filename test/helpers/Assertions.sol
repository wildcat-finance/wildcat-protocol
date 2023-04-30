pragma solidity ^0.8.17;

import 'reference/libraries/VaultState.sol';
import { StdAssertions } from 'forge-std/StdAssertions.sol';
import { LibString } from 'solady/utils/LibString.sol';

using LibString for uint256;

contract Assertions is StdAssertions {
	function assertEq(
		VaultState memory actual,
		VaultState memory expected,
		string memory key
	) internal {
		assertEq(actual.maxTotalSupply, expected.maxTotalSupply, string.concat(key, '.maxTotalSupply'));
		assertEq(
			actual.scaledTotalSupply,
			expected.scaledTotalSupply,
			string.concat(key, '.scaledTotalSupply')
		);
		assertEq(actual.isDelinquent, expected.isDelinquent, string.concat(key, '.isDelinquent'));
		assertEq(
			actual.annualInterestBips,
			expected.annualInterestBips,
			string.concat(key, '.annualInterestBips')
		);
		assertEq(
			actual.liquidityCoverageRatio,
			expected.liquidityCoverageRatio,
			string.concat(key, '.liquidityCoverageRatio')
		);
		assertEq(actual.timeDelinquent, expected.timeDelinquent, string.concat(key, '.timeDelinquent'));
		assertEq(actual.scaleFactor, expected.scaleFactor, string.concat(key, '.scaleFactor'));
		assertEq(
			actual.lastInterestAccruedTimestamp,
			expected.lastInterestAccruedTimestamp,
			string.concat(key, '.lastInterestAccruedTimestamp')
		);
	}
}
