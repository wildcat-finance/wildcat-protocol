// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import 'src/libraries/MathUtils.sol';
import { VaultState } from 'src/libraries/VaultState.sol';
import './TestConstants.sol';

using MathUtils for uint256;

using FuzzInputsLib for ConfigFuzzInputs global;
using FuzzInputsLib for StateFuzzInputs global;

// Used for fuzzing initial state for libraries
struct StateFuzzInputs {
	uint128 maxTotalSupply;
	uint128 accruedProtocolFees;
	uint128 reservedAssets;
	uint104 scaledTotalSupply;
	uint32 pendingWithdrawalExpiry;
	bool isDelinquent;
	uint32 timeDelinquent;
	uint16 annualInterestBips;
	uint16 liquidityCoverageRatio;
	uint112 scaleFactor;
	uint32 lastInterestAccruedTimestamp;
}

// Used for fuzzing vault deployment parameters
struct ConfigFuzzInputs {
	uint128 maxTotalSupply;
	uint16 protocolFeeBips;
	uint16 annualInterestBips;
	uint16 delinquencyFeeBips;
	uint32 withdrawalBatchDuration;
	uint16 liquidityCoverageRatio;
	uint32 delinquencyGracePeriod;
	address feeRecipient;
}

library FuzzInputsLib {
	function constrain(ConfigFuzzInputs memory inputs) internal pure {
		inputs.annualInterestBips = uint16(
			bound(inputs.annualInterestBips, MinimumAnnualInterestBips, MaximumAnnualInterestBips)
		);
		inputs.delinquencyFeeBips = uint16(
			bound(inputs.delinquencyFeeBips, MinimumDelinquencyFeeBips, MaximumDelinquencyFeeBips)
		);
		inputs.withdrawalBatchDuration = uint32(
			bound(
				inputs.withdrawalBatchDuration,
				MinimumWithdrawalBatchDuration,
				MaximumWithdrawalBatchDuration
			)
		);
		inputs.liquidityCoverageRatio = uint16(
			bound(
				inputs.liquidityCoverageRatio,
				MinimumLiquidityCoverageRatio,
				MaximumLiquidityCoverageRatio
			)
		);
		inputs.delinquencyGracePeriod = uint32(
			bound(
				inputs.delinquencyGracePeriod,
				MinimumDelinquencyGracePeriod,
				MaximumDelinquencyGracePeriod
			)
		);
		if (inputs.protocolFeeBips > 0) {
			inputs.feeRecipient = address(
				uint160(bound(uint160(inputs.feeRecipient), 1, type(uint160).max))
			);
		}
	}

	function constrain(StateFuzzInputs memory inputs) internal view {
		inputs.scaleFactor = uint112(bound(inputs.scaleFactor, RAY, type(uint112).max));
		inputs.scaledTotalSupply = uint104(bound(inputs.scaledTotalSupply, 0, type(uint104).max));
		inputs.maxTotalSupply = uint128(
			bound(
				inputs.maxTotalSupply,
				uint256(inputs.scaledTotalSupply).rayMul(inputs.scaleFactor),
				type(uint128).max
			)
		);

		inputs.annualInterestBips = uint16(
			bound(inputs.annualInterestBips, MinimumAnnualInterestBips, MaximumAnnualInterestBips)
		);
		inputs.liquidityCoverageRatio = uint16(
			bound(
				inputs.liquidityCoverageRatio,
				MinimumLiquidityCoverageRatio,
				MaximumLiquidityCoverageRatio
			)
		);
		inputs.lastInterestAccruedTimestamp = uint32(
			bound(inputs.lastInterestAccruedTimestamp, 1, block.timestamp)
		);
		inputs.timeDelinquent = uint32(
			bound(inputs.timeDelinquent, 0, inputs.lastInterestAccruedTimestamp)
		);
	}

	function toState(StateFuzzInputs memory inputs) internal pure returns (VaultState memory state) {
		state.maxTotalSupply = inputs.maxTotalSupply;
		state.accruedProtocolFees = inputs.accruedProtocolFees;
		state.reservedAssets = inputs.reservedAssets;
		state.scaledTotalSupply = inputs.scaledTotalSupply;
		state.pendingWithdrawalExpiry = inputs.pendingWithdrawalExpiry;
		state.isDelinquent = inputs.isDelinquent;
		state.timeDelinquent = inputs.timeDelinquent;
		state.annualInterestBips = inputs.annualInterestBips;
		state.liquidityCoverageRatio = inputs.liquidityCoverageRatio;
		state.scaleFactor = inputs.scaleFactor;
		state.lastInterestAccruedTimestamp = inputs.lastInterestAccruedTimestamp;
	}
}

/// @custom:author Taken from ProjectOpenSea/seaport/test/foundry/new/helpers/FuzzTestContextLib.sol
/// @dev Implementation cribbed from forge-std bound
function bound(uint256 x, uint256 min, uint256 max) pure returns (uint256 result) {
	require(min <= max, 'Max is less than min.');
	// If x is between min and max, return x directly. This is to ensure that
	// dictionary values do not get shifted if the min is nonzero.
	if (x >= min && x <= max) return x;

	uint256 size = max - min + 1;

	// If the value is 0, 1, 2, 3, warp that to min, min+1, min+2, min+3.
	// Similarly for the UINT256_MAX side. This helps ensure coverage of the
	// min/max values.
	if (x <= 3 && size > x) return min + x;
	if (x >= type(uint256).max - 3 && size > type(uint256).max - x)
		return max - (type(uint256).max - x);

	// Otherwise, wrap x into the range [min, max], i.e. the range is inclusive.
	if (x > max) {
		uint256 diff = x - max;
		uint256 rem = diff % size;
		if (rem == 0) return max;
		result = min + rem - 1;
	} else if (x < min) {
		uint256 diff = min - x;
		uint256 rem = diff % size;
		if (rem == 0) return min;
		result = max - rem + 1;
	}
}
