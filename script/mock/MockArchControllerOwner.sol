// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "src/WildcatArchController.sol";
import "src/WildcatMarketControllerFactory.sol";

contract MockArchControllerOwner {
    WildcatArchController internal immutable archController;
    mapping(address => bool) public authorizedAccounts;

    constructor(address _archController) {
        archController = WildcatArchController(_archController);
        authorizedAccounts[msg.sender] = true;
    }

    function authorizeAccount(address account) external {
        require(authorizedAccounts[account], "only original owner");
        authorizedAccounts[account] = true;
    }

    function returnOwnership() external {
        require(authorizedAccounts[msg.sender], "not authorized");
        archController.transferOwnership(msg.sender);
    }

    function registerBorrower(address borrower) external {
        archController.registerBorrower(borrower);
    }

    function registerBorrowers(address[] calldata borrowers) external {
        for (uint256 i; i < borrowers.length; i++) {
            archController.registerBorrower(borrowers[i]);
        }
    }

    function setProtocolFeeConfiguration(
        WildcatMarketControllerFactory factory,
        address feeRecipient,
        address originationFeeAsset,
        uint80 originationFeeAmount,
        uint16 protocolFeeBips
    ) external {
        require(authorizedAccounts[msg.sender], "not authorized");
        factory.setProtocolFeeConfiguration(feeRecipient, originationFeeAsset, originationFeeAmount, protocolFeeBips);
    }
}
