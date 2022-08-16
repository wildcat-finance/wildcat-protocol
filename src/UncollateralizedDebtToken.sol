// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./WrappedAssetMetadata.sol";
import "./ScaledBalanceToken.sol";
import { Configuration, ConfigurationCoder } from "./types/ConfigurationCoder.sol";
import "./libraries/SafeTransferLib.sol";

contract UncollateralizedDebtToken is ScaledBalanceToken, WrappedAssetMetadata {
  using ConfigurationCoder for Configuration;
  using SafeTransferLib for address;

  uint256 public immutable collateralizationRatio;

  Configuration internal _configuration;

  constructor(
    address _asset,
    string memory namePrefix,
    string memory symbolPrefix,
    address _owner,
    uint256 _maximumCapacity,
    uint256 _collateralizationRatio,
    int256  _annualInterestBips
  ) WrappedAssetMetadata(namePrefix, symbolPrefix, _asset) ScaledBalanceToken(_annualInterestBips) {
    collateralizationRatio = _collateralizationRatio;
    _configuration = ConfigurationCoder.encode(_owner, _maximumCapacity);
  }

  function owner() external view returns (address) {
    return _configuration.getOwner();
  }

  function maxTotalSupply() public view virtual override returns (uint256) {
    return _configuration.getMaxTotalSupply();
  }

  function _handleDeposit(
    address to,
    uint256 amount,
    uint256
  ) internal virtual override {
    asset.safeTransferFrom(msg.sender, to, amount);
  }

  function _setMaxTotalSupply(uint256 _maxTotalSupply) internal {
      require(_maxTotalSupply >= totalSupply(), "Cannot reduce max supply below outstanding");
      _configuration = _configuration.setMaxTotalSupply(_maxTotalSupply);
  }
}