// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { EnumerableSet } from 'openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import './Ownable.sol';
import './libraries/MathUtils.sol'; 
import {SphereXProtected} from "@spherex-xyz/contracts/src/SphereXProtected.sol";
 

contract WildcatArchController is Ownable {
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet internal _markets;
  EnumerableSet.AddressSet internal _controllerFactories;
  EnumerableSet.AddressSet internal _borrowers;
  EnumerableSet.AddressSet internal _controllers;

  error NotControllerFactory();
  error NotController();

  error BorrowerAlreadyExists();
  error ControllerFactoryAlreadyExists();
  error ControllerAlreadyExists();
  error MarketAlreadyExists();

  error BorrowerDoesNotExist();
  error ControllerFactoryDoesNotExist();
  error ControllerDoesNotExist();
  error MarketDoesNotExist();

  event MarketAdded(address indexed controller, address market);
  event MarketRemoved(address market);

  event ControllerFactoryAdded(address controllerFactory);
  event ControllerFactoryRemoved(address controllerFactory);

  event BorrowerAdded(address borrower);
  event BorrowerRemoved(address borrower);

  event ControllerAdded(address indexed controllerFactory, address controller);
  event ControllerRemoved(address controller);

  modifier onlyControllerFactory() {
    if (!_controllerFactories.contains(msg.sender)) {
      revert NotControllerFactory();
    }
    _;
  }

  modifier onlyController() {
    if (!_controllers.contains(msg.sender)) {
      revert NotController();
    }
    _;
  }

  constructor() {
    _initializeOwner(msg.sender);
  }

  /* ========================================================================== */
  /*                                  Borrowers                                 */
  /* ========================================================================== */

  function registerBorrower(address borrower) external onlyOwner sphereXGuardExternal(0xb69b9b98) {
    if (!_borrowers.add(borrower)) {
      revert BorrowerAlreadyExists();
    }
    emit BorrowerAdded(borrower);
  }

  function removeBorrower(address borrower) external onlyOwner sphereXGuardExternal(0x399fda11) {
    if (!_borrowers.remove(borrower)) {
      revert BorrowerDoesNotExist();
    }
    emit BorrowerRemoved(borrower);
  }

  function isRegisteredBorrower(address borrower) external view returns (bool) {
    return _borrowers.contains(borrower);
  }

  function getRegisteredBorrowers() external view returns (address[] memory) {
    return _borrowers.values();
  }

  function getRegisteredBorrowers(
    uint256 start,
    uint256 end
  ) external view returns (address[] memory arr) {
    uint256 len = _borrowers.length();
    end = MathUtils.min(end, len);
    uint256 count = end - start;
    arr = new address[](count);
    for (uint256 i = 0; i < count; i++) {
      arr[i] = _borrowers.at(start + i);
    }
  }

  function getRegisteredBorrowersCount() external view returns (uint256) {
    return _borrowers.length();
  }

  /* ========================================================================== */
  /*                            Controller Factories                            */
  /* ========================================================================== */

  function registerControllerFactory(address factory) external onlyOwner sphereXGuardExternal(0xae5cb6bc) {
    if (!_controllerFactories.add(factory)) {
      revert ControllerFactoryAlreadyExists();
    }
    emit ControllerFactoryAdded(factory);
  }

  function removeControllerFactory(address factory) external onlyOwner sphereXGuardExternal(0x747aaceb) {
    if (!_controllerFactories.remove(factory)) {
      revert ControllerFactoryDoesNotExist();
    }
    emit ControllerFactoryRemoved(factory);
  }

  function isRegisteredControllerFactory(address factory) external view returns (bool) {
    return _controllerFactories.contains(factory);
  }

  function getRegisteredControllerFactories() external view returns (address[] memory) {
    return _controllerFactories.values();
  }

  function getRegisteredControllerFactories(
    uint256 start,
    uint256 end
  ) external view returns (address[] memory arr) {
    uint256 len = _controllerFactories.length();
    end = MathUtils.min(end, len);
    uint256 count = end - start;
    arr = new address[](count);
    for (uint256 i = 0; i < count; i++) {
      arr[i] = _controllerFactories.at(start + i);
    }
  }

  function getRegisteredControllerFactoriesCount() external view returns (uint256) {
    return _controllerFactories.length();
  }

  /* ========================================================================== */
  /*                                 Controllers                                */
  /* ========================================================================== */

  function registerController(address controller) external onlyControllerFactory sphereXGuardExternal(0x932152bd) {
    if (!_controllers.add(controller)) {
      revert ControllerAlreadyExists();
    }
    emit ControllerAdded(msg.sender, controller);
  }

  function removeController(address controller) external onlyOwner sphereXGuardExternal(0x7be05ec0) {
    if (!_controllers.remove(controller)) {
      revert ControllerDoesNotExist();
    }
    emit ControllerRemoved(controller);
  }

  function isRegisteredController(address controller) external view returns (bool) {
    return _controllers.contains(controller);
  }

  function getRegisteredControllers() external view returns (address[] memory) {
    return _controllers.values();
  }

  function getRegisteredControllers(
    uint256 start,
    uint256 end
  ) external view returns (address[] memory arr) {
    uint256 len = _controllers.length();
    end = MathUtils.min(end, len);
    uint256 count = end - start;
    arr = new address[](count);
    for (uint256 i = 0; i < count; i++) {
      arr[i] = _controllers.at(start + i);
    }
  }

  function getRegisteredControllersCount() external view returns (uint256) {
    return _controllers.length();
  }

  /* ========================================================================== */
  /*                                   Markets                                   */
  /* ========================================================================== */

  function registerMarket(address market) external onlyController sphereXGuardExternal(0xbea93bd1) {
    if (!_markets.add(market)) {
      revert MarketAlreadyExists();
    }
    emit MarketAdded(msg.sender, market);
  }

  function removeMarket(address market) external onlyOwner sphereXGuardExternal(0x640a3700) {
    if (!_markets.remove(market)) {
      revert MarketDoesNotExist();
    }
    emit MarketRemoved(market);
  }

  function isRegisteredMarket(address market) external view returns (bool) {
    return _markets.contains(market);
  }

  function getRegisteredMarkets() external view returns (address[] memory) {
    return _markets.values();
  }

  function getRegisteredMarkets(
    uint256 start,
    uint256 end
  ) external view returns (address[] memory arr) {
    uint256 len = _markets.length();
    end = MathUtils.min(end, len);
    uint256 count = end - start;
    arr = new address[](count);
    for (uint256 i = 0; i < count; i++) {
      arr[i] = _markets.at(start + i);
    }
  }

  function getRegisteredMarketsCount() external view returns (uint256) {
    return _markets.length();
  }
}
