// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { EnumerableSet } from 'openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import './interfaces/WildcatStructsAndEnums.sol';
import './interfaces/IWildcatVaultController.sol';
import './interfaces/IWildcatArchController.sol';
import './libraries/LibStoredInitCode.sol';
import './libraries/MathUtils.sol';
import './market/WildcatMarket.sol';
import './WildcatVaultController.sol';

contract WildcatVaultControllerFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

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
  IWildcatArchController public immutable archController;

  // Returns sentinel used by controller
  address public immutable sentinel;

  address public immutable vaultInitCodeStorage;

  uint256 public immutable vaultInitCodeHash;

  address public immutable controllerInitCodeStorage;

  uint256 public immutable controllerInitCodeHash;

  uint256 internal immutable ownCreate2Prefix = LibStoredInitCode.getCreate2Prefix(address(this));

  uint32 internal immutable MinimumDelinquencyGracePeriod;
  uint32 internal immutable MaximumDelinquencyGracePeriod;

  uint16 internal immutable MinimumReserveRatioBips;
  uint16 internal immutable MaximumReserveRatioBips;

  uint16 internal immutable MinimumDelinquencyFeeBips;
  uint16 internal immutable MaximumDelinquencyFeeBips;

  uint32 internal immutable MinimumWithdrawalBatchDuration;
  uint32 internal immutable MaximumWithdrawalBatchDuration;

  uint16 internal immutable MinimumAnnualInterestBips;
  uint16 internal immutable MaximumAnnualInterestBips;

  ProtocolFeeConfiguration internal _protocolFeeConfiguration;

  EnumerableSet.AddressSet internal _deployedControllers;

  modifier onlyArchControllerOwner() {
    if (msg.sender != archController.owner()) {
      revert CallerNotArchControllerOwner();
    }
    _;
  }

  constructor(
    address _archController,
    address _sentinel,
    VaultParameterConstraints memory constraints
  ) {
    archController = IWildcatArchController(_archController);
    sentinel = _sentinel;
    if (
      constraints.minimumAnnualInterestBips > constraints.maximumAnnualInterestBips ||
      constraints.maximumAnnualInterestBips > 10000 ||
      constraints.minimumDelinquencyFeeBips > constraints.maximumDelinquencyFeeBips ||
      constraints.maximumDelinquencyFeeBips > 10000 ||
      constraints.minimumReserveRatioBips > constraints.maximumReserveRatioBips ||
      constraints.maximumReserveRatioBips > 10000 ||
      constraints.minimumDelinquencyGracePeriod > constraints.maximumDelinquencyGracePeriod ||
      constraints.minimumWithdrawalBatchDuration > constraints.maximumWithdrawalBatchDuration
    ) {
      revert InvalidConstraints();
    }
    MinimumDelinquencyGracePeriod = constraints.minimumDelinquencyGracePeriod;
    MaximumDelinquencyGracePeriod = constraints.maximumDelinquencyGracePeriod;
    MinimumReserveRatioBips = constraints.minimumReserveRatioBips;
    MaximumReserveRatioBips = constraints.maximumReserveRatioBips;
    MinimumDelinquencyFeeBips = constraints.minimumDelinquencyFeeBips;
    MaximumDelinquencyFeeBips = constraints.maximumDelinquencyFeeBips;
    MinimumWithdrawalBatchDuration = constraints.minimumWithdrawalBatchDuration;
    MaximumWithdrawalBatchDuration = constraints.maximumWithdrawalBatchDuration;
    MinimumAnnualInterestBips = constraints.minimumAnnualInterestBips;
    MaximumAnnualInterestBips = constraints.maximumAnnualInterestBips;

    (controllerInitCodeStorage, controllerInitCodeHash) = _storeControllerInitCode();
    (vaultInitCodeStorage, vaultInitCodeHash) = _storeVaultInitCode();
  }

  function _storeControllerInitCode()
    internal
    virtual
    returns (address initCodeStorage, uint256 initCodeHash)
  {
    bytes memory controllerInitCode = type(WildcatVaultController).creationCode;
    initCodeHash = uint256(keccak256(controllerInitCode));
    initCodeStorage = LibStoredInitCode.deployInitCode(controllerInitCode);
  }

  function _storeVaultInitCode()
    internal
    virtual
    returns (address initCodeStorage, uint256 initCodeHash)
  {
    bytes memory vaultInitCode = type(WildcatMarket).creationCode;
    initCodeHash = uint256(keccak256(vaultInitCode));
    initCodeStorage = LibStoredInitCode.deployInitCode(vaultInitCode);
  }

  function isDeployedController(address controller) external view returns (bool) {
    return _deployedControllers.contains(controller);
  }

  function getDeployedControllersCount() external view returns (uint256) {
    return _deployedControllers.length();
  }

  function getDeployedControllers() external view returns (address[] memory) {
    return _deployedControllers.values();
  }

  function getDeployedControllers(
    uint256 start,
    uint256 end
  ) external view returns (address[] memory arr) {
    uint256 len = _deployedControllers.length();
    end = MathUtils.min(end, len);
    uint256 count = end - start;
    arr = new address[](count);
    for (uint256 i = 0; i < count; i++) {
      arr[i] = _deployedControllers.at(start + i);
    }
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
    returns (VaultParameterConstraints memory constraints)
  {
    constraints.minimumDelinquencyGracePeriod = MinimumDelinquencyGracePeriod;
    constraints.maximumDelinquencyGracePeriod = MaximumDelinquencyGracePeriod;
    constraints.minimumReserveRatioBips = MinimumReserveRatioBips;
    constraints.maximumReserveRatioBips = MaximumReserveRatioBips;
    constraints.minimumDelinquencyFeeBips = MinimumDelinquencyFeeBips;
    constraints.maximumDelinquencyFeeBips = MaximumDelinquencyFeeBips;
    constraints.minimumWithdrawalBatchDuration = MinimumWithdrawalBatchDuration;
    constraints.maximumWithdrawalBatchDuration = MaximumWithdrawalBatchDuration;
    constraints.minimumAnnualInterestBips = MinimumAnnualInterestBips;
    constraints.maximumAnnualInterestBips = MaximumAnnualInterestBips;
  }

  /* -------------------------------------------------------------------------- */
  /*                            Controller Deployment                           */
  /* -------------------------------------------------------------------------- */

  address internal _tmpVaultBorrowerParameter = address(1);

  function getVaultControllerParameters()
    external
    view
    virtual
    returns (VaultControllerParameters memory parameters)
  {
    parameters.archController = address(archController);
    parameters.borrower = _tmpVaultBorrowerParameter;
    parameters.sentinel = sentinel;
    parameters.vaultInitCodeStorage = vaultInitCodeStorage;
    parameters.vaultInitCodeHash = vaultInitCodeHash;
    parameters.minimumDelinquencyGracePeriod = MinimumDelinquencyGracePeriod;
    parameters.maximumDelinquencyGracePeriod = MaximumDelinquencyGracePeriod;
    parameters.minimumReserveRatioBips = MinimumReserveRatioBips;
    parameters.maximumReserveRatioBips = MaximumReserveRatioBips;
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
   *      If a controller is already deployed for the borrower, reverts
   *      with `ControllerAlreadyDeployed`.
   *
   *	  If `archController.isRegisteredBorrower(msg.sender)` returns false
   *      reverts with `NotRegisteredBorrower`.
   *
   *      Calls `archController.registerController(controller)` and emits
   *      `NewController(borrower, controller)`.
   */
  function deployController() public returns (address controller) {
    if (!archController.isRegisteredBorrower(msg.sender)) {
      revert NotRegisteredBorrower();
    }
    _tmpVaultBorrowerParameter = msg.sender;
    // Salt is borrower address
    bytes32 salt = bytes32(uint256(uint160(msg.sender)));
    controller = LibStoredInitCode.calculateCreate2Address(
      ownCreate2Prefix,
      salt,
      controllerInitCodeHash
    );
    if (controller.codehash != bytes32(0)) {
      revert ControllerAlreadyDeployed();
    }
    LibStoredInitCode.create2WithStoredInitCode(controllerInitCodeStorage, salt);
    _tmpVaultBorrowerParameter = address(1);
    archController.registerController(controller);
    _deployedControllers.add(controller);
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
    uint16 reserveRatioBips,
    uint32 delinquencyGracePeriod
  ) external returns (address controller, address vault) {
    controller = deployController();
    vault = IWildcatVaultController(controller).deployVault(
      asset,
      namePrefix,
      symbolPrefix,
      maxTotalSupply,
      annualInterestBips,
      delinquencyFeeBips,
      withdrawalBatchDuration,
      reserveRatioBips,
      delinquencyGracePeriod
    );
  }

  function computeControllerAddress(address borrower) external view returns (address) {
    // Salt is borrower address
    bytes32 salt = bytes32(uint256(uint160(borrower)));
    return
      LibStoredInitCode.calculateCreate2Address(ownCreate2Prefix, salt, controllerInitCodeHash);
  }
}
