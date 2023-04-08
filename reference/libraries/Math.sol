// // SPDX-License-Identifier: MIT
// pragma solidity >=0.8.17;

// uint256 constant BIP = 1e4;
// uint256 constant OneEth = 1e18;
// uint256 constant RAY = 1e26;
// uint256 constant RayBipsNumerator = 1e22;
// uint256 constant SecondsIn365Days = 31536000;

// library Math {
// 	error InvalidNullValue();

// 	function bipsMul(uint256 x, uint256 y) internal pure returns (uint256 z) {
// 		z = (x * y) / BIP;
// 	}

// 	// function annualBipsToRayPerSecond(
// 	// 	uint256 annualBips
// 	// ) internal pure returns (uint256 rayPerSecond) {
// 	// 	assembly {
// 	// 		// Convert annual bips to fraction of 1e26 - (bips * 1e22) / 31536000
// 	// 		// Multiply by 1e22 = multiply by 1e26 and divide by 10000
// 	// 		rayPerSecond := div(mul(annualBips, RayBipsNumerator), SecondsIn365Days)
// 	// 	}
// 	// }

// 	function lowestBitSet(uint256 self) internal pure returns (uint256 _z) {
// 		if (self == 0) {
// 			revert InvalidNullValue();
// 		}
// 		uint256 _magic = 0x00818283848586878898a8b8c8d8e8f929395969799a9b9d9e9faaeb6bedeeff;
// 		uint256 val;
// 		assembly {
// 			val := shr(248, mul(and(self, sub(0, self)), _magic))
// 		}
// 		uint256 _y = val >> 5;

// 		_z = (
// 			_y < 4
// 				? _y < 2
// 					? ternary(
//             _y == 0,
//             0x753a6d1b65325d0c552a4d1345224105391a310b29122104190a110309020100,
//             0xc976c13bb96e881cb166a933a55e490d9d56952b8d4e801485467d2362422606
//           )
// 					: ternary(
//             _y == 2,
//             0xe39ed557db96902cd38ed14fad815115c786af479b7e83247363534337271707,
//             0xf7cae577eec2a03cf3bad76fb589591debb2dd67e0aa9834bea6925f6a4a2e0e
//           )
// 				: _y < 6
// 				? ternary(_y == 4, 0xc8c0b887b0a8a4489c948c7f847c6125746c645c544c444038302820181008ff, 0xf6e4ed9ff2d6b458eadcdf97bd91692de2d4da8fd2d0ac50c6ae9a8272523616)
// 				: ternary(_y == 6, 0xf5ecf1b3e9debc68e1d9cfabc5997135bfb7a7a3938b7b606b5b4b3f2f1f0ffe, 0xf8f9cbfae6cc78fbefe7cdc3a1793dfcf4f0e8bbd8cec470b6a28a7a5a3e1efd)
// 		);
//     assembly {
//         // _z = (_z >> (val & 0x1f) << 3) & 0xff;
//        _z := and(shr(shl(3, and(val, 0x1f)), _z), 0xff)
//     }
// 		return _z & 0xff;
// 	}
// }
