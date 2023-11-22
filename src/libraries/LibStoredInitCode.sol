// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import {ISphereXEngine, ModifierLocals} from "@spherex-xyz/contracts/src/ISphereXEngine.sol";


library LibStoredInitCode {
  error InitCodeDeploymentFailed();
  error DeploymentFailed();

  bytes32 private constant SPHEREX_ENGINE_STORAGE_SLOT =
        bytes32(uint256(keccak256("eip1967.spherex.spherex_engine")) - 1);

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

  modifier returnsIfNotActivated() {
        if (address(_sphereXEngine()) == address(0)) {
            return;
        }

        _;
    }

  function _sphereXEngine() private view returns (ISphereXEngine) {
        return ISphereXEngine(_getAddress(SPHEREX_ENGINE_STORAGE_SLOT));
    }

    /**
     * @dev internal function for engine communication. We use it to reduce contract size.
     *  Should be called before the code of a function.
     * @param num function identifier
     * @return locals ModifierLocals
     */
    function _sphereXValidateInternalPre(int256 num)
        internal
        returnsIfNotActivated
        returns (ModifierLocals memory locals)
    {
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
    function _sphereXValidateInternalPost(int256 num, ModifierLocals memory locals) internal returnsIfNotActivated {
        bytes32[] memory valuesAfter;
        valuesAfter = _readStorage(locals.storageSlots);
        _sphereXEngine().sphereXValidateInternalPost(num, locals.gas - gasleft(), locals.valuesBefore, valuesAfter);
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
     * Internal function that reads values from given storage slots and returns them
     * @param storageSlots list of storage slots to read
     * @return list of values read from the various storage slots
     */
    function _readStorage(bytes32[] memory storageSlots) internal view returns (bytes32[] memory) {
        uint256 arrayLength = storageSlots.length;
        bytes32[] memory values = new bytes32[](arrayLength);
        // create the return array data

        for (uint256 i = 0; i < arrayLength; i++) {
            bytes32 slot = storageSlots[i];
            bytes32 temp_value;
            // solhint-disable-next-line no-inline-assembly
            // slither-disable-next-line assembly
            assembly {
                temp_value := sload(slot)
            }

            values[i] = temp_value;
        }
        return values;
    }

  function deployInitCode(bytes memory data) internal sphereXGuardInternal(0xc73b8fd0) returns (address initCodeStorage) {
    assembly {
      let size := mload(data)
      let createSize := add(size, 0x0b)
      // Prefix Code
      //
      // Has trailing STOP instruction so the deployed data
      // can not be executed as a smart contract.
      //
      // Instruction                | Stack
      // ----------------------------------------------------
      // PUSH2 size                 | size                  |
      // PUSH0                      | 0, size               |
      // DUP2                       | size, 0, size         |
      // PUSH1 10 (offset to STOP)  | 10, size, 0, size     |
      // PUSH0                      | 0, 10, size, 0, size  |
      // CODECOPY                   | 0, size               |
      // RETURN                     |                       |
      // STOP                       |                       |
      // ----------------------------------------------------

      // Shift (size + 1) to position it in front of the PUSH2 instruction.
      // Reuse `data.length` memory for the create prefix to avoid
      // unnecessary memory allocation.
      mstore(data, or(shl(64, add(size, 1)), 0x6100005f81600a5f39f300))
      // Deploy the code storage
      initCodeStorage := create(0, add(data, 21), createSize)
      // if (initCodeStorage == address(0)) revert InitCodeDeploymentFailed();
      if iszero(initCodeStorage) {
        mstore(0, 0x11c8c3c0)
        revert(0x1c, 0x04)
      }
      // Restore `data.length`
      mstore(data, size)
    }
  }

  /**
   * @dev Returns the create2 prefix for a given deployer address.
   *      Equivalent to `uint256(uint160(deployer)) | (0xff << 160)`
   */
  function getCreate2Prefix(address deployer) internal pure returns (uint256 create2Prefix) {
    assembly {
      create2Prefix := or(deployer, 0xff0000000000000000000000000000000000000000)
    }
  }

  function calculateCreate2Address(
    uint256 create2Prefix,
    bytes32 salt,
    uint256 initCodeHash
  ) internal pure returns (address create2Address) {
    assembly {
      // Cache the free memory pointer so it can be restored
      // at the end
      let ptr := mload(0x40)

      // Write 0xff + address to bytes 11:32
      mstore(0x00, create2Prefix)

      // Write salt to bytes 32:64
      mstore(0x20, salt)

      // Write initcode hash to bytes 64:96
      mstore(0x40, initCodeHash)

      // Calculate create2 hash for token0, token1
      // The EVM only looks at the last 20 bytes, so the dirty
      // bits at the beginning do not need to be cleaned
      create2Address := keccak256(0x0b, 0x55)

      // Restore the free memory pointer
      mstore(0x40, ptr)
    }
  }

  function createWithStoredInitCode(address initCodeStorage) internal sphereXGuardInternal(0xb0868146) returns (address deployment) {
    deployment = createWithStoredInitCode(initCodeStorage, 0);
  }

  function createWithStoredInitCode(
    address initCodeStorage,
    uint256 value
  ) internal sphereXGuardInternal(0xb0868147) returns (address deployment) {
    assembly {
      let initCodePointer := mload(0x40)
      let initCodeSize := sub(extcodesize(initCodeStorage), 1)
      extcodecopy(initCodeStorage, initCodePointer, 1, initCodeSize)
      deployment := create(value, initCodePointer, initCodeSize)
      if iszero(deployment) {
        mstore(0x00, 0x30116425) // DeploymentFailed()
        revert(0x1c, 0x04)
      }
    }
  }

  function create2WithStoredInitCode(
    address initCodeStorage,
    bytes32 salt
  ) internal sphereXGuardInternal(0xf5bfe1a7) returns (address deployment) {
    deployment = create2WithStoredInitCode(initCodeStorage, salt, 0);
  }

  function create2WithStoredInitCode(
    address initCodeStorage,
    bytes32 salt,
    uint256 value
  ) internal sphereXGuardInternal(0xf5bfe1a8) returns (address deployment) {
    assembly {
      let initCodePointer := mload(0x40)
      let initCodeSize := sub(extcodesize(initCodeStorage), 1)
      extcodecopy(initCodeStorage, initCodePointer, 1, initCodeSize)
      deployment := create2(value, initCodePointer, initCodeSize, salt)
      if iszero(deployment) {
        mstore(0x00, 0x30116425) // DeploymentFailed()
        revert(0x1c, 0x04)
      }
    }
  }
}
