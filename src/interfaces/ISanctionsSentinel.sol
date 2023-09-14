// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

interface ISanctionsSentinel {
	// Allows a registered vault to create an escrow contract for
	// a sanctioned address that holds assets until either the
	// sanctions are lifted or the assets are released by the borrower.
	function createEscrow(
		address account,
		address borrower,
		address token
	) external returns (address escrowContract);

	function isSanctioned(address account) external view returns (bool);
}

interface ISanctionsEscrow {
	function releaseAssets() external;

	function canReleaseAssets() external view returns (bool);

	function escrowedAssets() external view returns (address[] memory, uint256[] memory);

	function borrower() external view returns (address);

	function account() external view returns (address);
}
