// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20;

import '../market/WildcatMarket.sol';
import '../WildcatMarketController.sol';
import '../WildcatArchController.sol';
import '../WildcatMarketControllerFactory.sol';

import './MarketData.sol';

import './TokenData.sol';

using ControllerDataLib for ControllerData global;
using ControllerDataLib for FeeConfiguration global;

struct ControllerData {
  address borrower;
  address controller;
  address controllerFactory;
  bool isRegisteredBorrower;
  bool hasDeployedController;
  FeeConfiguration fees;
  MarketParameterConstraints constraints;
  MarketData[] markets;
  uint256 borrowerOriginationFeeBalance;
  uint256 borrowerOriginationFeeApproval;
}

struct FeeConfiguration {
  address feeRecipient;
  uint16 protocolFeeBips;
  TokenMetadata originationFeeToken;
  uint256 originationFeeAmount;
}

library ControllerDataLib {
  function fill(
    ControllerData memory data,
    WildcatArchController archController,
    WildcatMarketControllerFactory controllerFactory,
    address borrower
  ) internal view {
    data.borrower = borrower;
    data.controller = controllerFactory.computeControllerAddress(borrower);
    data.controllerFactory = address(controllerFactory);
    data.isRegisteredBorrower = archController.isRegisteredBorrower(borrower);
    data.hasDeployedController = data.controller.codehash != 0;
    data.fees.fill(controllerFactory);
    data.constraints = controllerFactory.getParameterConstraints();
    if (data.hasDeployedController) {
      WildcatMarketController controller = WildcatMarketController(data.controller);
      address[] memory markets = controller.getControlledMarkets();
      data.markets = new MarketData[](markets.length);
      for (uint256 i; i < markets.length; i++) {
        data.markets[i].fill(WildcatMarket(markets[i]));
      }
    }
    if (data.fees.originationFeeToken.token != address(0)) {
      IERC20 originationFee = IERC20(data.fees.originationFeeToken.token);
      data.borrowerOriginationFeeBalance = originationFee.balanceOf(borrower);
      data.borrowerOriginationFeeApproval = originationFee.allowance(borrower, data.controller);
    }
  }

  function fill(
    FeeConfiguration memory data,
    WildcatMarketControllerFactory controllerFactory
  ) internal view {
    address originationFeeAsset;
    (
      data.feeRecipient,
      originationFeeAsset,
      data.originationFeeAmount,
      data.protocolFeeBips
    ) = controllerFactory.getProtocolFeeConfiguration();
    data.originationFeeToken.fill(originationFeeAsset);
  }
}
