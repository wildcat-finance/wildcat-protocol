// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import '../types/ScaleParametersCoder.sol';

// ============================== NOTICE ==============================
// This library was automatically generated with stackpacker.
// Be very careful about modifying it, as doing so incorrectly could
// result in corrupted reads/writes.
// ====================================================================

contract ExternalScaleParametersCoder {
	ScaleParameters internal _scaleParameters;

	function decode()
		external
		view
		returns (
			bool isDelinquent,
			uint256 timeDelinquent,
			uint256 annualInterestBips,
			uint256 scaleFactor,
			uint256 lastInterestAccruedTimestamp
		)
	{
		(
			isDelinquent,
			timeDelinquent,
			annualInterestBips,
			scaleFactor,
			lastInterestAccruedTimestamp
		) = ScaleParametersCoder.decode(_scaleParameters);
	}

	function encode(
		bool isDelinquent,
		uint256 timeDelinquent,
		uint256 annualInterestBips,
		uint256 scaleFactor,
		uint256 lastInterestAccruedTimestamp
	) external {
		(_scaleParameters) = ScaleParametersCoder.encode(
			isDelinquent,
			timeDelinquent,
			annualInterestBips,
			scaleFactor,
			lastInterestAccruedTimestamp
		);
	}

	function getNewScaleInputs()
		external
		view
		returns (
			uint256 annualInterestBips,
			uint256 scaleFactor,
			uint256 lastInterestAccruedTimestamp
		)
	{
		(
			annualInterestBips,
			scaleFactor,
			lastInterestAccruedTimestamp
		) = ScaleParametersCoder.getNewScaleInputs(_scaleParameters);
	}

	function setNewScaleOutputs(
		uint256 scaleFactor,
		uint256 lastInterestAccruedTimestamp
	) external {
		(_scaleParameters) = ScaleParametersCoder.setNewScaleOutputs(
			_scaleParameters,
			scaleFactor,
			lastInterestAccruedTimestamp
		);
	}

	function setInitialState(
		uint256 annualInterestBips,
		uint256 scaleFactor,
		uint256 lastInterestAccruedTimestamp
	) external {
		(_scaleParameters) = ScaleParametersCoder.setInitialState(
			_scaleParameters,
			annualInterestBips,
			scaleFactor,
			lastInterestAccruedTimestamp
		);
	}

	function getIsDelinquent() external view returns (bool isDelinquent) {
		(isDelinquent) = ScaleParametersCoder.getIsDelinquent(_scaleParameters);
	}

	function setIsDelinquent(bool isDelinquent) external {
		(_scaleParameters) = ScaleParametersCoder.setIsDelinquent(
			_scaleParameters,
			isDelinquent
		);
	}

	function getTimeDelinquent() external view returns (uint256 timeDelinquent) {
		(timeDelinquent) = ScaleParametersCoder.getTimeDelinquent(_scaleParameters);
	}

	function setTimeDelinquent(uint256 timeDelinquent) external {
		(_scaleParameters) = ScaleParametersCoder.setTimeDelinquent(
			_scaleParameters,
			timeDelinquent
		);
	}

	function getAnnualInterestBips()
		external
		view
		returns (uint256 annualInterestBips)
	{
		(annualInterestBips) = ScaleParametersCoder.getAnnualInterestBips(
			_scaleParameters
		);
	}

	function setAnnualInterestBips(uint256 annualInterestBips) external {
		(_scaleParameters) = ScaleParametersCoder.setAnnualInterestBips(
			_scaleParameters,
			annualInterestBips
		);
	}

	function getScaleFactor() external view returns (uint256 scaleFactor) {
		(scaleFactor) = ScaleParametersCoder.getScaleFactor(_scaleParameters);
	}

	function setScaleFactor(uint256 scaleFactor) external {
		(_scaleParameters) = ScaleParametersCoder.setScaleFactor(
			_scaleParameters,
			scaleFactor
		);
	}

	function getLastInterestAccruedTimestamp()
		external
		view
		returns (uint256 lastInterestAccruedTimestamp)
	{
		(lastInterestAccruedTimestamp) = ScaleParametersCoder
			.getLastInterestAccruedTimestamp(_scaleParameters);
	}

	function setLastInterestAccruedTimestamp(uint256 lastInterestAccruedTimestamp)
		external
	{
		(_scaleParameters) = ScaleParametersCoder.setLastInterestAccruedTimestamp(
			_scaleParameters,
			lastInterestAccruedTimestamp
		);
	}
}
