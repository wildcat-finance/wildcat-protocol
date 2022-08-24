// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './WrappedAssetMetadata.sol';
import './ScaledBalanceToken.sol';
import { Configuration, ConfigurationCoder } from './types/ConfigurationCoder.sol';
import './libraries/SafeTransferLib.sol';
import './ERC2612.sol';

contract UncollateralizedDebtToken is
	ScaledBalanceToken,
	WrappedAssetMetadata,
	ERC2612
{
	using ConfigurationCoder for Configuration;
	using SafeTransferLib for address;

	error NewMaxSupplyTooLow();
	event MaxSupplyUpdated(address vault, uint256 assets);

	uint256 public immutable collateralizationRatio;

	Configuration internal _configuration;

	/*//////////////////////////////////////////////////////////////
                             Constructor
  //////////////////////////////////////////////////////////////*/

	constructor(
		address _asset,
		string memory namePrefix,
		string memory symbolPrefix,
		address _owner,
		uint256 _maximumCapacity,
		uint256 _collateralizationRatio,
		int256 _annualInterestBips
	)
		WrappedAssetMetadata(namePrefix, symbolPrefix, _asset)
		ScaledBalanceToken(_annualInterestBips)
		ERC2612(name(), 'v1')
	{
		collateralizationRatio = _collateralizationRatio;
		_configuration = ConfigurationCoder.encode(_owner, _maximumCapacity);
	}

	function owner() external view returns (address) {
		return _configuration.getOwner();
	}

	function _setMaxTotalSupply(uint256 _maxTotalSupply) internal {
		if (_maxTotalSupply < totalSupply()) {
			revert NewMaxSupplyTooLow();
		}
		_configuration = _configuration.setMaxTotalSupply(_maxTotalSupply);
		emit MaxSupplyUpdated(address(this), _maxTotalSupply);
	}

  /*//////////////////////////////////////////////////////////////
                      Abstract Parent Overrides
  //////////////////////////////////////////////////////////////*/

	function _approve(
		address from,
		address spender,
		uint256 amount
	) internal virtual override(ScaledBalanceToken, ERC2612) {
		ScaledBalanceToken._approve(from, spender, amount);
	}

	function maxTotalSupply() public view virtual override returns (uint256) {
		return _configuration.getMaxTotalSupply();
	}

	function _pullDeposit(uint256 amount) internal virtual override {
		asset.safeTransferFrom(msg.sender, address(this), amount);
	}
}
