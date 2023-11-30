// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20;

import '../WildcatArchController.sol';
import './SliceParameters.sol';

using ArchControllerDataLib for ArchControllerData global;

struct ArchControllerData {
  address archController;
  uint256 borrowersCount;
  address[] borrowers;
  uint256 controllerFactoriesCount;
  address[] controllerFactories;
  uint256 controllersCount;
  address[] controllers;
  uint256 marketsCount;
  address[] markets;
}

library ArchControllerDataLib {
  function fill(
    ArchControllerData memory data,
    WildcatArchController archController,
    SliceParameters memory borrowersSlice,
    SliceParameters memory controllerFactoriesSlice,
    SliceParameters memory controllersSlice,
    SliceParameters memory marketsSlice
  ) internal view {
    data.archController = address(archController);
    data.borrowersCount = archController.getRegisteredBorrowersCount();
    data.borrowers = archController.getRegisteredBorrowers(
      borrowersSlice.start,
      borrowersSlice.end
    );
    data.controllerFactoriesCount = archController.getRegisteredControllerFactoriesCount();
    data.controllerFactories = archController.getRegisteredControllerFactories(
      controllerFactoriesSlice.start,
      controllerFactoriesSlice.end
    );
    data.controllersCount = archController.getRegisteredControllersCount();
    data.controllers = archController.getRegisteredControllers(
      controllersSlice.start,
      controllersSlice.end
    );
    data.marketsCount = archController.getRegisteredMarketsCount();
    data.markets = archController.getRegisteredMarkets(marketsSlice.start, marketsSlice.end);
  }
}
