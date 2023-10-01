// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IWildcatArchController {
  error NotVaultFactory();

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
  /*                               Vaults Registry                              */
  /* -------------------------------------------------------------------------- */

  event VaultAdded(address, address);

  event VaultRemoved(address);

  function getRegisteredVaults() external view returns (address[] memory);

  function getRegisteredVaults(uint256 start, uint256 end) external view returns (address[] memory);

  function getRegisteredVaultsCount() external view returns (uint256);

  function isRegisteredVault(address vault) external view returns (bool);

  function registerVault(address vault) external;

  function removeVault(address vault) external;
}
