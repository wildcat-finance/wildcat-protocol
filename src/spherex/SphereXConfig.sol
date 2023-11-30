// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import { ISphereXEngine, ModifierLocals } from './ISphereXEngine.sol';
import './SphereXProtectedEvents.sol';
import './SphereXProtectedErrors.sol';

abstract contract SphereXConfig {
  // ========================================================================== //
  //                                Storage Slots                               //
  // ========================================================================== //

  /**
   * @dev we would like to avoid occupying storage slots
   * @dev to easily incorporate with existing contracts
   */
  bytes32 private constant SPHEREX_ADMIN_STORAGE_SLOT =
    bytes32(uint256(keccak256('eip1967.spherex.spherex')) - 1);
  bytes32 private constant SPHEREX_PENDING_ADMIN_STORAGE_SLOT =
    bytes32(uint256(keccak256('eip1967.spherex.pending')) - 1);
  bytes32 private constant SPHEREX_OPERATOR_STORAGE_SLOT =
    bytes32(uint256(keccak256('eip1967.spherex.operator')) - 1);
  bytes32 private constant SPHEREX_ENGINE_STORAGE_SLOT =
    bytes32(uint256(keccak256('eip1967.spherex.spherex_engine')) - 1);

  // ========================================================================== //
  //                                 Constructor                                //
  // ========================================================================== //

  constructor(address admin, address operator, address engine) {
    _setAddress(SPHEREX_ADMIN_STORAGE_SLOT, admin);
    emit_SpherexAdminTransferCompleted(address(0), admin);

    _setAddress(SPHEREX_OPERATOR_STORAGE_SLOT, operator);
    emit_ChangedSpherexOperator(address(0), operator);

    _setSphereXEngine(engine);
    emit_ChangedSpherexEngineAddress(address(0), engine);
  }

  // ========================================================================== //
  //                              Events and Errors                             //
  // ========================================================================== //

  event ChangedSpherexOperator(address oldSphereXAdmin, address newSphereXAdmin);
  event ChangedSpherexEngineAddress(address oldEngineAddress, address newEngineAddress);
  event SpherexAdminTransferStarted(address currentAdmin, address pendingAdmin);
  event SpherexAdminTransferCompleted(address oldAdmin, address newAdmin);
  event NewAllowedSenderOnchain(address sender);

  error SphereXOperatorRequired();
  error SphereXAdminRequired();
  error SphereXOperatorOrAdminRequired();
  error SphereXNotPendingAdmin();
  error SphereXNotEngine();

  // ========================================================================== //
  //                                  Modifiers                                 //
  // ========================================================================== //

  modifier onlySphereXAdmin() {
    if (msg.sender != sphereXAdmin()) {
      revert_SphereXAdminRequired();
    }
    _;
  }

  modifier spherexOnlyOperator() {
    if (msg.sender != sphereXOperator()) {
      revert_SphereXOperatorRequired();
    }
    _;
  }

  modifier spherexOnlyOperatorOrAdmin() {
    if (msg.sender != sphereXOperator() && msg.sender != sphereXAdmin()) {
      revert_SphereXOperatorOrAdminRequired();
    }
    _;
  }

  // ========================================================================== //
  //                               Config Getters                               //
  // ========================================================================== //

  /**
   * Returns the currently pending admin address, the one that can call acceptSphereXAdminRole to become the admin.
   * @dev Could not use OZ Ownable2Step because the client's contract might use it.
   */
  function pendingSphereXAdmin() public view returns (address) {
    return _getAddress(SPHEREX_PENDING_ADMIN_STORAGE_SLOT);
  }

  /**
   * Returns the current admin address, the one that can call acceptSphereXAdminRole to become the admin.
   * @dev Could not use OZ Ownable2Step because the client's contract might use it.
   */
  function sphereXAdmin() public view returns (address) {
    return _getAddress(SPHEREX_ADMIN_STORAGE_SLOT);
  }

  /**
   * Returns the current operator address.
   */
  function sphereXOperator() public view returns (address) {
    return _getAddress(SPHEREX_OPERATOR_STORAGE_SLOT);
  }

  /**
   * @dev Returns the current engine address.
   */
  function sphereXEngine() public view returns (address) {
    return _getAddress(SPHEREX_ENGINE_STORAGE_SLOT);
  }

  // ========================================================================== //
  //                                 Management                                 //
  // ========================================================================== //

  /**
   * @dev Sets the address of the next admin.
   *      This address will have to accept the role to become the new admin.
   */
  function transferSphereXAdminRole(address newAdmin) public virtual onlySphereXAdmin {
    _setAddress(SPHEREX_PENDING_ADMIN_STORAGE_SLOT, newAdmin);
    emit_SpherexAdminTransferStarted(sphereXAdmin(), newAdmin);
  }

  /**
   * @dev Accepting the admin role and completing the transfer.
   * @dev Could not use OZ Ownable2Step because the client's contract might use it.
   */
  function acceptSphereXAdminRole() public virtual {
    if (msg.sender != pendingSphereXAdmin()) {
      revert_SphereXNotPendingAdmin();
    }
    address oldAdmin = sphereXAdmin();
    _setAddress(SPHEREX_ADMIN_STORAGE_SLOT, msg.sender);
    _setAddress(SPHEREX_PENDING_ADMIN_STORAGE_SLOT, address(0));
    emit_SpherexAdminTransferCompleted(oldAdmin, msg.sender);
  }

  /**
   * @param newSphereXOperator new address of the new operator account
   */
  function changeSphereXOperator(address newSphereXOperator) external onlySphereXAdmin {
    address oldSphereXOperator = _getAddress(SPHEREX_OPERATOR_STORAGE_SLOT);
    _setAddress(SPHEREX_OPERATOR_STORAGE_SLOT, newSphereXOperator);
    emit_ChangedSpherexOperator(oldSphereXOperator, newSphereXOperator);
  }

  /**
   *
   * @param newSphereXEngine new address of the spherex engine
   * @dev this is also used to actually enable the defense
   * (because as long is this address is 0, the protection is disabled).
   */
  function changeSphereXEngine(address newSphereXEngine) external spherexOnlyOperator {
    address oldEngine = _getAddress(SPHEREX_ENGINE_STORAGE_SLOT);
    _setSphereXEngine(newSphereXEngine);
    emit_ChangedSpherexEngineAddress(oldEngine, newSphereXEngine);
  }

  /**
   * @dev Checks the given address implements ISphereXEngine or is address(0)
   * @param newSphereXEngine new address of the spherex engine
   */
  function _setSphereXEngine(address newSphereXEngine) internal {
    if (
      newSphereXEngine != address(0) &&
      !ISphereXEngine(newSphereXEngine).supportsInterface(type(ISphereXEngine).interfaceId)
    ) {
      revert_SphereXNotEngine();
    }
    _setAddress(SPHEREX_ENGINE_STORAGE_SLOT, newSphereXEngine);
  }

  // ========================================================================== //
  //                             Engine Interaction                             //
  // ========================================================================== //

  function _addAllowedSenderOnChain(address newSender) internal {
    ISphereXEngine engine = ISphereXEngine(sphereXEngine());
    if (address(engine) != address(0)) {
      engine.addAllowedSenderOnChain(newSender);
    }
    emit_NewAllowedSenderOnchain(newSender);
  }

  // ========================================================================== //
  //                          Internal Storage Helpers                          //
  // ========================================================================== //

  /**
   * Stores a new address in an arbitrary slot
   * @param slot where to store the address
   * @param newAddress address to store in given slot
   */
  function _setAddress(bytes32 slot, address newAddress) internal {
    // solhint-disable-next-line no-inline-assembly
    // slither-disable-next-line assembly
    assembly {
      sstore(slot, newAddress)
    }
  }

  /**
   * Returns an address from an arbitrary slot.
   * @param slot to read an address from
   */
  function _getAddress(bytes32 slot) internal view returns (address addr) {
    // solhint-disable-next-line no-inline-assembly
    // slither-disable-next-line assembly
    assembly {
      addr := sload(slot)
    }
  }
}
