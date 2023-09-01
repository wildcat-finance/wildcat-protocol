// // SPDX-License-Identifier: MIT
// pragma solidity >=0.8.17;

// import { VmSafe } from "forge-std/Vm.sol";
// import { vm } from "./VmUtils";
// import { malloc, MemoryPointer } from "sol-utils/ir-only/MemoryPointer.sol";
// import { ArrayHelpers } from "sol-utils/ir-only/ArrayHelpers.sol";

// using { hashLog } for Log global;
// using LibLogsContext for LogsContext global;
// using LibLogsContextTypeCasts for MemoryPointer;
// using LibLogsContextTypeCasts for Log[];
// using LibLogsContextTypeCasts for Log;
// using ArrayHelpers for MemoryPointer;

// struct LogsContext {
//     bool isRecording;
//     bytes32[] watchedEventSignatures;
//     function(Log memory)
//         internal
//         pure
//         returns (string memory)[] watchedEventSerializers;
//     Log[] expectedLogs;
//     bytes32[] expectedLogHashes;
//     Log[] emittedLogs;
//     bytes32[] emittedLogHashes;
// }

// struct Log {
//     bytes32[] topics;
//     bytes data;
//     address emitter;
// }

// function hashLog(Log memory log) pure returns (bytes32) {
//     bytes32 topicHash = keccak256(abi.encodePacked(log.topics));
//     bytes32 dataHash = keccak256(log.data);
//     return keccak256(abi.encodePacked(topicHash, dataHash));
// }

// library LibLogsContext {
//     using LibLogsContextTypeCasts for *;
//     using LibLogsContext for *;

//     function asHashLogMapCallback(
//         function(Log memory) internal pure returns (bytes32) _fn
//     )
//         internal
//         pure
//         returns (function(uint256) internal pure returns (uint256) fn)
//     {
//         assembly {
//             fn := _fn
//         }
//     }

//     function hashLogs(
//         Log[] memory logs
//     ) internal pure returns (bytes32[] memory) {
//         return
//             ArrayHelpers
//                 .map(logs.toMemoryPointer(), hashLog.asHashLogMapCallback())
//                 .toBytes32Array();
//     }

//     function recordLogs() internal {
//         vm.recordLogs();
//     }

//     function getRecordedLogs() internal pure returns (Log[] memory logs) {
//         return _getRecordedLogs.asPureFn()();
//     }

//     function setWatchedEvents(
//         LogsContext memory self,
//         bytes32[] memory watchedEventSignatures,
//         function(Log memory) internal pure returns (string memory)[]
//             memory watchedEventSerializers
//     ) internal pure returns (LogsContext memory) {
//         self.watchedEventSignatures = watchedEventSignatures;
//         self.watchedEventSerializers = watchedEventSerializers;
//         return self;
//     }

//     function addWatchedEvent(
//         LogsContext memory self,
//         bytes32 topic0,
//         function(Log memory) internal pure returns (string memory) toJson
//     ) internal pure returns (LogsContext memory) {
//         self.watchedEventSerializers = ArrayHelpers
//             .cloneAndPush
//             .asPushEventSerializer()(self.watchedEventSerializers, toJson);
//         self.watchedEventSignatures = ArrayHelpers.cloneAndPush.asPushBytes32()(
//             self.watchedEventSignatures,
//             topic0
//         );
//         return self;
//     }

//     function setExpectedLogs(
//         LogsContext memory self,
//         Log[] memory expectedLogs
//     ) internal pure returns (LogsContext memory) {
//         self.expectedLogs = expectedLogs;
//         self.expectedLogHashes = hashLogs(expectedLogs);
//         return self;
//     }

//     function addExpectedLog(
//         LogsContext memory self,
//         Log memory expectedLog
//     ) internal pure returns (LogsContext memory) {
//         self.expectedLogs = ArrayHelpers.cloneAndPush.asPushLog()(
//             self.expectedLogs,
//             expectedLog
//         );
//         self.expectedLogHashes = ArrayHelpers.cloneAndPush.asPushBytes32()(
//             self.expectedLogHashes,
//             hashLog(expectedLog)
//         );
//         return self;
//     }

//     function setEmittedLogs(
//         LogsContext memory self,
//         Log[] memory emittedLogs
//     ) internal pure returns (LogsContext memory) {
//         self.emittedLogs = emittedLogs;
//         self.emittedLogHashes = hashLogs(emittedLogs);
//         return self;
//     }

//     function startRecording(
//         LogsContext memory self
//     ) internal pure returns (LogsContext memory) {
//         if (self.isRecording) {
//             return self;
//         }
//         self.isRecording = true;
//         recordLogs.asPureFn()();
//         return self;
//     }

//     function stopRecording(
//         LogsContext memory self
//     ) internal pure returns (LogsContext memory) {
//         if (!self.isRecording) {
//             return self;
//         }
//         self.isRecording = false;
//         Log[] memory emittedLogs = getRecordedLogs.asPureFn()();
//         self.setEmittedLogs(emittedLogs);
//         return self;
//     }

//     function reset(
//         LogsContext memory self
//     ) internal pure returns (LogsContext memory) {
//         self.isRecording = false;
//         self.expectedLogHashes = new bytes32[](0);
//         self.expectedLogs = new Log[](0);
//         self.emittedLogHashes = new bytes32[](0);
//         self.emittedLogs = new Log[](0);
//         return self;
//     }

//     /**
//      * @dev Predicate for find
//      */
//     function isWatchedEvent(
//         Log memory log,
//         LogsContext memory context
//     ) internal pure returns (bool) {
//         bytes32 topic0 = log.topics[0];
//         return
//             context.watchedEventSignatures.toMemoryPointer().includes(
//                 uint256(topic0)
//             );
//     }

//     /**
//      * @dev Checks that the next log matches the next expected transfer event.
//      *
//      * @param lastLogIndex The index of the last log that was checked
//      * @param expectedLogHash The expected event hash
//      * @param context The input to the reduce function
//      *
//      * @return nextLogIndex The index of the next log to check
//      */
//     function checkNextWatchedLog(
//         uint256 lastLogIndex,
//         uint256 expectedLogHash,
//         LogsContext memory context
//     ) internal returns (uint256 nextLogIndex) {
//         // Get the index of the next watched event in the logs array
//         int256 nextWatchedLogIndex = ArrayHelpers
//             .findIndexFromWithArg
//             .asLogsFindIndex()(
//                 context.emittedLogs,
//                 isWatchedEvent,
//                 lastLogIndex,
//                 context
//             );

//         // Dump the events data and revert if there are no remaining transfer events
//         if (nextWatchedLogIndex == -1) {
//             // vm.serializeUint("root", "failingIndex", lastLogIndex - 1);
//             // vm.serializeBytes32(
//             //     "root",
//             //     "expectedLogHash",
//             //     bytes32(expectedLogHash)
//             // );
//             // dumpTransfers(input.context);
//             revert(
//                 "ExpectedEvents: event not found - info written to fuzz_debug.json"
//             );
//         }

//         // Verify that the transfer event matches the expected event
//         uint256 i = uint256(nextWatchedLogIndex);
//         Log memory log = context.emittedLogs[i];
//         require(
//             hashLog(log) == bytes32(expectedLogHash),
//             "ExpectedEvents: event hash does not match"
//         );

//         // Increment the log index for the next iteration
//         return i + 1;
//     }

//     /**
//      * @dev Checks that the events emitted by the test match the expected
//      *      events.
//      *
//      * @param context The test context
//      */
//     function checkExpectedEvents(LogsContext memory context) internal {
//         context.stopRecording(self);
//         bytes32[] memory expectedLogHashes = context.expectedLogHashes;

//         // For each expected event, verify that it matches the next log
//         // in `logs` that has a topic0 matching one of the watched events.
//         uint256 lastLogIndex = ArrayHelpers.reduceWithArg.asLogsReduce()(
//             expectedLogHashes,
//             checkNextWatchedLog, // function called for each item in expectedLogs
//             0, // initial value for the reduce call, index 0
//             context // 3rd argument given to checkNextWatchedLog
//         );

//         // Verify that there are no other watched events in the array
//         int256 nextWatchedLogIndex = ArrayHelpers
//             .findIndexFromWithArg
//             .asLogsFindIndex()(
//                 context.emittedLogs,
//                 isWatchedEvent,
//                 lastLogIndex,
//                 context
//             );

//         if (nextWatchedLogIndex != -1) {
//             // dumpTransfers(context);
//             revert("ExpectedEvents: too many watched events");
//         }
//     }

//     function _getRecordedLogs() internal returns (Log[] memory logs) {
//         VmSafe.Log[] memory vmLogs = vm.getRecordedLogs();
//         assembly {
//             logs := vmLogs
//         }
//     }
// }

// library LibLogsContextTypeCasts {
//     function asPureFn(
//         function() internal _fn
//     ) internal pure returns (function() internal pure fn) {
//         assembly {
//             fn := _fn
//         }
//     }

//     function asPureFn(
//         function() internal returns (Log[] memory) _fn
//     )
//         internal
//         pure
//         returns (function() internal pure returns (Log[] memory) fn)
//     {
//         assembly {
//             fn := _fn
//         }
//     }

//     function toMemoryPointer(
//         bytes32[] memory array
//     ) internal pure returns (MemoryPointer ptr) {
//         assembly {
//             ptr := array
//         }
//     }

//     function toMemoryPointer(
//         Log[] memory array
//     ) internal pure returns (MemoryPointer ptr) {
//         assembly {
//             ptr := array
//         }
//     }

//     function toLogArray(
//         MemoryPointer ptr
//     ) internal pure returns (Log[] memory array) {
//         assembly {
//             array := ptr
//         }
//     }

//     function toBytes32Array(
//         MemoryPointer ptr
//     ) internal pure returns (bytes32[] memory array) {
//         assembly {
//             array := ptr
//         }
//     }

//     function toLog(MemoryPointer ptr) internal pure returns (Log memory log) {
//         assembly {
//             log := ptr
//         }
//     }

//     function asPushLog(
//         function(MemoryPointer, uint256)
//             internal
//             pure
//             returns (MemoryPointer) _fn
//     )
//         internal
//         pure
//         returns (
//             function(Log[] memory, Log memory)
//                 internal
//                 pure
//                 returns (Log[] memory) fn
//         )
//     {
//         assembly {
//             fn := _fn
//         }
//     }

//     function asPushBytes32(
//         function(MemoryPointer, uint256)
//             internal
//             pure
//             returns (MemoryPointer) _fn
//     )
//         internal
//         pure
//         returns (
//             function(bytes32[] memory, bytes32)
//                 internal
//                 pure
//                 returns (bytes32[] memory) fn
//         )
//     {
//         assembly {
//             fn := _fn
//         }
//     }

//     function asPushEventSerializer(
//         function(MemoryPointer, uint256)
//             internal
//             pure
//             returns (MemoryPointer) _fn
//     )
//         internal
//         pure
//         returns (
//             function(
//                 function(Log memory) internal pure returns (string memory)[]
//                     memory,
//                 function(Log memory) internal pure returns (string memory)
//             )
//                 internal
//                 pure
//                 returns (
//                     function(Log memory) internal pure returns (string memory)[]
//                         memory
//                 ) fn
//         )
//     {
//         assembly {
//             fn := _fn
//         }
//     }

//     function asLogsFindIndex(
//         function(
//             MemoryPointer,
//             function(MemoryPointer, MemoryPointer) internal pure returns (bool),
//             uint256,
//             MemoryPointer
//         ) internal pure returns (int256) fnIn
//     )
//         internal
//         pure
//         returns (
//             function(
//                 Log[] memory,
//                 function(Log memory, LogsContext memory)
//                     internal
//                     pure
//                     returns (bool),
//                 uint256,
//                 LogsContext memory
//             ) internal pure returns (int256) fnOut
//         )
//     {
//         assembly {
//             fnOut := fnIn
//         }
//     }

//     function asLogsReduce(
//         function(
//             MemoryPointer,
//             function(uint256, uint256, MemoryPointer)
//                 internal
//                 returns (uint256),
//             uint256,
//             MemoryPointer
//         ) internal returns (uint256) fnIn
//     )
//         internal
//         pure
//         returns (
//             function(
//                 bytes32[] memory,
//                 function(uint256, uint256, LogsContext memory)
//                     internal
//                     returns (uint256),
//                 uint256,
//                 LogsContext memory
//             ) internal returns (uint256) fnOut
//         )
//     {
//         assembly {
//             fnOut := fnIn
//         }
//     }
// }
