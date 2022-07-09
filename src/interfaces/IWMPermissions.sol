// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

interface IWMPermissions {

    function wintermute() external view returns (address);
    function isWhitelisted(address _counterparty) external view returns (bool);
    function adjustWhitelist(address _counterparty, bool _allowed) external;

}