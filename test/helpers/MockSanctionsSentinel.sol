// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

contract MockSanctionsSentinel {
  mapping(address => bool) public isSanctioned;
  mapping(bytes32 => address) public escrowByAccountBorrowerToken;
  bytes32 public constant SanctionsEscrowInitCodeHash =
    keccak256(type(MockSanctionsEscrow).creationCode);

  // Allows a registered vault to create an escrow contract for
  // a sanctioned address that holds assets until either the
  // sanctions are lifted or the assets are released by the borrower.
  function createEscrow(
    address account,
    address borrower,
    address token
  ) external returns (address escrowContract) {
    bytes32 id = _deriveSalt(account, borrower, token);
    if (escrowByAccountBorrowerToken[id] == address(0)) {
      escrowByAccountBorrowerToken[id] = address(new MockSanctionsEscrow{ salt: id }());
    }
    return escrowByAccountBorrowerToken[id];
  }

  function sanction(address account) external {
    isSanctioned[account] = true;
  }

  function _deriveSalt(
    address account,
    address borrower,
    address token
  ) internal pure returns (bytes32 salt) {
    return keccak256(abi.encode(account, borrower, token));
  }

  function getEscrowAddress(
    address account,
    address borrower,
    address token
  ) external view returns (address) {
    return _computeEscrowAddress(_deriveSalt(account, borrower, token));
  }

  function _computeEscrowAddress(bytes32 salt) internal view returns (address) {
    return
      address(
        uint160(
          uint256(
            keccak256(
              abi.encodePacked(bytes1(0xff), address(this), salt, SanctionsEscrowInitCodeHash)
            )
          )
        )
      );
  }
}

contract MockSanctionsEscrow {
  constructor() {}

  uint public x;
}
