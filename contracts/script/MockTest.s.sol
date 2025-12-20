// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {MockFHEVMExecutor} from "../src/mocks/MockFHEVMExecutor.sol";
import {MockACL} from "../src/mocks/MockACL.sol";

/**
 * @title DeployMocks
 * @notice Deploy mock FHE infrastructure for coprocessor event testing
 * @dev Mocks emit real FHE events without requiring deterministic addresses
 */
contract DeployMocks is Script {
    function run() external returns (address executor, address acl) {
        uint256 pk = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(pk);

        console.log("\n=== Deploying Mock FHE Infrastructure ===");

        vm.startBroadcast(pk);

        MockACL mockAcl = new MockACL();
        mockAcl.initialize(deployer);

        MockFHEVMExecutor mockExecutor = new MockFHEVMExecutor();
        mockExecutor.initialize(deployer, address(mockAcl));

        mockAcl.setFHEVMExecutor(address(mockExecutor));

        vm.stopBroadcast();

        console.log("  MockACL:", address(mockAcl));
        console.log("  MockFHEVMExecutor:", address(mockExecutor));
        console.log("\nUpdate coprocessor/.env:");
        console.log("  TFHE_EXECUTOR_ADDRESS=%s", address(mockExecutor));
        console.log("  ACL_ADDRESS=%s", address(mockAcl));

        return (address(mockExecutor), address(mockAcl));
    }
}

/**
 * @title GenerateEvents
 * @notice Generate FHE events for coprocessor testing
 * @dev Calls mock executor to emit TrivialEncrypt, FheAdd, FheMul, FheLe, FheIfThenElse events
 * 
 * Usage:
 *   EXECUTOR=0x... forge script script/MockTest.s.sol:GenerateEvents --rpc-url http://127.0.0.1:8545 --broadcast
 */
contract GenerateEvents is Script {
    function run() external {
        address executorAddr = vm.envAddress("EXECUTOR");
        uint256 pk = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));

        MockFHEVMExecutor executor = MockFHEVMExecutor(executorAddr);

        console.log("\n=== Generating FHE Events ===");
        console.log("Executor:", executorAddr);

        vm.startBroadcast(pk);

        // Simulate mint: TrivialEncrypt + FheAdd
        bytes32 h1 = executor.trivialEncrypt(0, 5);      // euint64 type = 5
        bytes32 h2 = executor.trivialEncrypt(1000000, 5);
        bytes32 h3 = executor.fheAdd(h1, h2, bytes1(0x00));

        // Simulate comparison + conditional
        bytes32 h4 = executor.trivialEncrypt(500000, 5);
        bytes32 cmp = executor.fheLe(h4, h3, bytes1(0x00));
        bytes32 h5 = executor.fheIfThenElse(cmp, h4, h1);

        // Arithmetic ops
        bytes32 h6 = executor.fheSub(h3, h5, bytes1(0x00));
        bytes32 h7 = executor.fheMul(h4, h2, bytes1(0x00));

        vm.stopBroadcast();

        console.log("\nGenerated 8 FHE events:");
        console.log("  3x TrivialEncrypt, 2x FheAdd, 1x FheLe, 1x FheIfThenElse, 1x FheSub, 1x FheMul");
        console.log("\nCheck coprocessor output for captured events.");
    }
}

/**
 * @title E2EMockTest
 * @notice Complete E2E test: deploy mocks + generate events in one transaction
 * @dev Use this for quick coprocessor testing
 * 
 * Usage:
 *   forge script script/MockTest.s.sol:E2EMockTest --rpc-url http://127.0.0.1:8545 --broadcast
 */
contract E2EMockTest is Script {
    function run() external {
        uint256 pk = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(pk);

        console.log("\n================================================================");
        console.log("       FHE COPROCESSOR E2E TEST (Mock Contracts)");
        console.log("================================================================\n");

        vm.startBroadcast(pk);

        // Deploy mocks
        MockACL acl = new MockACL();
        acl.initialize(deployer);

        MockFHEVMExecutor executor = new MockFHEVMExecutor();
        executor.initialize(deployer, address(acl));
        acl.setFHEVMExecutor(address(executor));

        console.log("Deployed:");
        console.log("  MockACL:", address(acl));
        console.log("  MockFHEVMExecutor:", address(executor));

        // Generate events
        console.log("\nGenerating FHE events...");

        // Mint simulation
        bytes32 zero = executor.trivialEncrypt(0, 5);
        bytes32 amt1 = executor.trivialEncrypt(1000000, 5);
        bytes32 bal1 = executor.fheAdd(zero, amt1, bytes1(0x00));
        acl.allow(bal1, address(executor));
        acl.allow(bal1, deployer);

        bytes32 amt2 = executor.trivialEncrypt(500000, 5);
        bytes32 bal2 = executor.fheAdd(bal1, amt2, bytes1(0x00));

        // Transfer simulation
        bytes32 txAmt = executor.trivialEncrypt(100000, 5);
        bytes32 canTx = executor.fheLe(txAmt, bal2, bytes1(0x00));
        bytes32 actual = executor.fheIfThenElse(canTx, txAmt, zero);
        bytes32 newFrom = executor.fheSub(bal2, actual, bytes1(0x00));
        bytes32 newTo = executor.fheAdd(zero, actual, bytes1(0x00));

        vm.stopBroadcast();

        console.log("\n================================================================");
        console.log("Events generated! Update coprocessor/.env:");
        console.log("  WEBSOCKET_URL=ws://127.0.0.1:8545");
        console.log("  TFHE_EXECUTOR_ADDRESS=%s", address(executor));
        console.log("  ACL_ADDRESS=%s", address(acl));
        console.log("\nThen run: cd coprocessor && cargo run");
        console.log("================================================================\n");
    }
}
