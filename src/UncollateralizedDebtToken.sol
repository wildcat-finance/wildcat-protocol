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

  error NotOwner();
	error NewMaxSupplyTooLow();

	event MaxSupplyUpdated(uint256 assets);

	uint256 public immutable collateralizationRatio;

	Configuration internal _configuration;

  /*//////////////////////////////////////////////////////////////
                              Modifiers
  //////////////////////////////////////////////////////////////*/

  modifier onlyOwner {
    if (msg.sender != owner()) revert NotOwner();
    _;
  }

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

	function owner() public view returns (address) {
		return _configuration.getOwner();
	}

	// TODO: how should the maximum capacity be represented here? flat amount of base asset? inflated per scale factor?
	/**
	 * @dev Sets the maximum total supply - this only limits deposits and does not affect interest accrual.
	 */
	function setMaxTotalSupply(uint256 _maxTotalSupply) external onlyOwner {
    // Ensure new maxTotalSupply is not less than current totalSupply
		if (_maxTotalSupply < totalSupply()) {
			revert NewMaxSupplyTooLow();
		}
    // Store new configuration with updated maxTotalSupply
		_configuration = _configuration.setMaxTotalSupply(_maxTotalSupply);
		emit MaxSupplyUpdated(_maxTotalSupply);
	}

  /*//////////////////////////////////////////////////////////////
                             Mint & Burn
  //////////////////////////////////////////////////////////////*/

  function depositUpTo(uint256 amount, address user) external virtual returns (uint256 actualAmount) {
		actualAmount = ScaledBalanceToken._mintUpTo(user, amount);
	}

	function deposit(uint256 amount, address user) external virtual {
		_mint(user, amount);
	}

	function withdraw(uint256 amount, address user) external virtual {
		_burn(user, amount);
	}

  /*//////////////////////////////////////////////////////////////
                      Abstract Parent Overrides
  //////////////////////////////////////////////////////////////*/

  // Tells ERC2612 to use ScaledBalanceToken's _approve function
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
