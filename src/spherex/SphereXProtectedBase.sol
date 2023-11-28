// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import { ISphereXEngine, ModifierLocals } from './ISphereXEngine.sol';
import './SphereXProtectedEvents.sol';

// 0x00: num
// 0x20: gas
// 0x40: valuesBefore offset (0x80)
// 0x60: valuesAfter offset (0xa0 + (0x20 * length))
// 0x80: valuesBefore length (0xa0 + (0x20 * length))
// 0xa0:0xa0+(0x20*length): valuesBefore data
// 0xa0 + (0x20 * length): valuesAfter length
// 0xc0 + (0x20 * length):0xc0 + (0x40 * length): valuesAfter data
// size of calldata: 0xc0 + (0x40 * length)

uint256 constant Locals_storageSlots_pointer_offset = 0x00;
uint256 constant Locals_valuesBefore_pointer_offset = 0x20;

uint256 constant Post_num_calldata_pos = 0x00;
uint256 constant Post_gas_calldata_pos = 0x20;
uint256 constant Post_valuesBefore_offset_calldata_pos = 0x40;
uint256 constant Post_valuesAfter_offset_calldata_pos = 0x60;
uint256 constant Post_valuesBefore_length_calldata_pos = 0x80;
uint256 constant Post_valuesBefore_data_calldata_pos = 0xa0;
uint256 constant Post_valuesAfter_length_calldata_min_pos = 0xa0;

// uint256 constant Post_valuesAfter_length_calldata_min_pos = 0xc0;

/**
 * @title SphereX base Customer contract template
 */
abstract contract SphereXProtectedBase {
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
   * @dev used when the client doesn't use a proxy
   * @notice constructor visibility is required to support all compiler versions
   */
  constructor(address admin, address operator, address engine) {
    __SphereXProtectedBase_init(admin, operator, engine);
  }

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

  modifier returnsIfNotActivated() {
    if (address(_sphereXEngine()) == address(0)) {
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
    emit_NewAllowedSenderOnchain(newSender);
  }

  // ============ Hooks ============

  function _getPtr(uint256 _ptr) internal pure returns (uint256 ptr) {
    assembly {
      ptr := _ptr
    }
  }

  function castAsLocals(
    function(uint256) internal pure returns (uint256) fnIn
  ) internal pure returns (function(uint256) internal pure returns (ModifierLocals memory) fnOut) {
    assembly {
      fnOut := fnIn
    }
  }

  /**
   * @dev The return type is a pointer rather than a struct because solidity
   *      will always allocate and zero memory for the full size of every
   *      variable declaration. Having a struct return type that gets reassigned
   *      to the return value of another function wastes the first allocation.
   *
   */
  function _pre() internal returns (uint256 ptr) {
    uint256 selector;
    assembly {
      selector := shr(224, calldataload(0))
    }
    ModifierLocals memory locals = _sphereXValidatePre(int256(selector), true);
    assembly {
      ptr := locals
    }
  }

  function _post(uint256 ptr) internal {
    int256 selector;
    assembly {
      selector := shr(224, calldataload(0))
    }
    _sphereXValidatePost(-selector, true, castAsLocals(_getPtr)(ptr));
  }

  /**
   * @dev internal function for engine communication. We use it to reduce contract size.
   *  Should be called before the code of a function.
   * @param num function identifier
   * @param isExternalCall set to true if this was called externally
   *  or a 'public' function from another address
   */
  function _sphereXValidatePre(
    int256 num,
    bool isExternalCall
  ) internal returnsIfNotActivated returns (ModifierLocals memory locals) {
    ISphereXEngine sphereXEngine = _sphereXEngine();
    if (isExternalCall) {
      locals.storageSlots = sphereXEngine.sphereXValidatePre(num, msg.sender, msg.data);
      locals.valuesBefore = _readStorage(locals.storageSlots);
    } else {
      locals.storageSlots = sphereXEngine.sphereXValidateInternalPre(num);
      locals.valuesBefore = _readStorage(locals.storageSlots);
    }
    locals.gas = gasleft();
    return locals;
  }

  /**
   * @dev internal function for engine communication. We use it to reduce contract size.
   *  Should be called after the code of a function.
   * @param num function identifier
   * @param isExternalCall set to true if this was called externally
   *  or a 'public' function from another address
   */
  function _sphereXValidatePost(
    int256 num,
    bool isExternalCall,
    ModifierLocals memory locals
  ) internal returnsIfNotActivated {
    uint256 gas = locals.gas - gasleft();

    ISphereXEngine sphereXEngine = _sphereXEngine();

    bytes32[] memory valuesAfter;
    valuesAfter = _readStorage(locals.storageSlots);

    if (isExternalCall) {
      sphereXEngine.sphereXValidatePost(num, gas, locals.valuesBefore, valuesAfter);
    } else {
      sphereXEngine.sphereXValidateInternalPost(num, gas, locals.valuesBefore, valuesAfter);
    }
  }

  /**
   * @dev internal function for engine communication. We use it to reduce contract size.
   *  Should be called before the code of a function.
   * @param num function identifier
   * @return locals ModifierLocals
   */
  function _sphereXValidateInternalPre(
    int256 num
  ) internal returnsIfNotActivated returns (ModifierLocals memory locals) {
    locals.storageSlots = _sphereXEngine().sphereXValidateInternalPre(num);
    locals.valuesBefore = _readStorage(locals.storageSlots);
    locals.gas = gasleft();
    return locals;
  }

  /**
   * @dev internal function for engine communication. We use it to reduce contract size.
   *  Should be called after the code of a function.
   * @param num function identifier
   * @param locals ModifierLocals
   */
  function _sphereXValidateInternalPost(
    int256 num,
    ModifierLocals memory locals
  ) internal returnsIfNotActivated {
    bytes32[] memory valuesAfter;
    valuesAfter = _readStorage(locals.storageSlots);
    _sphereXEngine().sphereXValidateInternalPost(
      num,
      locals.gas - gasleft(),
      locals.valuesBefore,
      valuesAfter
    );
  }

  /**
   *  @dev Modifier to be incorporated in all internal protected non-view functions
   */
  modifier sphereXGuardInternal(int256 num) {
    ModifierLocals memory locals = _sphereXValidateInternalPre(num);
    _;
    _sphereXValidateInternalPost(-num, locals);
  }

  /**
   *  @dev Modifier to be incorporated in all external protected non-view functions
   */
  modifier sphereXGuardExternal(int256 num) {
    // ModifierLocals memory locals = _sphereXValidatePre(num, true);
    uint256 ptr = _pre();
    _;
    // _sphereXValidatePost(-num, true, locals);
    _post(ptr);
    // IR without internals and with chgd modifier
    // WildcatMarket | init: 29690 bytes | runtime: 24978
    // NOT IR init: 29078 | runtime: 24755 | runs: 200

    // IR with internals and chgd modifier
    // WildcatMarket | init: 31809 bytes | runtime: 27097

    // with change to read storage, without internals, without chgd modifier
    // IR: WildcatMarket | init: 35303 bytes | runtime: 30591
    // NOT IR: WildcatMarket | init: 29054 | runtime: 24731 | runs: 200

    // With change to read storage
    // NOT IR: WildcatMarket | init: 28977 | runtime: 24654 | runs: 200
    // IR: WildcatMarket | init: 29656 bytes | runtime: 24944
  }

  /**
   *  @dev Modifier to be incorporated in all public protected non-view functions
   */
  modifier sphereXGuardPublic(int256 num, bytes4 selector) {
    ModifierLocals memory locals = _sphereXValidatePre(num, msg.sig == selector);
    _;
    _sphereXValidatePost(-num, msg.sig == selector, locals);
  }

  // ============ Internal Storage logic ============

  // function _readStorageTo(bytes32[] memory storageSlots, bytes32[] memory values) internal view {
  //   assembly {
  //     let length := mload(storageSlots)
  //     let arrayDataSize := shl(5, length)
  //     mstore(values, length)
  //     let nextSlotPointer := add(storageSlots, 0x20)
  //     let nextElementPointer := add(values, 0x20)
  //     let endPointer := add(nextElementPointer, shl(5, length))
  //     for {

  //     } lt(nextElementPointer, endPointer) {

  //     } {
  //       mstore(nextElementPointer, sload(mload(nextSlotPointer)))
  //       nextElementPointer := add(nextElementPointer, 0x20)
  //       nextSlotPointer := add(nextSlotPointer, 0x20)
  //     }
  //   }
  // }

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
      let length := mload(storageSlots)
      mstore(values, length)
      let inPtr := add(storageSlots, 0x20)
      let ptr := add(values, 0x20)
      let endPtr := add(ptr, shl(5, length))
      mstore(0x40, endPtr)
      for {

      } lt(ptr, endPtr) {

      } {
        mstore(ptr, sload(mload(inPtr)))
        ptr := add(ptr, 0x20)
        inPtr := add(inPtr, 0x20)
      }
      // mstore(0x40, add(values, mul(add(mload(storageSlots), 0x20), 0x20)))
      // mstore(values, mload(storageSlots))
    }
    // assembly {
    //   values := mload(0x40)
    //   mstore(0x40, add(values, add(shl(5, mload(storageSlots)), 0x20)))
    // }
    // _readStorageTo(storageSlots, values);
    // uint256 arrayLength = storageSlots.length;
    // bytes32[] memory values = new bytes32[](arrayLength);
    // // create the return array data

    // for (uint256 i = 0; i < arrayLength; i++) {
    //   bytes32 slot = storageSlots[i];
    //   bytes32 temp_value;
    //   // solhint-disable-next-line no-inline-assembly
    //   // slither-disable-next-line assembly
    //   assembly {
    //     temp_value := sload(slot)
    //   }

    //   values[i] = temp_value;
    // }
    // return values;
  }
}
