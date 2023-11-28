// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import { ISphereXEngine, ModifierLocals } from './ISphereXEngine.sol';
import './SphereXProtectedEvents.sol';

/**
 * @title SphereX base Customer contract template
 */
abstract contract SphereXProtectedBaseMinimal {
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

  event ChangedSpherexOperator(address oldSphereXAdmin, address newSphereXAdmin);
  event ChangedSpherexEngineAddress(address oldEngineAddress, address newEngineAddress);
  event SpherexAdminTransferStarted(address currentAdmin, address pendingAdmin);
  event SpherexAdminTransferCompleted(address oldAdmin, address newAdmin);
  event NewAllowedSenderOnchain(address sender);

  /**
   * @dev used when the client uses a proxy - should be called by the inhereter initialization
   */
  function __SphereXProtectedBase_init(
    address admin,
    address operator,
    address engine
  ) internal virtual {
    _setAddress(SPHEREX_ADMIN_STORAGE_SLOT, admin);
    emit_SpherexAdminTransferCompleted(address(0), admin);

    _setAddress(SPHEREX_OPERATOR_STORAGE_SLOT, operator);
    emit_ChangedSpherexOperator(address(0), operator);

    _checkSphereXEngine(engine);
    _setAddress(SPHEREX_ENGINE_STORAGE_SLOT, engine);
    emit_ChangedSpherexEngineAddress(address(0), engine);
  }

  // ============ Helper functions ============

  function _sphereXEngine() internal view returns (ISphereXEngine) {
    return ISphereXEngine(_getAddress(SPHEREX_ENGINE_STORAGE_SLOT));
  }

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

  error SphereXOperatorRequired();
  error SphereXAdminRequired();
  error SphereXNotPendingAdmin();
  error SphereXNotEngine();

  // ============ Local modifiers ============

  modifier onlySphereXAdmin() {
    if (msg.sender != _getAddress(SPHEREX_ADMIN_STORAGE_SLOT)) {
      revert SphereXAdminRequired();
    }
    _;
  }

  modifier spherexOnlyOperator() {
    if (msg.sender != _getAddress(SPHEREX_OPERATOR_STORAGE_SLOT)) {
      revert SphereXOperatorRequired();
    }
    _;
  }

  modifier returnsIfNotActivatedPre(ModifierLocals memory locals) {
    locals.engine = address(_sphereXEngine());
    if (locals.engine == address(0)) {
      return;
    }

    _;
  }

  modifier returnsIfNotActivatedPost(ModifierLocals memory locals) {
    if (locals.engine == address(0)) {
      return;
    }

    _;
  }

  // ============ Management ============

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
   * Returns the current engine address.
   */
  function sphereXEngine() public view returns (address) {
    return _getAddress(SPHEREX_ENGINE_STORAGE_SLOT);
  }

  /**
   * Setting the address of the next admin. this address will have to accept the role to become the new admin.
   * @dev Could not use OZ Ownable2Step because the client's contract might use it.
   */
  function transferSphereXAdminRole(address newAdmin) public virtual onlySphereXAdmin {
    _setAddress(SPHEREX_PENDING_ADMIN_STORAGE_SLOT, newAdmin);
    emit_SpherexAdminTransferStarted(sphereXAdmin(), newAdmin);
  }

  /**
   * Accepting the admin role and completing the transfer.
   * @dev Could not use OZ Ownable2Step because the client's contract might use it.
   */
  function acceptSphereXAdminRole() public virtual {
    if (msg.sender != pendingSphereXAdmin()) {
      revert SphereXNotPendingAdmin();
    }
    address oldAdmin = sphereXAdmin();
    _setAddress(SPHEREX_ADMIN_STORAGE_SLOT, msg.sender);
    _setAddress(SPHEREX_PENDING_ADMIN_STORAGE_SLOT, address(0));
    emit_SpherexAdminTransferCompleted(oldAdmin, msg.sender);
  }

  /**
   *
   * @param newSphereXOperator new address of the new operator account
   */
  function changeSphereXOperator(address newSphereXOperator) external onlySphereXAdmin {
    address oldSphereXOperator = _getAddress(SPHEREX_OPERATOR_STORAGE_SLOT);
    _setAddress(SPHEREX_OPERATOR_STORAGE_SLOT, newSphereXOperator);
    emit_ChangedSpherexOperator(oldSphereXOperator, newSphereXOperator);
  }

  /**
   * Checks the given address implements ISphereXEngine or is address(0)
   * @param newSphereXEngine new address of the spherex engine
   */
  function _checkSphereXEngine(address newSphereXEngine) internal view {
    if (
      newSphereXEngine != address(0) &&
      !ISphereXEngine(newSphereXEngine).supportsInterface(type(ISphereXEngine).interfaceId)
    ) {
      revert SphereXNotEngine();
    }
  }

  /**
   *
   * @param newSphereXEngine new address of the spherex engine
   * @dev this is also used to actually enable the defense
   * (because as long is this address is 0, the protection is disabled).
   */
  function changeSphereXEngine(address newSphereXEngine) external spherexOnlyOperator {
    _checkSphereXEngine(newSphereXEngine);
    address oldEngine = _getAddress(SPHEREX_ENGINE_STORAGE_SLOT);
    _setAddress(SPHEREX_ENGINE_STORAGE_SLOT, newSphereXEngine);
    emit_ChangedSpherexEngineAddress(oldEngine, newSphereXEngine);
  }

  // ============ Engine interaction ============

  function _addAllowedSenderOnChain(address newSender) internal {
    ISphereXEngine engine = _sphereXEngine();
    if (address(engine) != address(0)) {
      engine.addAllowedSenderOnChain(newSender);
    }
    emit NewAllowedSenderOnchain(newSender);
  }

  // ============ Hooks ============

  /**
   * @dev The return type is a pointer rather than a struct because solidity
   *      will always allocate and zero memory for the full size of every
   *      variable declaration. Having a struct return type that gets reassigned
   *      to the return value of another function wastes the first allocation.
   *
   */
  function _sphereXValidateExternalPre() internal returns (uint256 localsPointer) {
    return _castFunctionToPointerOutput(_getStorageSlotsAndPreparePostCalldata)(_getSelector());
  }

  /**
   * @dev Internal function for engine communication. We use it to reduce contract size.
   *      Should be called before the code of an external function.
   *
   *      Queries `storageSlots` from `sphereXValidatePre` on the engine and writes
   *      the result to `locals.storageSlots`, then caches the current storage values
   *      for those slots in `locals.valuesBefore`.
   *
   *      Also allocates memory for the calldata of the future call to `sphereXValidatePost`
   *      and initializes every value in the calldata except for `gas` and `valuesAfter` data.
   *
   * @param num function identifier
   */
  function _getStorageSlotsAndPreparePostCalldata(
    int256 num
  ) internal returnsIfNotActivatedPre(locals) returns (ModifierLocals memory locals) {
    assembly {
      // Read engine from `locals.engine` - this is filled by `returnsIfNotActivatedPre`
      let engineAddress := mload(add(locals, 0x60))

      // Get free memory pointer - this will be used for the calldata
      // to `sphereXValidatePre` and then reused for both `storageSlots`
      // and the future calldata to `sphereXValidatePost`
      let pointer := mload(0x40)

      // Call:
      // `sphereXValidatePre(num, msg.sender, msg.data)`
      mstore(pointer, 0x8925ca5a)
      mstore(add(pointer, 0x20), num)
      mstore(add(pointer, 0x40), caller())
      mstore(add(pointer, 0x60), 0x60)
      mstore(add(pointer, 0x80), calldatasize())
      calldatacopy(add(pointer, 0xa0), 0, calldatasize())
      let size := add(0xc4, calldatasize())

      if iszero(
        and(eq(mload(0), 0x20), call(gas(), engineAddress, 0, add(pointer, 28), size, 0, 0x40))
      ) {
        returndatacopy(0, 0, returndatasize())
        revert(0, returndatasize())
      }
      let length := mload(0x20)
      // Set up the memory after the allocation `locals` struct as:
      // [0x00:0x20]: `storageSlots.length`
      // [0x20:0x20+(length * 0x20)]: `storageSlots` data
      // [0x20+(length*0x20):]: calldata for `sphereXValidatePost`

      // The layout for the `sphereXValidatePost` calldata is:
      // [0x00:0x20]: num
      // [0x20:0x40]: gas
      // [0x40:0x60]: valuesBefore offset (0x80)
      // [0x60:0x80]: valuesAfter offset (0xa0 + (0x20 * length))
      // [0x80:0xa0]: valuesBefore length (0xa0 + (0x20 * length))
      // [0xa0:0xa0+(0x20*length)]: valuesBefore data
      // [0xa0+(0x20*length):0xc0+(0x20*length)] valuesAfter length
      // [0xc0+(0x20*length):0xc0+(0x40*length)]: valuesAfter data
      //
      // size of calldata: 0xc0 + (0x40 * length)
      //
      // size of allocation: 0xe0 + (0x60 * length)

      // Calculate size of array data (excluding length): 32 * length
      let arrayDataSize := shl(5, length)

      // Finalize memory allocation with space for `storageSlots` and
      // the calldata for `sphereXValidatePost`.
      mstore(0x40, add(pointer, add(0xe0, mul(arrayDataSize, 3))))

      // Copy `storageSlots` from returndata to the start of the allocated
      // memory buffer and write the pointer to `locals.storageSlots`
      returndatacopy(pointer, 0x20, add(arrayDataSize, 0x20))
      mstore(locals, pointer)

      // Get pointer to future calldata.
      // Add `32 + arrayDataSize` to skip the allocation for `locals.storageSlots`
      // @todo *could* put `valuesBefore` before `storageSlots` and reuse
      // the `storageSlots` buffer for `valuesAfter`
      let calldataPointer := add(pointer, add(arrayDataSize, 0x20))

      // Write `-num` to calldata
      mstore(calldataPointer, sub(0, num))

      // Write `valuesBefore` offset to calldata
      mstore(add(calldataPointer, 0x40), 0x80)

      // Write `locals.valuesBefore` pointer
      mstore(add(locals, 0x20), add(calldataPointer, 0x80))

      // Write `valuesAfter` offset to calldata
      mstore(add(calldataPointer, 0x60), add(0xa0, arrayDataSize))

      // Write `gasleft()` to `locals.gas`
      mstore(add(locals, 0x40), gas())
    }
    _readStorageTo(locals.storageSlots, locals.valuesBefore);
  }

  function _sphereXValidateExternalPost(uint256 locals) internal {
    _castFunctionToPointerInput(_callSphereXValidatePost)(locals);
  }

  function _callSphereXValidatePost(
    ModifierLocals memory locals
  ) internal returnsIfNotActivatedPost(locals) {
    uint256 length;
    bytes32[] memory storageSlots;
    bytes32[] memory valuesAfter;
    assembly {
      storageSlots := mload(locals)
      length := mload(storageSlots)
      valuesAfter := add(storageSlots, add(0xc0, shl(6, length)))
    }
    _readStorageTo(storageSlots, valuesAfter);
    assembly {
      let sphereXEngineAddress := mload(add(locals, 0x60))
      let arrayDataSize := shl(5, length)
      let calldataSize := add(0xc4, shl(1, arrayDataSize))

      let calldataPointer := add(storageSlots, add(arrayDataSize, 0x20))
      let gasDiff := sub(mload(add(locals, 0x40)), gas())
      mstore(add(calldataPointer, 0x20), gasDiff)
      let slotBefore := sub(calldataPointer, 32)
      let slotBeforeCache := mload(slotBefore)
      mstore(slotBefore, 0xf0bd9468)
      if iszero(call(gas(), sphereXEngineAddress, 0, add(slotBefore, 28), calldataSize, 0, 0)) {
        returndatacopy(0, 0, returndatasize())
        revert(0, returndatasize())
      }
    }
  }

  function _getSelector() internal pure returns (int256 selector) {
    assembly {
      selector := shr(224, calldataload(0))
    }
  }

  /**
   *  @dev Modifier to be incorporated in all external protected non-view functions
   */
  modifier sphereXGuardExternal() {
    uint256 localsPointer = _sphereXValidateExternalPre();
    _;
    _sphereXValidateExternalPost(localsPointer);
  }

  // ============ Function Type Casts ============

  function _castFunctionToPointerInput(
    function(ModifierLocals memory) internal fnIn
  ) internal pure returns (function(uint256) internal fnOut) {
    assembly {
      fnOut := fnIn
    }
  }

  function _castFunctionToPointerOutput(
    function(int256) internal returns (ModifierLocals memory) fnIn
  ) internal pure returns (function(int256) internal returns (uint256) fnOut) {
    assembly {
      fnOut := fnIn
    }
  }

  // ============ Internal Storage logic ============

  function _readStorageTo(bytes32[] memory storageSlots, bytes32[] memory values) internal view {
    assembly {
      let length := mload(storageSlots)
      let arrayDataSize := shl(5, length)
      mstore(values, length)
      let nextSlotPointer := add(storageSlots, 0x20)
      let nextElementPointer := add(values, 0x20)
      let endPointer := add(nextElementPointer, shl(5, length))
      for {

      } lt(nextElementPointer, endPointer) {

      } {
        mstore(nextElementPointer, sload(mload(nextSlotPointer)))
        nextElementPointer := add(nextElementPointer, 0x20)
        nextSlotPointer := add(nextSlotPointer, 0x20)
      }
    }
  }

  /**
   * Internal function that reads values from given storage slots and returns them
   * @param storageSlots list of storage slots to read
   * @return values list of values read from the various storage slots
   */
  function _readStorage(
    bytes32[] memory storageSlots
  ) internal view returns (bytes32[] memory values) {
    assembly {
      values := mload(0x40)
      mstore(0x40, add(values, add(shl(5, mload(storageSlots)), 0x20)))
    }
    _readStorageTo(storageSlots, values);
  }
}
