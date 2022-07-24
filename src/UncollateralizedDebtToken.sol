// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./WrappedAssetMetadata.sol";
import "./ScaledBalanceToken.sol";
import { Configuration, ConfigurationCoder } from "./types/ConfigurationCoder.sol";
import "./libraries/SafeTransferLib.sol";

contract UncollateralizedDebtToken is ScaledBalanceToken(), WrappedAssetMetadata {
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
    uint256 _collateralizationRatio
  ) WrappedAssetMetadata(namePrefix, symbolPrefix, _asset) {
    collateralizationRatio = _collateralizationRatio;
    _configuration = ConfigurationCoder.encode(_owner, _maximumCapacity);
  }

  function owner() external view returns (address) {
    return _configuration.getOwner();
  }

  function maxTotalSupply() public view virtual override returns (uint256) {
    return _configuration.getMaxTotalSupply();
  }
  function _beforeMint(
    address to,
    uint256 amount,
    uint256
  ) internal virtual override {
    asset.safeTransferFrom(msg.sender, to, amount);
  }
}