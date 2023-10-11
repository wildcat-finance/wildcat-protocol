// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

interface IWildcatSanctionsEscrow {
  event EscrowReleased(
    address indexed caller,
    address indexed account,
    address indexed asset,
    uint256 amount
  );

  error CanNotReleaseEscrow();

  function borrower() external view returns (address);

  function account() external view returns (address);

  function balance() external view returns (uint256);

  function canReleaseEscrow() external view returns (bool);

  function escrowedAsset() external view returns (address token, uint256 amount);

  function releaseEscrow() external;
}
