// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import 'src/WildcatSanctionsSentinel.sol';
import { SanctionsList } from 'src/libraries/Chainalysis.sol';

import { MockChainalysis } from './MockChainalysis.sol';

contract MockSanctionsSentinel is WildcatSanctionsSentinel {
  constructor(
    address _archController
  ) WildcatSanctionsSentinel(_archController, address(SanctionsList)) {}

  function sanction(address account) external {
    MockChainalysis(chainalysisSanctionsList).sanction(account);
  }
}
