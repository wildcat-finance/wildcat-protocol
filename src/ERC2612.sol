// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './EIP712.sol';
import './libraries/MemoryRestoration.sol';

bytes constant ERC2612Permit_typeString = 'Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)';
bytes32 constant ERC2612Permit_typeHash = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
uint256 constant ERC2612Permit_typeHash_ptr = 0x0;
uint256 constant ERC2612Permit_owner_ptr = 0x20;
uint256 constant ERC2612Permit_nonce_ptr = 0x80;
uint256 constant ERC2612Permit_deadline_ptr = 0xa0;
uint256 constant ERC2612Permit_owner_cdPtr = 0x04;
uint256 constant ERC2612Permit_v_cdPtr = 0x84;
uint256 constant ERC2612Permit_signature_length = 0x60;
uint256 constant ERC2612Permit_calldata_params_length = 0x60;
uint256 constant ERC2612Permit_length = 0xc0;

uint256 constant ECRecover_precompile = 0x01;
uint256 constant ECRecover_digest_ptr = 0x0;
uint256 constant ECRecover_v_ptr = 0x20;
uint256 constant ECRecover_calldata_length = 0x80;

abstract contract ERC2612 is EIP712, MemoryRestoration {
	error PermitDeadlineExpired(uint256 deadline, uint256 timestamp);

	/*//////////////////////////////////////////////////////////////
                         Storage & Constants
  //////////////////////////////////////////////////////////////*/

	mapping(address => uint256) public nonces;

	/*//////////////////////////////////////////////////////////////
                             Constructor
  //////////////////////////////////////////////////////////////*/

	constructor(string memory name, string memory version) EIP712(name, version) {
		if (ERC2612Permit_typeHash != keccak256(ERC2612Permit_typeString)) {
			revert InvalidTypeHash();
		}
	}

	/*//////////////////////////////////////////////////////////////
                       ERC20 Internal Actions
  //////////////////////////////////////////////////////////////*/

	function _approve(
		address owner,
		address spender,
		uint256 amount
	) internal virtual;

	/*//////////////////////////////////////////////////////////////
                           ERC-2612 LOGIC
  //////////////////////////////////////////////////////////////*/

	function permit(
		address from,
		address spender,
		uint256 value,
		uint256 deadline,
		uint8,
		bytes32,
		bytes32
	) external virtual {
		if (deadline < block.timestamp) {
			revert PermitDeadlineExpired(deadline, block.timestamp);
		}
		// Unchecked because the only math done is incrementing
		// the owner's nonce which cannot realistically overflow.
		unchecked {
			_verifyPermitSignature(from, nonces[from]++, deadline);
		}

		_approve(from, spender, value);
	}

	function _digestPermit(uint256 nonce, uint256 deadline)
		internal
		view
		returns (bytes32 digest)
	{
		bytes32 domainSeparator = DOMAIN_SEPARATOR();
		assembly {
			mstore(ERC2612Permit_typeHash_ptr, ERC2612Permit_typeHash)
			calldatacopy(
				ERC2612Permit_owner_ptr,
				ERC2612Permit_owner_cdPtr,
				ERC2612Permit_calldata_params_length
			)
			mstore(ERC2612Permit_nonce_ptr, nonce)
			mstore(ERC2612Permit_deadline_ptr, deadline)
			let permitHash := keccak256(
				ERC2612Permit_typeHash_ptr,
				ERC2612Permit_length
			)
			mstore(0, EIP712Signature_prefix)
			mstore(EIP712Signature_domainSeparator_ptr, domainSeparator)
			mstore(EIP712Signature_digest_ptr, permitHash)
			digest := keccak256(0, EIP712Signature_length)
		}
	}

	function _verifyPermitSignature(
		address owner,
		uint256 nonce,
		uint256 deadline
	)
		internal
		view
		RestoreFirstTwoUnreservedSlots
		RestoreFreeMemoryPointer
		RestoreZeroSlot
	{
		bytes32 digest = _digestPermit(nonce, deadline);
		bool validSignature;
		assembly {
			mstore(ECRecover_digest_ptr, digest)
			// Copy v, r, s from calldata
			calldatacopy(
				ECRecover_v_ptr,
				ERC2612Permit_v_cdPtr,
				ERC2612Permit_signature_length
			)
			// Call ecrecover precompile to validate signature
			let success := staticcall(
				gas(),
				ECRecover_precompile, // ecrecover precompile
				ECRecover_digest_ptr,
				ECRecover_calldata_length,
				0x0,
				0x20
			)
			validSignature := and(
				success, // call succeeded
				and(
					gt(owner, 0), // owner != 0
					eq(owner, mload(0)) // owner == recoveredAddress
				)
			)
		}
		if (!validSignature) {
			revert InvalidSigner();
		}
	}
}
