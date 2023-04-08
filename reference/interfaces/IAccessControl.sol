// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { AuthorizableAction } from "./IWildcatPermissions.sol";

interface IAccessControl {
	/// @notice Event emitted when ownership is transferred
	event OwnershipTransferred(address indexed user, address indexed newOwner);

	/// @notice Error thrown when non-owner tries accessing owner-only actions
	error NotOwner();

  error UnauthorizedAction(AuthorizableAction action, address account);
  error GenericUnauthorizedAction();
}
