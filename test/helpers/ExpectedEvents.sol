// // SPDX-License-Identifier: MIT
// pragma solidity >=0.8.20;

// import { VmSafe } from 'forge-std/Vm.sol';
// import './VmUtils.sol';

// type MemoryPointer is uint24;

// using LibLogsContext for LogsContext global;

// function malloc(uint) pure returns (MemoryPointer) {}

// library LibArrayCast {
// 	using LibArrayCast for *;

// 	function toMemoryPointer(bytes32[] memory array) internal pure returns (MemoryPointer ptr) {
// 		assembly {
// 			ptr := array
// 		}
// 	}

// 	function toMemoryPointer(VmSafe.Log[] memory array) internal pure returns (MemoryPointer ptr) {
// 		assembly {
// 			ptr := array
// 		}
// 	}

// 	function readUint256(MemoryPointer ptr) internal pure returns (uint256 value) {
// 		assembly {
// 			value := ptr
// 		}
// 	}

// 	function toLogArray(MemoryPointer ptr) internal pure returns (VmSafe.Log[] memory array) {
// 		assembly {
// 			array := ptr
// 		}
// 	}

// 	function toBytes32Array(MemoryPointer ptr) internal pure returns (bytes32[] memory array) {
// 		assembly {
// 			array := ptr
// 		}
// 	}

// 	function cloneWithElement(
// 		MemoryPointer src,
// 		bytes32 value
// 	) internal pure returns (MemoryPointer dst) {
// 		uint256 len = src.readUint256();
// 		// Allocate mmeory for each element of old array, length of new array and new element
// 		dst = malloc((len + 2) << 5);
// 		// Copy old array to new array
// 		copyArrayElements(src, dst);
// 		// Set new element
// 		assembly {
// 			mstore(
// 				add(dst, shl(5, add(len, 1))), // Add 1 to skip length
// 				value
// 			)
// 		}
// 	}

// 	function copyArrayElements(MemoryPointer src, MemoryPointer dst) internal pure {
// 		copyArrayElements(src, dst, src.readUint256());
// 	}

// 	function copyArrayElements(MemoryPointer src, MemoryPointer dst, uint256 len) internal pure {
// 		assembly {
// 			let srcData := add(src, 32)
// 			let dstData := add(dst, 32)
// 			let end := add(srcData, shl(5, len))

// 			for {

// 			} lt(srcData, end) {

// 			} {
// 				mstore(dstData, mload(srcData))
// 				srcData := add(srcData, 32)
// 				dstData := add(dstData, 32)
// 			}
// 		}
// 	}
// }

// library LibLogsContext {
// 	using LibArrayCast for *;

// 	function hashLog(VmSafe.Log memory log) internal pure returns (bytes32) {
// 		bytes32 topicHash = keccak256(abi.encodePacked(log.topics));
// 		bytes32 dataHash = keccak256(log.data);
// 		return keccak256(abi.encodePacked(topicHash, dataHash));
// 	}

// 	function hashLogs(VmSafe.Log[] memory logs) internal pure returns (bytes32[] memory hashes) {
// 		uint256 len = logs.length;
// 		hashes = new bytes32[](len);
// 		for (uint256 i = 0; i < len; i++) {
// 			hashes[i] = hashLog(logs[i]);
// 		}
// 	}

// 	function setWatchedEvents(
// 		LogsContext memory self,
// 		bytes32[] memory watchedEventSignatures,
// 		function(VmSafe.Log memory) internal pure returns (string memory)[]
// 			memory watchedEventSerializers
// 	) internal pure returns (LogsContext memory) {
// 		self.watchedEventSignatures = watchedEventSignatures;
// 		self.watchedEventSerializers = watchedEventSerializers;
// 		return self;
// 	}

// 	function addWatchedEvent(
// 		LogsContext memory self,
// 		bytes32 topic0,
// 		function(VmSafe.Log memory) internal pure returns (string memory) toJson
// 	) internal pure returns (LogsContext memory) {
// 		uint256 len = self.watchedEventSignatures.length;
// 		bytes32[] memory watchedEventSignatures = new bytes32[](len + 1);
// 		function(VmSafe.Log memory) internal pure returns (string memory)[]
// 			memory watchedEventSerializers = new function(VmSafe.Log memory)
// 				internal
// 				pure
// 				returns (string memory)[](len + 1);

// 		for (uint256 i = 0; i < len; i++) {
// 			watchedEventSignatures[i] = self.watchedEventSignatures[i];
// 			watchedEventSerializers[i] = self.watchedEventSerializers[i];
// 		}
// 		watchedEventSignatures[len] = topic0;
// 		watchedEventSerializers[len] = toJson;
// 		self.watchedEventSignatures = watchedEventSignatures;
// 		self.watchedEventSerializers = watchedEventSerializers;
// 		return self;
// 	}

// 	function setExpectedLogs(
// 		LogsContext memory self,
// 		VmSafe.Log[] memory expectedLogs
// 	) internal pure returns (LogsContext memory) {
// 		self.expectedLogs = expectedLogs;
// 		self.expectedLogHashes = hashLogs(expectedLogs);
// 		return self;
// 	}

// 	function addExpectedLog(
// 		LogsContext memory self,
// 		VmSafe.Log memory expectedLog
// 	) internal pure returns (LogsContext memory) {
// 		bytes32 _logPtr;
// 		assembly {
// 			_logPtr := expectedLog
// 		}
// 		self.expectedLogs = LibArrayCast
// 			.cloneWithElement(self.expectedLogs.toMemoryPointer(), _logPtr)
// 			.toLogArray();
// 		self.expectedLogHashes = LibArrayCast
// 			.cloneWithElement(self.expectedLogHashes.toMemoryPointer(), hashLog(expectedLog))
// 			.toBytes32Array();
// 		return self;
// 	}

// 	function setEmittedLogs(
// 		LogsContext memory self,
// 		VmSafe.Log[] memory emittedLogs
// 	) internal pure returns (LogsContext memory) {
// 		self.emittedLogs = emittedLogs;
// 		self.emittedLogHashes = hashLogs(emittedLogs);
// 		return self;
// 	}

// 	function startRecording(LogsContext memory self) internal pure returns (LogsContext memory) {
// 		self.isRecording = true;
// 		asPureFn(recordLogs)();
// 		return self;
// 	}

// 	function stopRecording(LogsContext memory self) internal pure returns (LogsContext memory) {
// 		self.isRecording = false;
// 		VmSafe.Log[] memory emittedLogs = asPureFn(getRecordedLogs)();
// 		self.setEmittedLogs(emittedLogs);
// 		return self;
// 	}

// 	function resetLogs(LogsContext memory self) internal pure returns (LogsContext memory) {
// 		self.isRecording = false;
// 		self.expectedLogHashes = new bytes32[](0);
// 		self.expectedLogs = new VmSafe.Log[](0);
// 		self.emittedLogHashes = new bytes32[](0);
// 		self.emittedLogs = new VmSafe.Log[](0);
// 		return self;
// 	}

// 	function isWatchedEvent(
// 		VmSafe.Log memory log,
// 		LogsContext memory context
// 	) internal pure returns (bool) {
// 		bytes32 topic0 = log.topics[0];
// 		return context.watchedEventSignatures.includes(topic0);
// 	}

// 	/**
// 	 * @dev Checks that the next log matches the next expected transfer event.
// 	 *
// 	 * @param lastLogIndex The index of the last log that was checked
// 	 * @param expectedLogHash The expected event hash
// 	 * @param input The input to the reduce function
// 	 *
// 	 * @return nextLogIndex The index of the next log to check
// 	 */
// 	function checkNextWatchedLog(
// 		uint256 lastLogIndex,
// 		uint256 expectedLogHash,
// 		LogsContext memory context
// 	) internal returns (uint256 nextLogIndex) {
// 		// Get the index of the next watched event in the logs array
// 		int256 nextWatchedLogIndex = ArrayHelpers.findIndexFrom.asLogsFindIndex()(
// 			context.emittedLogs,
// 			isWatchedEvent,
// 			lastLogIndex
// 		);

// 		// Dump the events data and revert if there are no remaining transfer events
// 		if (nextWatchedLogIndex == -1) {
// 			vm.serializeUint('root', 'failingIndex', lastLogIndex - 1);
// 			vm.serializeBytes32('root', 'expectedLogHash', bytes32(expectedLogHash));
// 			dumpTransfers(input.context);
// 			revert('ExpectedEvents: transfer event not found - info written to fuzz_debug.json');
// 		}


// 		// Verify that the transfer event matches the expected event
// 		uint256 i = uint256(nextWatchedLogIndex);
// 		VmSafe.Log memory log = context.emittedLogs[i];
// 		require(
// 			hashLog(log) == bytes32(expectedLogHash),
// 			'ExpectedEvents: event hash does not match'
// 		);

// 		// Increment the log index for the next iteration
// 		return i + 1;
// 	}

// 	/**
// 	 * @dev Checks that the events emitted by the test match the expected
// 	 *      events.
// 	 *
// 	 * @param context The test context
// 	 */
// 	function checkExpectedTransferEvents(LogsContext memory context) internal {
// 		bytes32[] memory expectedLogHashes = context.expectations.expectedLogHashes;

// 		// For each expected event, verify that it matches the next log
// 		// in `logs` that has a topic0 matching one of the watched events.
// 		uint256 lastLogIndex = ArrayHelpers.reduceWithArg.asLogsReduce()(
// 			expectedLogHashes,
// 			checkNextTransferEvent, // function called for each item in expectedEvents
// 			0, // initial value for the reduce call, index 0
// 			context // 3rd argument given to checkNextTransferEvent
// 		);

// 		// Verify that there are no other watched events in the array
// 		int256 nextWatchedLogIndex = ArrayHelpers.findIndexFrom.asLogsFindIndex()(
// 			logs,
// 			isWatchedTransferEvent,
// 			lastLogIndex
// 		);

// 		if (nextWatchedLogIndex != -1) {
// 			dumpTransfers(context);
// 			revert('ExpectedEvents: too many watched transfer events - info written to fuzz_debug.json');
// 		}
// 	}
// }
