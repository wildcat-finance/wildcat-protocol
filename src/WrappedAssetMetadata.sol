// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './libraries/StringPackerPrefixer.sol';
import './interfaces/IERC20Metadata.sol';

uint256 constant UnknownNameQueryError_selector = 0xed3df7ad00000000000000000000000000000000000000000000000000000000;
uint256 constant UnknownSymbolQueryError_selector = 0x89ff815700000000000000000000000000000000000000000000000000000000;
uint256 constant NameFunction_selector = 0x06fdde0300000000000000000000000000000000000000000000000000000000;
uint256 constant SymbolFunction_selector = 0x95d89b4100000000000000000000000000000000000000000000000000000000;

contract WrappedAssetMetadata is StringPackerPrefixer {
	error UnknownNameQueryError();
	error UnknownSymbolQueryError();

	/*//////////////////////////////////////////////////////////////
                             Immutables
  //////////////////////////////////////////////////////////////*/

	address public immutable asset;

	bytes32 private immutable _packedName;

	bytes32 private immutable _packedSymbol;

	uint8 public immutable decimals;

	constructor(
		string memory namePrefix,
		string memory symbolPrefix,
		address _asset
	) {
		asset = _asset;
		_packedName = _getPackedPrefixedReturnValue(
			namePrefix,
			_asset,
			NameFunction_selector,
			UnknownNameQueryError_selector
		);
		_packedSymbol = _getPackedPrefixedReturnValue(
			symbolPrefix,
			_asset,
			SymbolFunction_selector,
			UnknownSymbolQueryError_selector
		);
		decimals = IERC20Metadata(_asset).decimals();
	}

	function name() public view returns (string memory) {
		return _unpackString(_packedName);
	}

	function symbol() public view returns (string memory) {
		return _unpackString(_packedSymbol);
	}
}
