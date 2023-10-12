// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { IERC20 } from './interfaces/IERC20.sol';
import { IChainalysisSanctionsList } from './interfaces/IChainalysisSanctionsList.sol';
import { SanctionsList } from './libraries/Chainalysis.sol';
import { WildcatSanctionsSentinel } from './WildcatSanctionsSentinel.sol';
import { IWildcatSanctionsEscrow } from './interfaces/IWildcatSanctionsEscrow.sol';

contract WildcatSanctionsEscrow is IWildcatSanctionsEscrow {
  address public immutable override sentinel;
  address public immutable override borrower;
  address public immutable override account;
  address internal immutable asset;

  constructor() {
    sentinel = msg.sender;
    (borrower, account, asset) = WildcatSanctionsSentinel(sentinel).tmpEscrowParams();
  }

  function balance() public view override returns (uint256) {
    return IERC20(asset).balanceOf(address(this));
  }

  function canReleaseEscrow() public view override returns (bool) {
    return !WildcatSanctionsSentinel(sentinel).isSanctioned(borrower, account);
  }

  function escrowedAsset() public view override returns (address, uint256) {
    return (asset, balance());
  }

  function releaseEscrow() public override {
    if (!canReleaseEscrow()) revert CanNotReleaseEscrow();

    uint256 amount = balance();

    IERC20(asset).transfer(account, amount);

    emit EscrowReleased(account, asset, amount);
  }
}
