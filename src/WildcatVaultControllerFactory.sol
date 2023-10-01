// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import './interfaces/WildcatStructsAndEnums.sol';
import './interfaces/IWildcatArchController.sol';

struct ProtocolFeeConfiguration {
  address feeRecipient;
  address originationFeeAsset;
  uint80 originationFeeAmount;
  uint16 protocolFeeBips;
}

contract WildcatVaultControllerFactory {
  event NewController(address borrower, address controller, string namePrefix, string symbolPrefix);
  event UpdateProtocolFeeConfiguration(
    address feeRecipient,
    uint16 protocolFeeBips,
    address originationFeeAsset,
    uint256 originationFeeAmount
  );

  error EmptyString();
  error NotRegisteredBorrower();
  error InvalidProtocolFeeConfiguration();
  error CallerNotArchControllerOwner();
  error InvalidRange();
  error ControllerAlreadyDeployed();

  // Returns immutable arch-controller
  IWildcatArchController public immutable archController;

  // Returns sentinel used by controller
  address public immutable sentinel;

  uint32 public immutable MinimumDelinquencyGracePeriod;
  uint32 public immutable MaximumDelinquencyGracePeriod;

  uint16 public immutable MinimumLiquidityCoverageRatio;
  uint16 public immutable MaximumLiquidityCoverageRatio;

  uint16 public immutable MinimumDelinquencyFeeBips;
  uint16 public immutable MaximumDelinquencyFeeBips;

  uint32 public immutable MinimumWithdrawalBatchDuration;
  uint32 public immutable MaximumWithdrawalBatchDuration;

  uint16 public immutable MinimumAnnualInterestBips;
  uint16 public immutable MaximumAnnualInterestBips;

  ProtocolFeeConfiguration internal _protocolFeeConfiguration;

  modifier onlyArchControllerOwner() {
    if (msg.sender != archController.owner()) {
      revert CallerNotArchControllerOwner();
    }
    _;
  }

  constructor(
    address _archController,
    address _sentinel,
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
  ) {
    archController = IWildcatArchController(_archController);
    sentinel = _sentinel;
    if (
      minimumAnnualInterestBips > maximumAnnualInterestBips ||
      minimumDelinquencyFeeBips > maximumDelinquencyFeeBips ||
      minimumLiquidityCoverageRatio > maximumLiquidityCoverageRatio ||
      minimumDelinquencyGracePeriod > maximumDelinquencyGracePeriod ||
      minimumWithdrawalBatchDuration > maximumWithdrawalBatchDuration
    ) {
      revert InvalidRange();
    }
    MinimumDelinquencyGracePeriod = minimumDelinquencyGracePeriod;
    MaximumDelinquencyGracePeriod = maximumDelinquencyGracePeriod;
    MinimumLiquidityCoverageRatio = minimumLiquidityCoverageRatio;
    MaximumLiquidityCoverageRatio = maximumLiquidityCoverageRatio;
    MinimumDelinquencyFeeBips = minimumDelinquencyFeeBips;
    MaximumDelinquencyFeeBips = maximumDelinquencyFeeBips;
    MinimumWithdrawalBatchDuration = minimumWithdrawalBatchDuration;
    MaximumWithdrawalBatchDuration = maximumWithdrawalBatchDuration;
    MinimumAnnualInterestBips = minimumAnnualInterestBips;
    MaximumAnnualInterestBips = maximumAnnualInterestBips;
  }

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
    )
  {
    return (
      _protocolFeeConfiguration.feeRecipient,
      _protocolFeeConfiguration.originationFeeAsset,
      _protocolFeeConfiguration.originationFeeAmount,
      _protocolFeeConfiguration.protocolFeeBips
    );
  }

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
  ) external onlyArchControllerOwner {
    bool hasOriginationFee = originationFeeAmount > 0;
    bool nullFeeRecipient = feeRecipient == address(0);
    bool nullOriginationFeeAsset = originationFeeAsset == address(0);
    if (
      (protocolFeeBips > 0 && nullFeeRecipient) ||
      (hasOriginationFee && nullFeeRecipient) ||
      (hasOriginationFee && nullOriginationFeeAsset)
    ) {
      revert InvalidProtocolFeeConfiguration();
    }
    _protocolFeeConfiguration = ProtocolFeeConfiguration({
      feeRecipient: feeRecipient,
      originationFeeAsset: originationFeeAsset,
      originationFeeAmount: originationFeeAmount,
      protocolFeeBips: protocolFeeBips
    });
  }

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
    )
  {}

  address internal _tmpVaultBorrowerParameter = address(1);

  function getVaultControllerParameters()
    external
    view
    returns (VaultControllerParameters memory parameters)
  {
    parameters.archController = address(archController);
    parameters.borrower = _tmpVaultBorrowerParameter;
    parameters.sentinel = sentinel;
    parameters.minimumDelinquencyGracePeriod = MinimumDelinquencyGracePeriod;
    parameters.maximumDelinquencyGracePeriod = MaximumDelinquencyGracePeriod;
    parameters.minimumLiquidityCoverageRatio = MinimumLiquidityCoverageRatio;
    parameters.maximumLiquidityCoverageRatio = MaximumLiquidityCoverageRatio;
    parameters.minimumDelinquencyFeeBips = MinimumDelinquencyFeeBips;
    parameters.maximumDelinquencyFeeBips = MaximumDelinquencyFeeBips;
    parameters.minimumWithdrawalBatchDuration = MinimumWithdrawalBatchDuration;
    parameters.maximumWithdrawalBatchDuration = MaximumWithdrawalBatchDuration;
    parameters.minimumAnnualInterestBips = MinimumAnnualInterestBips;
    parameters.maximumAnnualInterestBips = MaximumAnnualInterestBips;
  }

  /**
   * @dev Deploys a create2 deployment of `WildcatVaultController`
   *      unique to the borrower and registers it with the arch-controller.
   *
   *	  If `archController.isRegisteredBorrower(msg.sender)` returns false
   *      reverts with `NotRegisteredBorrower`.
   *
   *      Calls `archController.registerController(controller)` and emits
   *      `NewController(borrower, controller)`.
   */
  function deployController() external returns (address controller) {
    if (!archController.isRegisteredBorrower(msg.sender)) {
      revert NotRegisteredBorrower();
    }

  }

  /**
   * @dev Deploys a create2 deployment of `WildcatVaultController`
   *      unique to the borrower and registers it with the arch-controller,
   *      then deploys a new vault through the controller.
   *
   *      If a controller is already deployed for the borrower, reverts
   *      with `ControllerAlreadyDeployed`.
   *
   *	  If `archController.isRegisteredBorrower(msg.sender)` returns false
   *	  reverts with `NotRegisteredBorrower`.
   *
   *      Calls `archController.registerController(controller)` and emits
   * 	  `NewController(borrower, controller, namePrefix, symbolPrefix)`.
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
  ) external returns (address controller, address vault) {}
}
