// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { IChainalysisSanctionsList } from './interfaces/IChainalysisSanctionsList.sol';
import { IWildcatArchController } from './interfaces/IWildcatArchController.sol';
import { IWildcatSanctionsSentinel } from './interfaces/IWildcatSanctionsSentinel.sol';
import { SanctionsList } from './libraries/Chainalysis.sol';
import { WildcatSanctionsEscrow } from './WildcatSanctionsEscrow.sol'; 
import {SphereXProtected} from "@spherex-xyz/contracts/src/SphereXProtected.sol";
 

contract WildcatSanctionsSentinel is IWildcatSanctionsSentinel , SphereXProtected {
  bytes32 public constant override WildcatSanctionsEscrowInitcodeHash =
    keccak256(type(WildcatSanctionsEscrow).creationCode);

  address public immutable override chainalysisSanctionsList;

  address public immutable override archController;

  TmpEscrowParams public override tmpEscrowParams;

  mapping(address borrower => mapping(address account => bool sanctionOverride))
    public
    override sanctionOverrides;

  constructor(address _archController, address _chainalysisSanctionsList) {
    archController = _archController;
    chainalysisSanctionsList = _chainalysisSanctionsList;
    _resetTmpEscrowParams();
  }

  function _resetTmpEscrowParams() internal sphereXGuardInternal(0x5a5545aa) {
    tmpEscrowParams = TmpEscrowParams(address(1), address(1), address(1));
  }

  function isFlaggedByChainalysis(address account) public view returns (bool) {
    return IChainalysisSanctionsList(chainalysisSanctionsList).isSanctioned(account);
  }

  /**
   * @dev Returns boolean indicating whether `account` is sanctioned
   *      on Chainalysis and that status has not been overridden by
   *      `borrower`.
   */
  function isSanctioned(address borrower, address account) public view override returns (bool) {
    return
      !sanctionOverrides[borrower][account] &&
      isFlaggedByChainalysis(account);
  }

  /**
   * @dev Overrides the sanction status of `account` for `borrower`.
   */
  function overrideSanction(address account) public override sphereXGuardPublic(0x7cc6eb71, 0x681909a0) {
    sanctionOverrides[msg.sender][account] = true;
    emit SanctionOverride(msg.sender, account);
  }

  /**
   * @dev Removes the sanction override of `account` for `borrower`.
   */
  function removeSanctionOverride(address account) public override sphereXGuardPublic(0x06340eae, 0x490a8653) {
    sanctionOverrides[msg.sender][account] = false;
    emit SanctionOverrideRemoved(msg.sender, account);
  }

  /**
   * @dev Calculate the create2 escrow address for the combination
   *      of `borrower`, `account`, and `asset`.
   */
  function getEscrowAddress(
    address borrower,
    address account,
    address asset
  ) public view override returns (address escrowAddress) {
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

  /**
   * @dev Creates a new WildcatSanctionsEscrow contract for `borrower`,
   *      `account`, and `asset` or returns the existing escrow contract
   *      if one already exists.
   *
   *      The escrow contract is added to the set of sanction override
   *      addresses for `borrower` so that it can not be blocked.
   */
  function createEscrow(
    address borrower,
    address account,
    address asset
  ) public override sphereXGuardPublic(0x22f014bf, 0xa1054f6b) returns (address escrowContract) {

    escrowContract = getEscrowAddress(borrower, account, asset);

    // Skip creation if the address code size is non-zero
    if (escrowContract.code.length != 0) return escrowContract;

    tmpEscrowParams = TmpEscrowParams(borrower, account, asset);

    new WildcatSanctionsEscrow{ salt: keccak256(abi.encode(borrower, account, asset)) }();

    emit NewSanctionsEscrow(borrower, account, asset);

    sanctionOverrides[borrower][escrowContract] = true;

    emit SanctionOverride(borrower, escrowContract);

    _resetTmpEscrowParams();
  }
}
