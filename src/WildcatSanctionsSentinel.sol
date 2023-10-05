// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { IChainalysisSanctionsList } from './interfaces/IChainalysisSanctionsList.sol';
import { SanctionsList } from './libraries/Chainalysis.sol';
import { WildcatSanctionsEscrow } from './WildcatSanctionsEscrow.sol';

// -- TEMP START --
interface IWildcatArchController {
  function isRegisteredVault(address) external view returns (bool);
}

// -- TEMP END --

contract WildcatSanctionsSentinel {
  event NewSanctionsEscrow(
    address indexed borrower,
    address indexed account,
    address indexed asset
  );

  error NotRegisteredVault();

  struct TmpVaultParams {
    address borrower;
    address account;
    address asset;
  }

  bytes32 public constant WildcatSanctionsEscrowInitcodeHash =
    keccak256(type(WildcatSanctionsEscrow).creationCode);

  IChainalysisSanctionsList public constant chainalysisSanctionsList = SanctionsList;

  IWildcatArchController public immutable archController;

  TmpVaultParams public tmpVaultParams;

  constructor(IWildcatArchController _archController) {
    archController = _archController;
    _resetTmpVaultParams();
  }

  function _resetTmpVaultParams() internal {
    tmpVaultParams = TmpVaultParams(address(1), address(1), address(1));
  }

  function isSanctioned(address account) public view returns (bool) {
    return chainalysisSanctionsList.isSanctioned(account);
  }

  function getEscrowAddress(
    address borrower,
    address account,
    address asset
  ) public view returns (address escrowAddress) {
    return
      address(
        uint160(
          uint256(
            keccak256(
              abi.encodePacked(
                bytes1(0xff),
                address(this),
                keccak256(abi.encode(borrower, account, asset)),
                WildcatSanctionsEscrowInitcodeHash
              )
            )
          )
        )
      );
  }

  function createEscrow(
    address borrower,
    address account,
    address asset
  ) public returns (address escrowContract) {
    if (!archController.isRegisteredVault(msg.sender)) revert NotRegisteredVault();

    escrowContract = getEscrowAddress(borrower, account, asset);

    if (escrowContract.codehash != bytes32(0)) return escrowContract;

    tmpVaultParams = TmpVaultParams(borrower, account, asset);

    new WildcatSanctionsEscrow{ salt: keccak256(abi.encode(borrower, account, asset)) }();

    emit NewSanctionsEscrow(borrower, account, asset);
    _resetTmpVaultParams();
  }
}
