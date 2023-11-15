// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IWildcatArchController {
  error NotMarketFactory();

  error NotControllerFactory();

  function owner() external view returns (address);

  /* -------------------------------------------------------------------------- */
  /*                         Controller Factory Registry                        */
  /* -------------------------------------------------------------------------- */

  event ControllerFactoryAdded(address);

  event ControllerFactoryRemoved(address);

  function getRegisteredControllerFactories() external view returns (address[] memory);

  function getRegisteredControllerFactories(
    uint256 start,
    uint256 end
  ) external view returns (address[] memory);

  function getRegisteredControllerFactoriesCount() external view returns (uint256);

  function isRegisteredControllerFactory(address factory) external view returns (bool);

  function registerControllerFactory(address factory) external;

  function removeControllerFactory(address factory) external;

  /* -------------------------------------------------------------------------- */
  /*                             Controller Registry                            */
  /* -------------------------------------------------------------------------- */

  event ControllerAdded(address, address);

  event ControllerRemoved(address);

  function getRegisteredControllers() external view returns (address[] memory);

  function getRegisteredControllers(
    uint256 start,
    uint256 end
  ) external view returns (address[] memory);

  function getRegisteredControllersCount() external view returns (uint256);

  function isRegisteredController(address controller) external view returns (bool);

  function registerController(address controller) external;

  function removeController(address controller) external;

  /* -------------------------------------------------------------------------- */
  /*                             Borrowers Registry                             */
  /* -------------------------------------------------------------------------- */

  event BorrowerAdded(address);

  event BorrowerRemoved(address);

  function getRegisteredBorrowers() external view returns (address[] memory);

  function getRegisteredBorrowers(
    uint256 start,
    uint256 end
  ) external view returns (address[] memory);

  function getRegisteredBorrowersCount() external view returns (uint256);

  function isRegisteredBorrower(address borrower) external view returns (bool);

  function registerBorrower(address borrower) external;

  function removeBorrower(address borrower) external;

  /* -------------------------------------------------------------------------- */
  /*                               Markets Registry                              */
  /* -------------------------------------------------------------------------- */

  event MarketAdded(address, address);

  event MarketRemoved(address);

  function getRegisteredMarkets() external view returns (address[] memory);

  function getRegisteredMarkets(uint256 start, uint256 end) external view returns (address[] memory);

  function getRegisteredMarketsCount() external view returns (uint256);

  function isRegisteredMarket(address market) external view returns (bool);

  function registerMarket(address market) external;

  function removeMarket(address market) external;
}
