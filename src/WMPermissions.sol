// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

contract WMPermissions {

    address public wintermute;
    mapping(address => bool) public whitelisted;

    modifier isWintermute() {
        require(msg.sender == wintermute, "isWintermute: not Wintermute");
        _;
    }

    event WintermuteAddressUpdated(address);
    event CounterpartyAdjustment(address, bool);

    constructor(address _wintermute) {
        wintermute = _wintermute;
        emit WintermuteAddressUpdated(_wintermute);
    }

    function updateWintermute(address _newWM) external isWintermute() {
        wintermute = _newWM;
        emit WintermuteAddressUpdated(_newWM);
    }

    function isWhitelisted(address _counterparty) external view returns (bool) {
        return whitelisted[_counterparty];
    }

    // Addresses that are whitelisted can mint wmtX via X
    // An address that is no longer whitelisted can redeem, but cannot mint more
    function adjustWhitelist(address _counterparty, bool _allowed) external isWintermute() {
        whitelisted[_counterparty] = _allowed;
        emit CounterpartyAdjustment(_counterparty, _allowed);
    }

}

