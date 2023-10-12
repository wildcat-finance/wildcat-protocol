// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import 'forge-std/Test.sol';
import 'src/WildcatArchController.sol';
import 'src/WildcatVaultControllerFactory.sol';
import { MinimumDelinquencyGracePeriod, MaximumDelinquencyGracePeriod, MinimumReserveRatioBips, MaximumReserveRatioBips, MinimumDelinquencyFeeBips, MaximumDelinquencyFeeBips, MinimumWithdrawalBatchDuration, MaximumWithdrawalBatchDuration, MinimumAnnualInterestBips, MaximumAnnualInterestBips } from './shared/TestConstants.sol';

contract WildcatVaultControllerFactoryTest is Test {
  WildcatArchController internal archController;
  WildcatVaultControllerFactory internal controllerFactory;
  VaultParameterConstraints internal constraints;

  function setUp() external {
    archController = new WildcatArchController();
    _resetConstraints();
    controllerFactory = new WildcatVaultControllerFactory(
      address(archController),
      address(0),
      constraints
    );
  }

  function _resetConstraints() internal {
    constraints = VaultParameterConstraints({
      minimumDelinquencyGracePeriod: MinimumDelinquencyGracePeriod,
      maximumDelinquencyGracePeriod: MaximumDelinquencyGracePeriod,
      minimumReserveRatioBips: MinimumReserveRatioBips,
      maximumReserveRatioBips: MaximumReserveRatioBips,
      minimumDelinquencyFeeBips: MinimumDelinquencyFeeBips,
      maximumDelinquencyFeeBips: MaximumDelinquencyFeeBips,
      minimumWithdrawalBatchDuration: MinimumWithdrawalBatchDuration,
      maximumWithdrawalBatchDuration: MaximumWithdrawalBatchDuration,
      minimumAnnualInterestBips: MinimumAnnualInterestBips,
      maximumAnnualInterestBips: MaximumAnnualInterestBips
    });
  }

  function _expectRevertInvalidConstraints() internal {
    vm.expectRevert(WildcatVaultControllerFactory.InvalidConstraints.selector);
    new WildcatVaultControllerFactory(address(archController), address(0), constraints);
    _resetConstraints();
  }

  function test_InvalidConstraints() external {
    constraints.minimumAnnualInterestBips = constraints.maximumAnnualInterestBips + 1;
    _expectRevertInvalidConstraints();
    constraints.minimumDelinquencyFeeBips = constraints.maximumDelinquencyFeeBips + 1;
    _expectRevertInvalidConstraints();
    constraints.minimumReserveRatioBips = constraints.maximumReserveRatioBips + 1;
    _expectRevertInvalidConstraints();
    constraints.minimumDelinquencyGracePeriod = constraints.maximumDelinquencyGracePeriod + 1;
    _expectRevertInvalidConstraints();
    constraints.minimumWithdrawalBatchDuration = constraints.maximumWithdrawalBatchDuration + 1;
    _expectRevertInvalidConstraints();

    constraints.maximumAnnualInterestBips = 10001;
    _expectRevertInvalidConstraints();
    constraints.maximumDelinquencyFeeBips = 10001;
    _expectRevertInvalidConstraints();
    constraints.maximumReserveRatioBips = 10001;
    _expectRevertInvalidConstraints();
  }

  function test_getVaultControllerParameters() external {
    VaultControllerParameters memory parameters = controllerFactory.getVaultControllerParameters();
    assertEq(parameters.archController, address(archController));
    assertEq(parameters.borrower, address(1), 'borrower');
    assertEq(parameters.sentinel, address(0), 'sentinel');
    assertEq(
      parameters.vaultInitCodeStorage,
      controllerFactory.vaultInitCodeStorage(),
      'vaultInitCodeStorage'
    );
    assertEq(
      parameters.vaultInitCodeHash,
      controllerFactory.vaultInitCodeHash(),
      'vaultInitCodeHash'
    );
    assertEq(parameters.vaultInitCodeHash, uint256(keccak256(type(WildcatMarket).creationCode)));
    assertEq(
      controllerFactory.controllerInitCodeHash(),
      uint256(keccak256(type(WildcatVaultController).creationCode)),
      'controllerInitCodeHash'
    );

    assertEq(
      parameters.minimumDelinquencyGracePeriod,
      MinimumDelinquencyGracePeriod,
      'minimumDelinquencyGracePeriod'
    );
    assertEq(
      parameters.maximumDelinquencyGracePeriod,
      MaximumDelinquencyGracePeriod,
      'maximumDelinquencyGracePeriod'
    );
    assertEq(
      parameters.minimumReserveRatioBips,
      MinimumReserveRatioBips,
      'minimumReserveRatioBips'
    );
    assertEq(
      parameters.maximumReserveRatioBips,
      MaximumReserveRatioBips,
      'maximumReserveRatioBips'
    );
    assertEq(
      parameters.minimumDelinquencyFeeBips,
      MinimumDelinquencyFeeBips,
      'minimumDelinquencyFeeBips'
    );
    assertEq(
      parameters.maximumDelinquencyFeeBips,
      MaximumDelinquencyFeeBips,
      'maximumDelinquencyFeeBips'
    );
    assertEq(
      parameters.minimumWithdrawalBatchDuration,
      MinimumWithdrawalBatchDuration,
      'minimumWithdrawalBatchDuration'
    );
    assertEq(
      parameters.maximumWithdrawalBatchDuration,
      MaximumWithdrawalBatchDuration,
      'maximumWithdrawalBatchDuration'
    );
    assertEq(
      parameters.minimumAnnualInterestBips,
      MinimumAnnualInterestBips,
      'minimumAnnualInterestBips'
    );
    assertEq(
      parameters.maximumAnnualInterestBips,
      MaximumAnnualInterestBips,
      'maximumAnnualInterestBips'
    );
  }
}
