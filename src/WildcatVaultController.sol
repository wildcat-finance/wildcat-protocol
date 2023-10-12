// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { EnumerableSet } from 'openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import 'solady/utils/SafeTransferLib.sol';
import './market/WildcatMarket.sol';
import './interfaces/IWildcatArchController.sol';
import './interfaces/IWildcatVaultControllerEventsAndErrors.sol';
import './interfaces/IWildcatVaultControllerFactory.sol';
import './libraries/LibStoredInitCode.sol';
import './libraries/MathUtils.sol';

struct TemporaryReserveRatio {
  uint128 reserveRatioBips;
  uint128 expiry;
}

struct TmpVaultParameterStorage {
  address asset;
  string namePrefix;
  string symbolPrefix;
  address feeRecipient;
  uint16 protocolFeeBips;
  uint128 maxTotalSupply;
  uint16 annualInterestBips;
  uint16 delinquencyFeeBips;
  uint32 withdrawalBatchDuration;
  uint16 reserveRatioBips;
  uint32 delinquencyGracePeriod;
}

contract WildcatVaultController is IWildcatVaultControllerEventsAndErrors {
  using EnumerableSet for EnumerableSet.AddressSet;
  using SafeCastLib for uint256;
  using SafeTransferLib for address;

  /* -------------------------------------------------------------------------- */
  /*                                 Immutables                                 */
  /* -------------------------------------------------------------------------- */

  IWildcatArchController public immutable archController;

  IWildcatVaultControllerFactory public immutable controllerFactory;

  address public immutable borrower;

  address public immutable sentinel;

  address public immutable vaultInitCodeStorage;

  uint256 public immutable vaultInitCodeHash;

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

  EnumerableSet.AddressSet internal _authorizedLenders;
  EnumerableSet.AddressSet internal _controlledVaults;

  /// @dev Temporary storage for vault parameters, used during vault deployment
  TmpVaultParameterStorage internal _tmpVaultParameters;

  mapping(address => TemporaryReserveRatio) public temporaryExcessReserveRatio;

  // VaultParameterConstraints internal immutable constraints

  modifier onlyBorrower() {
    if (msg.sender != borrower) {
      revert CallerNotBorrower();
    }
    _;
  }

  modifier onlyControlledVault(address vault) {
    if (!_controlledVaults.contains(vault)) {
      revert NotControlledVault();
    }
    _;
  }

  constructor() {
    controllerFactory = IWildcatVaultControllerFactory(msg.sender);
    VaultControllerParameters memory parameters = controllerFactory.getVaultControllerParameters();
    archController = IWildcatArchController(parameters.archController);
    borrower = parameters.borrower;
    sentinel = parameters.sentinel;
    vaultInitCodeStorage = parameters.vaultInitCodeStorage;
    vaultInitCodeHash = parameters.vaultInitCodeHash;
    MinimumDelinquencyGracePeriod = parameters.minimumDelinquencyGracePeriod;
    MaximumDelinquencyGracePeriod = parameters.maximumDelinquencyGracePeriod;
    MinimumReserveRatioBips = parameters.minimumReserveRatioBips;
    MaximumReserveRatioBips = parameters.maximumReserveRatioBips;
    MinimumDelinquencyFeeBips = parameters.minimumDelinquencyFeeBips;
    MaximumDelinquencyFeeBips = parameters.maximumDelinquencyFeeBips;
    MinimumWithdrawalBatchDuration = parameters.minimumWithdrawalBatchDuration;
    MaximumWithdrawalBatchDuration = parameters.maximumWithdrawalBatchDuration;
    MinimumAnnualInterestBips = parameters.minimumAnnualInterestBips;
    MaximumAnnualInterestBips = parameters.maximumAnnualInterestBips;
  }

  /* -------------------------------------------------------------------------- */
  /*                               Lender Registry                              */
  /* -------------------------------------------------------------------------- */

  /**
   * @dev Returns the set of authorized lenders.
   */
  function getAuthorizedLenders() external view returns (address[] memory) {
    return _authorizedLenders.values();
  }

  function getAuthorizedLenders(
    uint256 start,
    uint256 end
  ) external view returns (address[] memory arr) {
    uint256 len = _authorizedLenders.length();
    end = MathUtils.min(end, len);
    uint256 count = end - start;
    arr = new address[](count);
    for (uint256 i = 0; i < count; i++) {
      arr[i] = _authorizedLenders.at(start + i);
    }
  }

  function getAuthorizedLendersCount() external view returns (uint256) {
    return _authorizedLenders.length();
  }

  function isAuthorizedLender(address lender) external view virtual returns (bool) {
    return _authorizedLenders.contains(lender);
  }

  /**
   * @dev Grant authorization for a set of lenders.
   *
   *      Note: Only updates the internal set of approved lenders.
   *      Must call `updateLenderAuthorization` to apply changes
   *      to existing vault accounts
   */
  function authorizeLenders(address[] memory lenders) external onlyBorrower {
    for (uint256 i = 0; i < lenders.length; i++) {
      address lender = lenders[i];
      if (_authorizedLenders.add(lender)) {
        emit LenderAuthorized(lender);
      }
    }
  }

  /**
   * @dev Revoke authorization for a set of lenders.
   *
   *      Note: Only updates the internal set of approved lenders.
   *      Must call `updateLenderAuthorization` to apply changes
   *      to existing vault accounts
   */
  function deauthorizeLenders(address[] memory lenders) external onlyBorrower {
    for (uint256 i = 0; i < lenders.length; i++) {
      address lender = lenders[i];
      if (_authorizedLenders.remove(lender)) {
        emit LenderDeauthorized(lender);
      }
    }
  }

  /**
   * @dev Update lender authorization for a set of vaults to the current
   *      status.
   */
  function updateLenderAuthorization(address lender, address[] memory vaults) external {
    for (uint256 i; i < vaults.length; i++) {
      address vault = vaults[i];
      if (!_controlledVaults.contains(vault)) {
        revert NotControlledVault();
      }
      WildcatMarket(vault).updateAccountAuthorization(lender, _authorizedLenders.contains(lender));
    }
  }

  /* -------------------------------------------------------------------------- */
  /*                                Vault Queries                               */
  /* -------------------------------------------------------------------------- */

  function isControlledVault(address vault) external view returns (bool) {
    return _controlledVaults.contains(vault);
  }

  function getControlledVaults() external view returns (address[] memory) {
    return _controlledVaults.values();
  }

  function getControlledVaults(
    uint256 start,
    uint256 end
  ) external view returns (address[] memory arr) {
    uint256 len = _controlledVaults.length();
    end = MathUtils.min(end, len);
    uint256 count = end - start;
    arr = new address[](count);
    for (uint256 i = 0; i < count; i++) {
      arr[i] = _controlledVaults.at(start + i);
    }
  }

  function getControlledVaultsCount() external view returns (uint256) {
    return _controlledVaults.length();
  }

  function computeVaultAddress(
    address asset,
    string memory namePrefix,
    string memory symbolPrefix
  ) external view returns (address) {
    bytes32 salt = _deriveSalt(asset, namePrefix, symbolPrefix);
    return LibStoredInitCode.calculateCreate2Address(ownCreate2Prefix, salt, vaultInitCodeHash);
  }

  /* -------------------------------------------------------------------------- */
  /*                              Vault Deployment                              */
  /* -------------------------------------------------------------------------- */

  /**
   * @dev Get the temporarily stored vault parameters for a vault that is
   *      currently being deployed.
   */
  function getVaultParameters() external view returns (VaultParameters memory parameters) {
    parameters.asset = _tmpVaultParameters.asset;
    parameters.namePrefix = _tmpVaultParameters.namePrefix;
    parameters.symbolPrefix = _tmpVaultParameters.symbolPrefix;
    parameters.borrower = borrower;
    parameters.controller = address(this);
    parameters.feeRecipient = _tmpVaultParameters.feeRecipient;
    parameters.sentinel = sentinel;
    parameters.maxTotalSupply = _tmpVaultParameters.maxTotalSupply;
    parameters.protocolFeeBips = _tmpVaultParameters.protocolFeeBips;
    parameters.annualInterestBips = _tmpVaultParameters.annualInterestBips;
    parameters.delinquencyFeeBips = _tmpVaultParameters.delinquencyFeeBips;
    parameters.withdrawalBatchDuration = _tmpVaultParameters.withdrawalBatchDuration;
    parameters.reserveRatioBips = _tmpVaultParameters.reserveRatioBips;
    parameters.delinquencyGracePeriod = _tmpVaultParameters.delinquencyGracePeriod;
  }

  function _resetTmpVaultParameters() internal {
    _tmpVaultParameters.asset = address(1);
    _tmpVaultParameters.namePrefix = '_';
    _tmpVaultParameters.symbolPrefix = '_';
    _tmpVaultParameters.feeRecipient = address(1);
    _tmpVaultParameters.protocolFeeBips = 1;
    _tmpVaultParameters.maxTotalSupply = 1;
    _tmpVaultParameters.annualInterestBips = 1;
    _tmpVaultParameters.delinquencyFeeBips = 1;
    _tmpVaultParameters.withdrawalBatchDuration = 1;
    _tmpVaultParameters.reserveRatioBips = 1;
    _tmpVaultParameters.delinquencyGracePeriod = 1;
  }

  /**
   * @dev Deploys a create2 deployment of `WildcatMarket` unique to the
   *      combination of `asset, namePrefix, symbolPrefix` and registers
   *      it with the arch-controller.
   *
   *      If a vault has already been deployed with these parameters,
   *      reverts with `VaultAlreadyDeployed`.
   *
   *      If `msg.sender` is not `borrower` or `controllerFactory`,
   *      reverts with `CallerNotBorrowerOrControllerFactory`.
   *
   *	    If `msg.sender == borrower && !archController.isRegisteredBorrower(msg.sender)`,
   *		  reverts with `NotRegisteredBorrower`.
   *
   *      If called by `controllerFactory`, skips borrower check.
   *
   *      If either string is empty, reverts with `EmptyString`.
   *
   *      If `originationFeeAmount` returned by controller factory is not zero,
   *      transfers `originationFeeAmount` of `originationFeeAsset` from
   *      `msg.sender` to `feeRecipient`.
   */
  function deployVault(
    address asset,
    string memory namePrefix,
    string memory symbolPrefix,
    uint128 maxTotalSupply,
    uint16 annualInterestBips,
    uint16 delinquencyFeeBips,
    uint32 withdrawalBatchDuration,
    uint16 reserveRatioBips,
    uint32 delinquencyGracePeriod
  ) external returns (address vault) {
    if (msg.sender == borrower) {
      if (!archController.isRegisteredBorrower(msg.sender)) {
        revert NotRegisteredBorrower();
      }
    } else if (msg.sender != address(controllerFactory)) {
      revert CallerNotBorrowerOrControllerFactory();
    }

    enforceParameterConstraints(
      namePrefix,
      symbolPrefix,
      annualInterestBips,
      delinquencyFeeBips,
      withdrawalBatchDuration,
      reserveRatioBips,
      delinquencyGracePeriod
    );

    TmpVaultParameterStorage memory parameters = TmpVaultParameterStorage({
      asset: asset,
      namePrefix: namePrefix,
      symbolPrefix: symbolPrefix,
      feeRecipient: address(0),
      maxTotalSupply: maxTotalSupply,
      protocolFeeBips: 0,
      annualInterestBips: annualInterestBips,
      delinquencyFeeBips: delinquencyFeeBips,
      withdrawalBatchDuration: withdrawalBatchDuration,
      reserveRatioBips: reserveRatioBips,
      delinquencyGracePeriod: delinquencyGracePeriod
    });

    address originationFeeAsset;
    uint80 originationFeeAmount;
    (
      parameters.feeRecipient,
      originationFeeAsset,
      originationFeeAmount,
      parameters.protocolFeeBips
    ) = controllerFactory.getProtocolFeeConfiguration();

    _tmpVaultParameters = parameters;

    if (originationFeeAsset != address(0)) {
      originationFeeAsset.safeTransferFrom(borrower, parameters.feeRecipient, originationFeeAmount);
    }

    bytes32 salt = _deriveSalt(asset, namePrefix, symbolPrefix);
    vault = LibStoredInitCode.calculateCreate2Address(ownCreate2Prefix, salt, vaultInitCodeHash);
    if (vault.codehash != bytes32(0)) {
      revert VaultAlreadyDeployed();
    }
    LibStoredInitCode.create2WithStoredInitCode(vaultInitCodeStorage, salt);

    archController.registerVault(vault);
    _controlledVaults.add(vault);

    _resetTmpVaultParameters();
  }

  /**
   * @dev Derive create2 salt for a vault given the asset address,
   *      name prefix and symbol prefix.
   *
   *      The salt is unique to each vault deployment in the controller,
   *      so only one vault can be deployed for each combination of `asset`,
   *      `namePrefix` and `symbolPrefix`
   */
  function _deriveSalt(
    address asset,
    string memory namePrefix,
    string memory symbolPrefix
  ) internal pure returns (bytes32 salt) {
    assembly {
      // Cache free memory pointer
      let freeMemoryPointer := mload(0x40)
      // `keccak256(abi.encode(asset, keccak256(namePrefix), keccak256(symbolPrefix)))`
      mstore(0x00, asset)
      mstore(0x20, keccak256(add(namePrefix, 32), mload(namePrefix)))
      mstore(0x40, keccak256(add(symbolPrefix, 32), mload(symbolPrefix)))
      salt := keccak256(0, 0x60)
      // Restore free memory pointer
      mstore(0x40, freeMemoryPointer)
    }
  }

  /**
   * @dev Enforce constraints on vault parameters, ensuring that
   *      `annualInterestBips`, `delinquencyFeeBips`, `withdrawalBatchDuration`,
   *      `reserveRatioBips` and `delinquencyGracePeriod` are within the
   *      allowed ranges and that `namePrefix` and `symbolPrefix` are not null.
   */
  function enforceParameterConstraints(
    string memory namePrefix,
    string memory symbolPrefix,
    uint16 annualInterestBips,
    uint16 delinquencyFeeBips,
    uint32 withdrawalBatchDuration,
    uint16 reserveRatioBips,
    uint32 delinquencyGracePeriod
  ) internal view virtual {
    assembly {
      if or(iszero(mload(namePrefix)), iszero(mload(symbolPrefix))) {
        // revert EmptyString();
        mstore(0x00, 0xecd7b0d1)
        revert(0x1c, 0x04)
      }
    }
    assertValueInRange(
      annualInterestBips,
      MinimumAnnualInterestBips,
      MaximumAnnualInterestBips,
      AnnualInterestBipsOutOfBounds.selector
    );
    assertValueInRange(
      delinquencyFeeBips,
      MinimumDelinquencyFeeBips,
      MaximumDelinquencyFeeBips,
      DelinquencyFeeBipsOutOfBounds.selector
    );
    assertValueInRange(
      withdrawalBatchDuration,
      MinimumWithdrawalBatchDuration,
      MaximumWithdrawalBatchDuration,
      WithdrawalBatchDurationOutOfBounds.selector
    );
    assertValueInRange(
      reserveRatioBips,
      MinimumReserveRatioBips,
      MaximumReserveRatioBips,
      ReserveRatioBipsOutOfBounds.selector
    );
    assertValueInRange(
      delinquencyGracePeriod,
      MinimumDelinquencyGracePeriod,
      MaximumDelinquencyGracePeriod,
      DelinquencyGracePeriodOutOfBounds.selector
    );
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

  /**
   * @dev Modify the interest rate for a vault.
   * If the new interest rate is lower than the current interest rate,
   * the reserve ratio is set to 90% for the next two weeks.
   */
  function setAnnualInterestBips(
    address vault,
    uint16 annualInterestBips
  ) external virtual onlyBorrower onlyControlledVault(vault) {
    // If borrower is reducing the interest rate, increase the reserve
    // ratio for the next two weeks.
    if (annualInterestBips < WildcatMarket(vault).annualInterestBips()) {
      TemporaryReserveRatio storage tmp = temporaryExcessReserveRatio[vault];

      if (tmp.expiry == 0) {
        tmp.reserveRatioBips = uint128(WildcatMarket(vault).reserveRatioBips());

        // Require 90% liquidity coverage for the next 2 weeks
        WildcatMarket(vault).setReserveRatioBips(9000);
      }

      tmp.expiry = uint128(block.timestamp + 2 weeks);
    }

    WildcatMarket(vault).setAnnualInterestBips(annualInterestBips);
  }

  function resetReserveRatio(address vault) external virtual {
    TemporaryReserveRatio memory tmp = temporaryExcessReserveRatio[vault];
    if (tmp.expiry == 0) {
      revertWithSelector(AprChangeNotPending.selector);
    }
    if (block.timestamp < tmp.expiry) {
      revertWithSelector(ExcessReserveRatioStillActive.selector);
    }

    WildcatMarket(vault).setReserveRatioBips(uint256(tmp.reserveRatioBips).toUint16());
    delete temporaryExcessReserveRatio[vault];
  }

  function assertValueInRange(
    uint256 value,
    uint256 min,
    uint256 max,
    bytes4 errorSelector
  ) internal pure {
    assembly {
      if or(lt(value, min), gt(value, max)) {
        mstore(0, errorSelector)
        revert(0, 4)
      }
    }
  }
}
