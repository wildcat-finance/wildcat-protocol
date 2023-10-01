// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { AddressSet } from 'sol-utils/types/EnumerableSet.sol';
import 'solady/utils/SafeTransferLib.sol';
import './market/WildcatMarket.sol';
import './interfaces/IWildcatVaultFactory.sol';
import './interfaces/IWildcatArchController.sol';
import './interfaces/IWildcatVaultControllerFactory.sol';

struct TemporaryLiquidityCoverage {
  uint128 liquidityCoverageRatio;
  uint128 expiry;
}

contract WildcatVaultController {
  using SafeCastLib for uint256;
  using SafeTransferLib for address;

  /* -------------------------------------------------------------------------- */
  /*                                   Errors                                   */
  /* -------------------------------------------------------------------------- */

  error DelinquencyGracePeriodOutOfBounds(uint256 value, uint256 minimum, uint256 maximum);
  error LiquidityCoverageRatioOutOfBounds(uint256 value, uint256 minimum, uint256 maximum);
  error DelinquencyFeeBipsOutOfBounds(uint256 value, uint256 minimum, uint256 maximum);
  error WithdrawalBatchDurationOutOfBounds(uint256 value, uint256 minimum, uint256 maximum);
  error AnnualInterestBipsOutOfBounds(uint256 value, uint256 minimum, uint256 maximum);

  // Error thrown when a borrower-only method is called by another account.
  error CallerNotBorrower();

  // Error thrown when `deployVault` called by an account other than `borrower` or
  // `controllerFactory`.
  error CallerNotBorrowerOrControllerFactory();

  // Error thrown if borrower calls `deployVault` and is no longer
  // registered with the arch-controller.
  error NotRegisteredBorrower();

  error EmptyString();

  /* -------------------------------------------------------------------------- */
  /*                                   Events                                   */
  /* -------------------------------------------------------------------------- */

  event LenderAuthorized(address);

  event LenderDeauthorized(address);

  event VaultDeployed(address indexed vault, address indexed underlying);

  /* -------------------------------------------------------------------------- */
  /*                                 Immutables                                 */
  /* -------------------------------------------------------------------------- */

  IWildcatArchController public immutable archController;

  IWildcatVaultControllerFactory public immutable controllerFactory;

  address public immutable borrower;

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

  error InvalidControllerParameter();
  error DelinquencyFeeTooLow();
  error DelinquencyGracePeriodTooHigh();
  error LiquidityCoverageRatioTooLow();
  error NotControlledVault();
  error CallerNotFactory();
  error ExcessLiquidityCoverageStillActive();

  AddressSet internal _authorizedLenders;
  AddressSet internal _controlledVaults;

  /// @dev temporary storage for vault parameters, used during vault deployment
  VaultParameters internal _tmpVaultParameters;

  mapping(address => TemporaryLiquidityCoverage) public temporaryExcessLiquidityCoverage;

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
    MinimumDelinquencyGracePeriod = parameters.minimumDelinquencyGracePeriod;
    MaximumDelinquencyGracePeriod = parameters.maximumDelinquencyGracePeriod;
    MinimumLiquidityCoverageRatio = parameters.minimumLiquidityCoverageRatio;
    MaximumLiquidityCoverageRatio = parameters.maximumLiquidityCoverageRatio;
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
  ) external view returns (address[] memory) {
    return _authorizedLenders.slice(start, end);
  }

  function getAuthorizedLendersCount() external view returns (uint256) {
    return _authorizedLenders.length();
  }

  function isAuthorizedLender(address lender) external view returns (bool) {
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
  function updateLenderAuthorization(address lender, address[] memory vaults) external {}

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
  ) external view returns (address[] memory) {
    return _controlledVaults.slice(start, end);
  }

  function getControlledVaultsCount() external view returns (uint256) {
    return _controlledVaults.length();
  }

  /**
   * @dev Deploys a new instance of the vault through the vault factory
   *      and registers it with the arch-controller.
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
    string calldata namePrefix,
    string calldata symbolPrefix,
    uint128 maxTotalSupply,
    uint16 annualInterestBips,
    uint16 delinquencyFeeBips,
    uint32 withdrawalBatchDuration,
    uint16 liquidityCoverageRatio,
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
      liquidityCoverageRatio,
      delinquencyGracePeriod
    );

    VaultParameters memory parameters = VaultParameters({
      asset: asset,
      namePrefix: namePrefix,
      symbolPrefix: symbolPrefix,
      borrower: borrower,
      controller: address(this),
      feeRecipient: address(0),
      sentinel: sentinel,
      maxTotalSupply: maxTotalSupply,
      protocolFeeBips: 0,
      annualInterestBips: annualInterestBips,
      delinquencyFeeBips: delinquencyFeeBips,
      withdrawalBatchDuration: withdrawalBatchDuration,
      liquidityCoverageRatio: liquidityCoverageRatio,
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

    if (originationFeeAsset != address(0)) {
      originationFeeAsset.safeTransferFrom(borrower, parameters.feeRecipient, originationFeeAmount);
    }


  }

  function enforceParameterConstraints(
    string calldata namePrefix,
    string calldata symbolPrefix,
    uint16 annualInterestBips,
    uint16 delinquencyFeeBips,
    uint32 withdrawalBatchDuration,
    uint16 liquidityCoverageRatio,
    uint32 delinquencyGracePeriod
  ) internal view {
    assembly {
      if or(iszero(namePrefix.length), iszero(symbolPrefix.length)) {
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
      liquidityCoverageRatio,
      MinimumLiquidityCoverageRatio,
      MaximumLiquidityCoverageRatio,
      LiquidityCoverageRatioOutOfBounds.selector
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
  {
    minimumDelinquencyGracePeriod = MinimumDelinquencyGracePeriod;
    maximumDelinquencyGracePeriod = MaximumDelinquencyGracePeriod;
    minimumLiquidityCoverageRatio = MinimumLiquidityCoverageRatio;
    maximumLiquidityCoverageRatio = MaximumLiquidityCoverageRatio;
    minimumDelinquencyFeeBips = MinimumDelinquencyFeeBips;
    maximumDelinquencyFeeBips = MaximumDelinquencyFeeBips;
    minimumWithdrawalBatchDuration = MinimumWithdrawalBatchDuration;
    maximumWithdrawalBatchDuration = MaximumWithdrawalBatchDuration;
    minimumAnnualInterestBips = MinimumAnnualInterestBips;
    maximumAnnualInterestBips = MaximumAnnualInterestBips;
  }

  /**
   * @dev Modify the interest rate for a vault.
   * If the new interest rate is lower than the current interest rate,
   * the liquidity coverage ratio is set to 90% for the next two weeks.
   */
  function setAnnualInterestBips(
    address vault,
    uint16 annualInterestBips
  ) external virtual onlyBorrower onlyControlledVault(vault) {
    // If borrower is reducing the interest rate, increase the liquidity
    // coverage ratio for the next two weeks.
    if (annualInterestBips < WildcatMarket(vault).annualInterestBips()) {
      TemporaryLiquidityCoverage storage tmp = temporaryExcessLiquidityCoverage[vault];

      if (tmp.expiry == 0) {
        tmp.liquidityCoverageRatio = uint128(WildcatMarket(vault).liquidityCoverageRatio());

        // Require 90% liquidity coverage for the next 2 weeks
        WildcatMarket(vault).setLiquidityCoverageRatio(9000);
      }

      tmp.expiry = uint128(block.timestamp + 2 weeks);
    }

    WildcatMarket(vault).setAnnualInterestBips(annualInterestBips);
  }

  function resetLiquidityCoverage(address vault) external virtual {
    TemporaryLiquidityCoverage memory tmp = temporaryExcessLiquidityCoverage[vault];
    if (block.timestamp < tmp.expiry) {
      revertWithSelector(ExcessLiquidityCoverageStillActive.selector);
    }
    WildcatMarket(vault).setLiquidityCoverageRatio(uint256(tmp.liquidityCoverageRatio).toUint16());
    delete temporaryExcessLiquidityCoverage[vault];
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
        mstore(4, value)
        mstore(36, min)
        mstore(68, max)
        revert(0, 100)
      }
    }
  }
}
