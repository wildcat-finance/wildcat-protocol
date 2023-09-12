// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { console, console2, StdAssertions, StdChains, StdCheats, stdError, StdInvariant, stdJson, stdMath, StdStorage, stdStorage, StdUtils, Vm, StdStyle, DSTest, Test as ForgeTest } from 'forge-std/Test.sol';
import '../helpers/VmUtils.sol' as VmUtils;
import { deployMockChainalysis } from '../helpers/MockChainalysis.sol';

contract Test is ForgeTest {
	constructor() {
		deployMockChainalysis();
	}

	function bound(
		uint256 value,
		uint256 min,
		uint256 max
	) internal view virtual override returns (uint256 result) {
		return VmUtils.bound(value, min, max);
	}

	function dbound(
		uint256 value1,
		uint256 value2,
		uint256 min,
		uint256 max
	) internal view virtual returns (uint256, uint256) {
		return VmUtils.dbound(value1, value2, min, max);
	}
}
