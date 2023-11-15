// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { IERC20 } from './interfaces/IERC20.sol';
import { IChainalysisSanctionsList } from './interfaces/IChainalysisSanctionsList.sol';
import { SanctionsList } from './libraries/Chainalysis.sol';
import { WildcatSanctionsSentinel } from './WildcatSanctionsSentinel.sol';
import { IWildcatSanctionsEscrow } from './interfaces/IWildcatSanctionsEscrow.sol';
import 'solady/utils/SafeTransferLib.sol'; 
import {SphereXProtected} from "@spherex-xyz/contracts/src/SphereXProtected.sol";
 


contract WildcatSanctionsEscrow is IWildcatSanctionsEscrow , SphereXProtected {
  using SafeTransferLib for address;

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

  function releaseEscrow() public override sphereXGuardPublic(0x976b4ad1, 0x757a5543) {
    if (!canReleaseEscrow()) revert CanNotReleaseEscrow();

    uint256 amount = balance();
    address _account = account;
    address _asset = asset;

    asset.safeTransfer(_account, amount);

    emit EscrowReleased(_account, _asset, amount);
  }
}
