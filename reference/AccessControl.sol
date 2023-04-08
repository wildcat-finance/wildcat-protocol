// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "solmate/auth/Owned.sol";
import './interfaces/IAccessControl.sol';
import './interfaces/IWildcatPermissions.sol';

abstract contract AccessControl is IAccessControl {
	// =====================================================================//
	//                       Storage and immutables                         //
	// =====================================================================//

	/// @dev Whether callers must be authorized to receive assets.
	bool public immutable CHECK_AUTH_ON_RECEIVE;

	/// @dev Whether callers must be authorized to deposit assets.
	bool public immutable CHECK_AUTH_ON_DEPOSIT;

	/// @dev Whether callers must be authorized to withdraw assets.
	bool public immutable CHECK_AUTH_ON_WITHDRAW;

	IWildcatPermissions public immutable permissionsController;

	address public owner;

	// =====================================================================//
	//                              Modifiers                               //
	// =====================================================================//

	modifier onlyOwner() {
		if (msg.sender != owner) revert NotOwner();
		_;
	}

	modifier authorizedToReceive(address to) {
    if (CHECK_AUTH_ON_RECEIVE) {
      if (!permissionsController.checkAuthorization(AuthorizableAction.RECEIVE, to)) {
        revert UnauthorizedAction(AuthorizableAction.RECEIVE, to);
      }
    }
		_;
	}

	modifier authorizedToDeposit(address to) {
    if (CHECK_AUTH_ON_DEPOSIT) {
      if (!permissionsController.checkAuthorization(AuthorizableAction.DEPOSIT, to)) {
        revert UnauthorizedAction(AuthorizableAction.DEPOSIT, to);
      }
    }
		_;
	}

	modifier authorizedToWithdraw(address to) {
    if (CHECK_AUTH_ON_WITHDRAW) {
      if (!permissionsController.checkAuthorization(AuthorizableAction.WITHDRAW, to)) {
        revert UnauthorizedAction(AuthorizableAction.WITHDRAW, to);
      }
    }
		_;
	}

	// =====================================================================//
	//                             Constructor                              //
	// =====================================================================//

	constructor(address _owner, address _permissionsController) {
		owner = _owner;

		emit OwnershipTransferred(address(0), _owner);
		permissionsController = IWildcatPermissions(_permissionsController);

		(
			CHECK_AUTH_ON_RECEIVE,
			CHECK_AUTH_ON_DEPOSIT,
			CHECK_AUTH_ON_WITHDRAW
		) = permissionsController.getAuthorizationRequirements();
	}

	// =====================================================================//
	//                            Owner Actions                             //
	// =====================================================================//

	function transferOwnership(address newOwner) public virtual onlyOwner {
		owner = newOwner;

		emit OwnershipTransferred(msg.sender, newOwner);
	}
}
