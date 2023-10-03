// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import './WildcatStructsAndEnums.sol';

interface IWildcatVaultControllerFactory {
  event NewController(address borrower, address controller, string namePrefix, string symbolPrefix);
  event UpdateProtocolFeeConfiguration(
    address feeRecipient,
    uint16 protocolFeeBips,
    address originationFeeAsset,
    uint256 originationFeeAmount
  );

  error NotRegisteredBorrower();
  error InvalidProtocolFeeConfiguration();
  error CallerNotArchControllerOwner();
  error InvalidConstraints();
  error ControllerAlreadyDeployed();

  // Returns immutable arch-controller
  function archController() external view returns (address);

  // Returns vault factory used by controller
  function vaultFactory() external view returns (address);

  // Returns sentinel used by controller
  function sentinel() external view returns (address);

  /**
   * @dev Returns protocol fee configuration for new vaults.
   *
   *      These can be updated by the arch-controller owner but
   *      `protocolFeeBips` and `feeRecipient` are immutable once
   *      a vault is deployed.
   *
   * @return feeRecipient         feeRecipient to use in new vaults
   * @return originationFeeAsset  Asset used to pay fees for new vault
   *                              deployments
   * @return originationFeeAmount Amount of originationFeeAsset paid
   *                              for new vault deployments
   * @return protocolFeeBips      protocolFeeBips to use in new vaults
   */
  function getProtocolFeeConfiguration()
    external
    view
    returns (
      address feeRecipient,
      address originationFeeAsset,
      uint80 originationFeeAmount,
      uint16 protocolFeeBips
    );

  /**
   * @dev Sets protocol fee configuration for new vault deployments via
   *      controllers deployed by this factory.
   *
   *      If caller is not `archController.owner()`, reverts with
   *      `NotArchControllerOwner`.
   *
   *      Revert with `InvalidProtocolFeeConfiguration` if:
   *      - `protocolFeeBips > 0 && feeRecipient == address(0)`
   *      - OR `originationFeeAmount > 0 && originationFeeAsset == address(0)`
   *      - OR `originationFeeAmount > 0 && feeRecipient == address(0)`
   */
  function setProtocolFeeConfiguration(
    address feeRecipient,
    address originationFeeAsset,
    uint80 originationFeeAmount,
    uint16 protocolFeeBips
  ) external;

  /**
   * @dev Returns immutable constraints on vault parameters that
   *      the controller variant will enforce.
   */
  function getParameterConstraints()
    external
    view
    returns (
      uint32 minimumDelinquencyGracePeriod,
      uint32 maximumDelinquencyGracePeriod,
      uint16 minimumLiquidityCoverageRatio,
      uint16 maximumLiquidityCoverageRatio,
      uint16 minimumDelinquencyFeeBips,
      uint16 maximumDelinquencyFeeBips,
      uint32 minimumWithdrawalBatchDuration,
      uint32 maximumWithdrawalBatchDuration,
      uint16 minimumAnnualInterestBips,
      uint16 maximumAnnualInterestBips
    );

  function getVaultControllerParameters() external view returns (VaultControllerParameters memory);

  /**
   * @dev Deploys a new instance of the wildcat controller variant
   *      with borrower set to `msg.sender` and registers it with
   *      the arch-controller.
   *
   *	    If `archController.isRegisteredBorrower(msg.sender)` returns false
   *      reverts with `NotRegisteredBorrower`.
   *
   *      Calls `archController.registerController(controller)` and emits
   *      `NewController(borrower, controller, namePrefix, symbolPrefix)`.
   *
   *	    If either string is empty, reverts with `EmptyString`.
   */
  function deployController() external returns (address controller);

  /**
   * @dev Deploys a create2 deployment of `WildcatVaultController`
   *      unique to the borrower and registers it with the arch-controller,
   *      then deploys a new vault through the controller.
   *
   *      If a controller is already deployed for the borrower
   *
   *	    If `archController.isRegisteredBorrower(msg.sender)` returns false
   *	    reverts with `NotRegisteredBorrower`.
   *
   *      Calls `archController.registerController(controller)` and emits
   * 	    `NewController(borrower, controller, namePrefix, symbolPrefix)`.
   */
  function deployControllerAndVault(
    string memory namePrefix,
    string memory symbolPrefix,
    address asset,
    uint128 maxTotalSupply,
    uint16 annualInterestBips,
    uint16 delinquencyFeeBips,
    uint32 withdrawalBatchDuration,
    uint16 liquidityCoverageRatio,
    uint32 delinquencyGracePeriod
  ) external returns (address controller, address vault);
}
