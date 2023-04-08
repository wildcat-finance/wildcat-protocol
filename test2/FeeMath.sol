// // SPDX-License-Identifier: NONE
// pragma solidity ^0.8.13;

// import 'forge-std/Test.sol';
// import 'forge-std/Vm.sol';

// import 'src/libraries/FeeMath.sol';
// import { VaultState, _calculateInterestAndFees } from 'reference/libraries/FeeMath.sol';

// using Math for uint256;

// contract TestFeeMath is Test {
// 	using stdStorage for StdStorage;

//   struct FeeConfig {
//     uint256 interestFeeBips;
//     uint256 penaltyFeeBips;
//     uint256 gracePeriod;
//   }

//   modifier validateState(VaultState memory state) {
//     vm.assume(state.lastInterestAccruedTimestamp <= block.timestamp);
//     vm.assume(
//       state.scaledTotalSupply.rayMul(state.scaleFactor) < state.maxTotalSupply
//     );
//     _;
//   }

//   modifier validateConfig(FeeConfig memory config) {
//     vm.assume(config.interestFeeBips <= BipsOne);
//     vm.assume(config.penaltyFeeBips <= BipsOne);
//     vm.assume(config.gracePeriod < 1 years);
//   }

// 	function stateToStackParameters(VaultState memory state)
// 		internal
// 		pure
// 		returns (ScaleParameters scaleParameters, VaultSupply vaultSupply)
// 	{
// 		scaleParameters = ScaleParametersCoder.encode(
// 			state.isDelinquent,
// 			state.timeDelinquent,
// 			state.annualInterestBips,
// 			state.scaleFactor,
// 			state.lastInterestAccruedTimestamp
// 		);
// 		vaultSupply = VaultSupplyCoder.encode(
// 			state.maxTotalSupply,
// 			state.scaledTotalSupply
// 		);
// 	}
// }
