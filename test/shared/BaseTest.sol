// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import { FeeMath, MathUtils, SafeCastLib, VaultState, HALF_RAY, RAY } from 'reference/libraries/FeeMath.sol';
import 'forge-std/Test.sol';
import 'forge-std/console2.sol';
import 'forge-std/StdError.sol';
import 'solmate/test/utils/mocks/MockERC20.sol';

// scaleFactor = 112 bits
// RAY = 89 bits
// so, rayMul by scaleFactor can grow by 23 bits
// if maxTotalSupply is 128 bits, scaledTotalSupply should be 104 bits
struct StateFuzzInputs {
	// Maximum allowed token supply
	uint128 maxTotalSupply;
	// Scaled token supply (divided by scaleFactor)
	uint104 scaledTotalSupply;
	// Whether vault is currently delinquent (liquidity under requirement)
	bool isDelinquent;
	// Seconds in delinquency status
	uint32 timeDelinquent;
	// Max APR is ~655%
	uint16 annualInterestBips;
	// Max scale factor is ~52m
	uint112 scaleFactor;
	// Last time vault accrued interest
	uint32 lastInterestAccruedTimestamp;
}

struct FuzzInput {
	StateFuzzInputs state;
	uint256 liquidityCoverageRatio;
	uint256 protocolFeeBips;
	uint256 delinquencyFeeBips;
	uint256 delinquencyGracePeriod;
	uint256 timeDelta;
}

struct FuzzContext {
	VaultState state;
	uint256 liquidityCoverageRatio;
	uint256 protocolFeeBips;
	uint256 delinquencyFeeBips;
	uint256 delinquencyGracePeriod;
	uint256 timeDelta;
}

contract BaseTest is Test {
	using MathUtils for uint256;
	using SafeCastLib for uint256;

	MockERC20 internal baseToken;
	string internal constant baseName = 'TestToken';
	string internal constant baseSymbol = 'TST';
	uint8 internal constant baseDecimals = 18;

	function setUp() public virtual {
		baseToken = new MockERC20(baseName, baseSymbol, baseDecimals);
	}

	function maxRayMulRhs(uint256 left) internal pure returns (uint256 maxRight) {
		if (left == 0) return type(uint256).max;
		maxRight = (type(uint256).max - HALF_RAY) / left;
	}

	function getValidState(
		StateFuzzInputs calldata inputs
	) private view returns (VaultState memory state) {
		state.scaleFactor = bound(inputs.scaleFactor, RAY, type(uint112).max).safeCastTo112();

		state.scaledTotalSupply = bound(
			inputs.scaledTotalSupply,
			uint256(1e18).rayDiv(state.scaleFactor),
			type(uint104).max
		).safeCastTo104();

		state.isDelinquent = inputs.isDelinquent;
		state.maxTotalSupply = bound(
			inputs.maxTotalSupply,
			uint256(state.scaledTotalSupply).rayMul(state.scaleFactor),
			type(uint128).max
		).safeCastTo128();
		state.timeDelinquent = bound(inputs.timeDelinquent, 0, inputs.lastInterestAccruedTimestamp)
			.safeCastTo32();
		state.annualInterestBips = bound(inputs.annualInterestBips, 1, 1e4).safeCastTo16();
		// state.lastInterestAccruedTimestamp = bound(inputs.lastInterestAccruedTimestamp, 1, block.timestamp - 10).safeCastTo32();
	}

	function getFuzzContext(FuzzInput calldata input) internal returns (FuzzContext memory context) {
		context.state = getValidState(input.state);
		context.liquidityCoverageRatio = bound(input.liquidityCoverageRatio, 1, 1e4).safeCastTo16();
		context.protocolFeeBips = bound(input.protocolFeeBips, 1, 1e4).safeCastTo16();
		context.delinquencyFeeBips = bound(input.delinquencyFeeBips, 1, 1e4).safeCastTo16();
		context.delinquencyGracePeriod = input.delinquencyGracePeriod;
		context.timeDelta = bound(input.timeDelta, 0, type(uint32).max);
		uint256 currentBlockTime = bound(block.timestamp, context.timeDelta, type(uint32).max);
		vm.warp(currentBlockTime);
		context.state.lastInterestAccruedTimestamp = uint32(currentBlockTime - context.timeDelta);
	}
}
