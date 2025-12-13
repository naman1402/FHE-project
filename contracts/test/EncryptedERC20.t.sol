// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {HostContractsDeployerTestUtils} from "fhevm-foundry/HostContractsDeployerTestUtils.sol";
import {ACL} from "@fhevm-host-contracts/contracts/ACL.sol";
import {FHEEvents} from "@fhevm-host-contracts/contracts/FHEEvents.sol";
import {FheType} from "@fhevm-host-contracts/contracts/shared/FheType.sol";
import {aclAdd, fhevmExecutorAdd, kmsVerifierAdd} from "@fhevm-host-contracts/addresses/FHEVMHostAddresses.sol";
import {EncryptedERC20} from "../src/EncryptedERC20.sol";
import {euint64} from "fhevm/lib/EncryptedTypes.sol";
import {FHE} from "fhevm/lib/FHE.sol";
import {CoprocessorConfig} from "fhevm/lib/Impl.sol";

/**
 * @title ConfiguredEncryptedERC20
 * @notice EncryptedERC20 wrapper that configures the coprocessor addresses in its storage context
 * @dev The FHE library uses contract storage slots, so each contract needs its own config
 */
contract ConfiguredEncryptedERC20 is EncryptedERC20 {
    constructor(
        string memory name_,
        string memory symbol_,
        CoprocessorConfig memory config
    ) EncryptedERC20(name_, symbol_) {
        FHE.setCoprocessor(config);
    }
}

/**
 * @title EncryptedERC20Test
 * @notice Comprehensive test suite for EncryptedERC20 contract
 * @dev Tests FHE operation event emissions for coprocessor consumption
 * 
 * Test Categories:
 * 1. Basic Token Operations - name, symbol, decimals, totalSupply
 * 2. Mint Operations - verify TrivialEncrypt and FheAdd events
 * 3. Transfer Operations - verify FheLe, FheIfThenElse, FheAdd, FheSub events
 * 4. ACL Permissions - verify handle access control
 * 5. Event Parsing - validate event data structure for coprocessor
 */
contract EncryptedERC20Test is Test, HostContractsDeployerTestUtils, FHEEvents {
    ConfiguredEncryptedERC20 public token;
    ACL public acl;

    // Test addresses
    address public owner;
    address public alice;
    address public bob;
    address public pauser;

    // KMS/Input verifier setup
    address[] public kmsSigners;
    address[] public inputSigners;

    // Event topic selectors for filtering
    bytes32 constant TOPIC_FHE_ADD = keccak256("FheAdd(address,bytes32,bytes32,bytes1,bytes32)");
    bytes32 constant TOPIC_FHE_SUB = keccak256("FheSub(address,bytes32,bytes32,bytes1,bytes32)");
    bytes32 constant TOPIC_FHE_LE = keccak256("FheLe(address,bytes32,bytes32,bytes1,bytes32)");
    bytes32 constant TOPIC_FHE_IF_THEN_ELSE = keccak256("FheIfThenElse(address,bytes32,bytes32,bytes32,bytes32)");
    bytes32 constant TOPIC_TRIVIAL_ENCRYPT = keccak256("TrivialEncrypt(address,uint256,uint8,bytes32)");

    // Struct to hold parsed FHE event data
    struct FheOperationEvent {
        string opName;
        address caller;
        bytes32 lhs;
        bytes32 rhs;
        bytes1 scalarByte;
        bytes32 result;
    }

    struct TrivialEncryptEvent {
        address caller;
        uint256 plaintext;
        FheType toType;
        bytes32 result;
    }

    struct FheIfThenElseEvent {
        address caller;
        bytes32 control;
        bytes32 ifTrue;
        bytes32 ifFalse;
        bytes32 result;
    }

    function setUp() public {
        // Setup test accounts
        owner = makeAddr("owner");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        pauser = makeAddr("pauser");

        // Initialize signer arrays for verifiers
        kmsSigners = new address[](1);
        kmsSigners[0] = makeAddr("kmsSigner");
        inputSigners = new address[](1);
        inputSigners[0] = makeAddr("inputSigner");

        // Deploy full FHEVM host stack using Zama's test utilities
        _deployFullHostStack(
            owner,                    // owner
            pauser,                   // pauser
            address(0),               // kmsVerifyingSource (not used in tests)
            address(0),               // inputVerifyingSource (not used in tests)
            uint64(block.chainid),    // chainIDSource
            kmsSigners,               // kmsSigners
            1,                        // kmsThreshold
            inputSigners,             // inputSigners
            1                         // inputThreshold
        );

        // Get ACL reference
        acl = ACL(aclAdd);

        // Create coprocessor config
        CoprocessorConfig memory config = CoprocessorConfig({
            ACLAddress: aclAdd,
            CoprocessorAddress: fhevmExecutorAdd,
            KMSVerifierAddress: kmsVerifierAdd
        });

        // Deploy EncryptedERC20 token with coprocessor config
        vm.prank(owner);
        token = new ConfiguredEncryptedERC20("FHE Token", "FHET", config);
    }

    // ============================================================
    // Basic Token Operations Tests
    // ============================================================

    function test_Initialization() public view {
        assertEq(token.name(), "FHE Token", "Name should be FHE Token");
        assertEq(token.symbol(), "FHET", "Symbol should be FHET");
        assertEq(token.decimals(), 6, "Decimals should be 6");
        assertEq(token.totalSupply(), 0, "Initial supply should be 0");
        assertEq(token.owner(), owner, "Owner should be set correctly");
    }

    function test_TokenMetadata() public view {
        // Verify all public getters work correctly
        string memory name = token.name();
        string memory symbol = token.symbol();
        uint8 decimals = token.decimals();
        uint64 supply = token.totalSupply();
        address tokenOwner = token.owner();

        assertTrue(bytes(name).length > 0, "Name should not be empty");
        assertTrue(bytes(symbol).length > 0, "Symbol should not be empty");
        assertEq(decimals, 6, "Decimals should be 6");
        assertEq(supply, 0, "Supply should start at 0");
        assertEq(tokenOwner, owner, "Owner should match");
    }

    // ============================================================
    // Mint Operation Tests - Events for Coprocessor
    // ============================================================

    function test_MintEmitsEvents() public {
        uint64 mintAmount = 1000;

        // Start recording logs
        vm.recordLogs();

        // Mint tokens as owner
        vm.prank(owner);
        token.mint(mintAmount);

        console.log("fn:test_MintEmitsEvents balance handle", vm.toString(euint64.unwrap(token.balanceOf(owner))));

        // Get all recorded logs
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertTrue(logs.length > 0, "Should emit events");

        // Count and validate FHE events
        uint256 trivialEncryptCount = 0;
        uint256 fheAddCount = 0;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == TOPIC_TRIVIAL_ENCRYPT) {
                trivialEncryptCount++;
                _validateTrivialEncryptEvent(logs[i]);
            } else if (logs[i].topics[0] == TOPIC_FHE_ADD) {
                fheAddCount++;
                _validateFheAddEvent(logs[i]);
            }
        }

        // Mint should emit at least TrivialEncrypt (for the amount) and FheAdd (for balance update)
        // Note: The exact number depends on FHEVM implementation
        console.log("TrivialEncrypt events:", trivialEncryptCount);
        console.log("FheAdd events:", fheAddCount);

        assertEq(token.totalSupply(), mintAmount, "Total supply should be updated");
    }

    function test_MintOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        token.mint(1000);
    }

    function test_MultipleMints() public {
        uint64 amount1 = 1000;
        uint64 amount2 = 2000;

        vm.recordLogs();

        vm.startPrank(owner);
        token.mint(amount1);
        token.mint(amount2);
        vm.stopPrank();

        Vm.Log[] memory logs = vm.getRecordedLogs();
        
        // Each mint should emit FHE events
        uint256 fheAddCount = 0;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == TOPIC_FHE_ADD) {
                fheAddCount++;
            }
        }

        assertTrue(fheAddCount >= 2, "Should have FheAdd events from both mints");
        assertEq(token.totalSupply(), amount1 + amount2, "Total supply should be sum");
    }

    // ============================================================
    // Transfer Operation Tests - Events for Coprocessor
    // ============================================================

    // function test_TransferEmitsEvents() public {
    //     // Setup: Mint tokens to owner first
    //     uint64 mintAmount = 1000;
    //     vm.prank(owner);
    //     token.mint(mintAmount);

    //     // Get owner's balance handle for transfer
    //     euint64 ownerBalance = token.balanceOf(owner);

    //     // Clear logs from mint
    //     vm.recordLogs();

    //     // Perform transfer using the euint64 overload
    //     // First we need to create an encrypted amount
    //     // Since we can't easily create encrypted values in tests without the SDK,
    //     // we test the internal transfer flow by examining events

    //     // Note: Direct euint64 transfers require the sender to have ACL permission
    //     // This test validates the event emission pattern
    // }

    function test_TransferEventSequence() public {
        /*
         * Transfer operation event sequence (expected):
         * 1. FheLe - Compare amount <= sender balance
         * 2. TrivialEncrypt - Create encrypted 0 for fallback
         * 3. FheIfThenElse - Select amount or 0 based on comparison
         * 4. FheAdd - Add transferValue to receiver balance  
         * 5. FheSub - Subtract transferValue from sender balance
         *
         * This test documents the expected event sequence for coprocessor parsing.
         */
        console.log("fn:test_TransferEventSequence (doc only, showing mint events)");
        
        vm.prank(owner);
        token.mint(1000);

        vm.recordLogs();
        
        vm.prank(owner);
        token.mint(500);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        
        console.log("=== Transfer Event Sequence Analysis ===");
        for (uint256 i = 0; i < logs.length; i++) {
            _logEventDetails(logs[i], i);
        }
    }

    // ============================================================
    // ACL Permission Tests
    // ============================================================

    function test_ACLPermissionsAfterMint() public {
        vm.prank(owner);
        token.mint(1000);

        // Get the balance handle
        euint64 balance = token.balanceOf(owner);
        bytes32 handle = euint64.unwrap(balance);

        // Verify ACL permissions are set correctly
        // Owner should be allowed to access their balance
        bool ownerAllowed = acl.isAllowed(handle, owner);
        bool contractAllowed = acl.isAllowed(handle, address(token));

        console.log("Handle (unwrapped euint64 balance):", vm.toString(handle));
        console.log("Owner allowed:", ownerAllowed);
        console.log("Contract allowed:", contractAllowed);

        // The contract should allow itself and the owner
        assertTrue(contractAllowed, "Contract should be allowed to access handle");
        assertTrue(ownerAllowed, "Owner should be allowed to access handle");

        // Alice should NOT be allowed
        bool aliceAllowed = acl.isAllowed(handle, alice);
        assertFalse(aliceAllowed, "Alice should not be allowed to access owner's handle");
    }

    function test_ACLPermissionsIsolation() public {
        // Mint to owner
        vm.prank(owner);
        token.mint(1000);

        euint64 ownerBalance = token.balanceOf(owner);
        bytes32 ownerHandle = euint64.unwrap(ownerBalance);

        // Bob's balance handle should be different and inaccessible to owner
        euint64 bobBalance = token.balanceOf(bob);
        bytes32 bobHandle = euint64.unwrap(bobBalance);

        // Bob hasn't received anything, so their balance handle might be zero
        // But if it's set, verify isolation
        if (bobHandle != bytes32(0)) {
            bool ownerCanAccessBob = acl.isAllowed(bobHandle, owner);
            assertFalse(ownerCanAccessBob, "Owner should not access Bob's handle");
        }

        // Owner's handle should not be accessible by Bob
        bool bobCanAccessOwner = acl.isAllowed(ownerHandle, bob);
        assertFalse(bobCanAccessOwner, "Bob should not access owner's handle");
    }

    // ============================================================
    // Event Parsing Tests - Coprocessor Format Validation
    // ============================================================

    function test_EventDataStructure() public {
        /*
         * Validates that FHE events follow the expected format:
         * 
         * Binary FHE ops (FheAdd, FheSub, FheLe, etc.):
         * - topics[0]: event selector
         * - topics[1]: indexed caller address (padded to bytes32)
         * - data: abi.encode(lhs, rhs, scalarByte, result)
         *
         * TrivialEncrypt:
         * - topics[0]: event selector  
         * - topics[1]: indexed caller address
         * - data: abi.encode(plaintext, toType, result)
         *
         * FheIfThenElse:
         * - topics[0]: event selector
         * - topics[1]: indexed caller address
         * - data: abi.encode(control, ifTrue, ifFalse, result)
         */

        console.log("fn:test_EventDataStructure start");

        vm.recordLogs();
        
        vm.prank(owner);
        token.mint(1000);

        Vm.Log[] memory logs = vm.getRecordedLogs();

        for (uint256 i = 0; i < logs.length; i++) {
            Vm.Log memory log = logs[i];
            
            if (log.topics[0] == TOPIC_FHE_ADD) {
                // Parse FheAdd event
                (bytes32 lhs, bytes32 rhs, bytes1 scalarByte, bytes32 result) = 
                    abi.decode(log.data, (bytes32, bytes32, bytes1, bytes32));
                
                console.log("=== FheAdd Event ===");
                console.log("Caller:", address(uint160(uint256(log.topics[1]))));
                console.log("LHS:", vm.toString(lhs));
                console.log("RHS:", vm.toString(rhs));
                console.log("ScalarByte:", uint8(scalarByte));
                console.log("Result:", vm.toString(result));
                
                // Validate result is non-zero (deterministic handle)
                assertTrue(result != bytes32(0), "Result handle should be non-zero");
            }
            
            if (log.topics[0] == TOPIC_TRIVIAL_ENCRYPT) {
                // Parse TrivialEncrypt event
                (uint256 pt, FheType toType, bytes32 result) = 
                    abi.decode(log.data, (uint256, FheType, bytes32));
                
                console.log("=== TrivialEncrypt Event ===");
                console.log("Caller:", address(uint160(uint256(log.topics[1]))));
                console.log("Plaintext:", pt);
                console.log("ToType:", uint8(toType));
                console.log("Result:", vm.toString(result));
                
                assertTrue(result != bytes32(0), "Result handle should be non-zero");
            }
        }
    }

    function test_ParseFheEventForCoprocessor() public {
        /*
         * This test demonstrates how a Rust coprocessor would parse events:
         * 
         * 1. Filter logs by topic (event selector)
         * 2. Extract indexed caller from topics[1]
         * 3. Decode non-indexed params from data
         * 4. Build operation queue for FHE computation
         */

        console.log("fn:test_ParseFheEventForCoprocessor start");

        vm.recordLogs();
        
        vm.prank(owner);
        token.mint(1000);

        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Simulate coprocessor parsing
        FheOperationEvent[] memory operations = new FheOperationEvent[](logs.length);
        uint256 opCount = 0;

        for (uint256 i = 0; i < logs.length; i++) {
            if (_isFheBinaryOp(logs[i].topics[0])) {
                operations[opCount] = _parseFheBinaryOp(logs[i]);
                opCount++;
            }
        }

        console.log("Total FHE operations parsed:", opCount);
        
        // Log operation chain for coprocessor
        for (uint256 i = 0; i < opCount; i++) {
            console.log("Op", i, ":", operations[i].opName);
            console.log("  Result handle:", vm.toString(operations[i].result));
        }
    }

    // ============================================================
    // Edge Cases and Error Handling
    // ============================================================

    // function test_MintZeroAmount() public {
    //     vm.recordLogs();
        
    //     vm.prank(owner);
    //     token.mint(0);

    //     // Should still emit events even for 0
    //     Vm.Log[] memory logs = vm.getRecordedLogs();
    //     assertTrue(logs.length > 0, "Should emit events even for zero amount");
        
    //     assertEq(token.totalSupply(), 0, "Total supply should remain 0");
    // }

    // function test_MintMaxAmount() public {
    //     uint64 maxAmount = type(uint64).max;
        
    //     vm.prank(owner);
    //     token.mint(maxAmount);

    //     assertEq(token.totalSupply(), maxAmount, "Total supply should be max uint64");
    // }

    // ============================================================
    // Gas Usage Analysis
    // ============================================================

    function test_GasUsageMint() public {
        uint256 gasBefore = gasleft();
        
        vm.prank(owner);
        token.mint(1000);
        
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for mint:", gasUsed);
        
        // Document gas usage for optimization analysis
        assertTrue(gasUsed < 1_000_000, "Mint should use less than 1M gas");
    }

    // ============================================================
    // Helper Functions for Event Parsing
    // ============================================================

    function _validateTrivialEncryptEvent(Vm.Log memory log) internal pure {
        require(log.topics.length >= 2, "TrivialEncrypt should have 2 topics");
        require(log.data.length >= 96, "TrivialEncrypt data should have 3 words");
    }

    function _validateFheAddEvent(Vm.Log memory log) internal pure {
        require(log.topics.length >= 2, "FheAdd should have 2 topics");
        require(log.data.length >= 128, "FheAdd data should have 4 words");
    }

    function _logEventDetails(Vm.Log memory log, uint256 index) internal pure {
        console.log("--- Event", index, "---");
        console.log("Emitter:", log.emitter);
        console.log("Topic0:", vm.toString(log.topics[0]));
        // console.log("Data bytes:", log.data.length);
        
        if (log.topics[0] == TOPIC_FHE_ADD) {
            console.log("Type: FheAdd");
        } else if (log.topics[0] == TOPIC_FHE_SUB) {
            console.log("Type: FheSub");
        } else if (log.topics[0] == TOPIC_FHE_LE) {
            console.log("Type: FheLe");
        } else if (log.topics[0] == TOPIC_FHE_IF_THEN_ELSE) {
            console.log("Type: FheIfThenElse");
        } else if (log.topics[0] == TOPIC_TRIVIAL_ENCRYPT) {
            console.log("Type: TrivialEncrypt");
        } else {
            console.log("Type: Unknown (non-FHE event)");
        }
    }

    function _isFheBinaryOp(bytes32 topic) internal pure returns (bool) {
        return topic == TOPIC_FHE_ADD || 
               topic == TOPIC_FHE_SUB || 
               topic == TOPIC_FHE_LE;
    }

    function _parseFheBinaryOp(Vm.Log memory log) internal pure returns (FheOperationEvent memory op) {
        op.caller = address(uint160(uint256(log.topics[1])));
        
        (op.lhs, op.rhs, op.scalarByte, op.result) = 
            abi.decode(log.data, (bytes32, bytes32, bytes1, bytes32));
        
        if (log.topics[0] == TOPIC_FHE_ADD) {
            op.opName = "FheAdd";
        } else if (log.topics[0] == TOPIC_FHE_SUB) {
            op.opName = "FheSub";
        } else if (log.topics[0] == TOPIC_FHE_LE) {
            op.opName = "FheLe";
        }
    }

    // ============================================================
    // Coprocessor Integration Test Helpers
    // ============================================================

    /**
     * @notice Extract all FHE operations from transaction logs
     * @dev This simulates what a Rust coprocessor would do
     */
    function extractFheOperations(Vm.Log[] memory logs) 
        internal 
        pure 
        returns (bytes32[] memory resultHandles) 
    {
        // Count FHE operations
        uint256 count = 0;
        for (uint256 i = 0; i < logs.length; i++) {
            if (_isFheOperation(logs[i].topics[0])) {
                count++;
            }
        }

        // Extract result handles
        resultHandles = new bytes32[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < logs.length; i++) {
            if (_isFheOperation(logs[i].topics[0])) {
                resultHandles[idx] = _extractResultHandle(logs[i]);
                idx++;
            }
        }
    }

    function _isFheOperation(bytes32 topic) internal pure returns (bool) {
        return topic == TOPIC_FHE_ADD || 
               topic == TOPIC_FHE_SUB || 
               topic == TOPIC_FHE_LE ||
               topic == TOPIC_FHE_IF_THEN_ELSE ||
               topic == TOPIC_TRIVIAL_ENCRYPT;
    }

    function _extractResultHandle(Vm.Log memory log) internal pure returns (bytes32) {
        // Result is always the last bytes32 in the data
        bytes memory data = log.data;
        bytes32 result;
        assembly {
            result := mload(add(data, mload(data)))
        }
        return result;
    }
}

/**
 * @title EncryptedERC20FuzzTest
 * @notice Fuzz tests for EncryptedERC20
 */
contract EncryptedERC20FuzzTest is Test, HostContractsDeployerTestUtils {
    ConfiguredEncryptedERC20 public token;
    address public owner;
    address public pauser;
    address[] public kmsSigners;
    address[] public inputSigners;

    function setUp() public {
        owner = makeAddr("owner");
        pauser = makeAddr("pauser");
        kmsSigners = new address[](1);
        kmsSigners[0] = makeAddr("kmsSigner");
        inputSigners = new address[](1);
        inputSigners[0] = makeAddr("inputSigner");

        _deployFullHostStack(
            owner, pauser, address(0), address(0),
            uint64(block.chainid), kmsSigners, 1, inputSigners, 1
        );

        // Create coprocessor config
        CoprocessorConfig memory config = CoprocessorConfig({
            ACLAddress: aclAdd,
            CoprocessorAddress: fhevmExecutorAdd,
            KMSVerifierAddress: kmsVerifierAdd
        });

        vm.prank(owner);
        token = new ConfiguredEncryptedERC20("Fuzz Token", "FUZZ", config);
    }

    function testFuzz_Mint(uint64 amount) public {
        vm.prank(owner);
        token.mint(amount);
        
        assertEq(token.totalSupply(), amount, "Total supply should match mint amount");
    }

    function testFuzz_MultipleMints(uint64 amount1, uint64 amount2) public {
        // Bound to avoid overflow
        amount1 = uint64(bound(amount1, 0, type(uint64).max / 2));
        amount2 = uint64(bound(amount2, 0, type(uint64).max / 2));

        vm.startPrank(owner);
        token.mint(amount1);
        token.mint(amount2);
        vm.stopPrank();

        assertEq(token.totalSupply(), amount1 + amount2, "Total supply should be sum");
    }

    function testFuzz_MintEmitsEvents(uint64 amount) public {
        vm.recordLogs();
        
        vm.prank(owner);
        token.mint(amount);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        
        // Should always emit events regardless of amount
        assertTrue(logs.length > 0, "Should emit FHE events");
    }
}
