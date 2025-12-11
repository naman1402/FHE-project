// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ACL} from "fhevm-host/ACL.sol";
import {FHEVMExecutor} from "fhevm-host/FHEVMExecutor.sol";
import {KMSVerifier} from "fhevm-host/KMSVerifier.sol";
import {InputVerifier} from "fhevm-host/InputVerifier.sol";
import {HCULimit} from "fhevm-host/HCULimit.sol";
import {PauserSet} from "fhevm-host/immutable/PauserSet.sol";
import {EmptyUUPSProxy} from "fhevm-host/emptyProxy/EmptyUUPSProxy.sol";
import {EmptyUUPSProxyACL} from "fhevm-host/emptyProxyACL/EmptyUUPSProxyACL.sol";

import {
    aclAdd,
    fhevmExecutorAdd,
    kmsVerifierAdd,
    inputVerifierAdd,
    hcuLimitAdd,
    pauserSetAdd
} from "@fhevm-host-contracts/addresses/FHEVMHostAddresses.sol";

/**
 * @dev Deployable proxy wrapper - needed so deployCodeTo can load locally compiled bytecode
 */
contract DeployableERC1967Proxy is ERC1967Proxy {
    constructor(address implementation, bytes memory data) ERC1967Proxy(implementation, data) {}
}

/**
 * @title DeployInfra
 * @notice Foundry deployment script for Zama FHEVM host infrastructure on Anvil
 * @dev This script deploys all core FHEVM infrastructure contracts to deterministic
 *      addresses as defined in FHEVMHostAddresses.sol.
 *
 * IMPORTANT: This script uses Foundry cheatcodes (deployCodeTo, etch, prank) which
 * ONLY work on Anvil/local chains. For production deployment, use the official
 * Zama deployment process via Hardhat.
 *
 * The script deploys contracts to these deterministic addresses:
 *   - ACL:           0x339EcE85B9E11a3A3AA557582784a15d7F82AAf2
 *   - FHEVMExecutor: 0x05fD9B5EFE0a996095f42Ed7e77c390810CF660c
 *   - KMSVerifier:   0x12B064FB845C1cc05e9493856a1D637a73e944bE
 *   - InputVerifier: 0x3a2DA6f1daE9eF988B48d9CF27523FA31a8eBE50
 *   - HCULimit:      0x3De04EecBC93c87Dc922F71E98a6bD9259E0aD93
 *   - PauserSet:     0x4b7Ac2d0e8fC9a6F2B1BcE0fE5DcA5D8C9E6F7A8
 */
contract DeployInfra is Script, Test {
    // =========================================================================
    // Implementation addresses (set during deployment)
    // =========================================================================

    address public aclImplementation;
    address public fhevmExecutorImplementation;
    address public kmsVerifierImplementation;
    address public inputVerifierImplementation;
    address public hcuLimitImplementation;

    // =========================================================================
    // Configuration
    // =========================================================================

    /// @notice Deployer/owner address
    address public owner;

    /// @notice Pauser address
    address public pauser;

    /// @notice KMS signers for decryption verification
    address[] public kmsSigners;
    uint256 public kmsThreshold;

    /// @notice Coprocessor signers for input verification
    address[] public coprocessorSigners;
    uint256 public coprocessorThreshold;

    /// @notice Gateway chain ID for cross-chain EIP-712 verification
    uint64 public gatewayChainId;

    // =========================================================================
    // Main deployment function
    // =========================================================================

    function run() external {
        _loadConfiguration();
        _logConfiguration();

        console.log("\n========================================");
        console.log("FHEVM Infrastructure Deployment (Anvil)");
        console.log("========================================\n");

        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        vm.startBroadcast(deployerPrivateKey);

        // Deploy in dependency order
        _deployACL();
        _deployPauserSet();
        _deployFHEVMExecutor();
        _deployHCULimit();
        _deployKMSVerifier();
        _deployInputVerifier();

        // Configure pauser
        _configurePauserSet();

        vm.stopBroadcast();

        // Verify wiring
        _verifyDeployment();

        // Output summary
        _logDeploymentSummary();
    }

    // =========================================================================
    // Configuration
    // =========================================================================

    function _loadConfiguration() internal {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        owner = vm.addr(deployerPrivateKey);
        pauser = vm.envOr("PAUSER_ADDRESS", owner);
        gatewayChainId = uint64(vm.envOr("GATEWAY_CHAIN_ID", uint256(block.chainid)));

        // KMS signer (defaults to deployer for local testing)
        address kmsSigner = vm.envOr("KMS_SIGNER_ADDRESS", owner);
        kmsSigners = new address[](1);
        kmsSigners[0] = kmsSigner;
        kmsThreshold = 1;

        // Coprocessor signer (defaults to KMS signer)
        address coprocessorSigner = vm.envOr("COPROCESSOR_SIGNER_ADDRESS", kmsSigner);
        coprocessorSigners = new address[](1);
        coprocessorSigners[0] = coprocessorSigner;
        coprocessorThreshold = 1;
    }

    function _logConfiguration() internal view {
        console.log("Configuration:");
        console.log("  Owner:", owner);
        console.log("  Pauser:", pauser);
        console.log("  Gateway Chain ID:", gatewayChainId);
        console.log("  KMS Signer:", kmsSigners[0]);
        console.log("  Coprocessor Signer:", coprocessorSigners[0]);
    }

    // =========================================================================
    // Contract Deployment Functions
    // =========================================================================

    /**
     * @notice Deploy ACL to deterministic address using deployCodeTo
     */
    function _deployACL() internal {
        console.log("[1/6] Deploying ACL to", aclAdd);
        address emptyProxyImpl = address(new EmptyUUPSProxyACL());

        deployCodeTo(
            "DeployInfra.s.sol:DeployableERC1967Proxy",
            abi.encode(emptyProxyImpl, abi.encodeCall(EmptyUUPSProxyACL.initialize, (owner))),
            aclAdd
        );
        vm.label(aclAdd, "ACL Proxy");

        // Deploy ACL implementation
        aclImplementation = address(new ACL());
        vm.label(aclImplementation, "ACL Implementation");

        // Upgrade proxy to ACL (already broadcasting as owner)
        EmptyUUPSProxyACL(aclAdd).upgradeToAndCall(
            aclImplementation,
            abi.encodeCall(ACL.initializeFromEmptyProxy, ())
        );

        console.log("       ACL deployed! Implementation:", aclImplementation);
    }

    /**
     * @notice Deploy PauserSet to deterministic address using etch
     * @dev PauserSet is immutable (no proxy) so we use vm.etch
     */
    function _deployPauserSet() internal {
        console.log("[2/6] Deploying PauserSet to", pauserSetAdd);
        PauserSet pauserSetImpl = new PauserSet();
        vm.etch(pauserSetAdd, address(pauserSetImpl).code);
        vm.label(pauserSetAdd, "PauserSet");
        console.log("       PauserSet deployed!");
    }

    /**
     * @notice Deploy FHEVMExecutor to deterministic address
     */
    function _deployFHEVMExecutor() internal {
        console.log("[3/6] Deploying FHEVMExecutor to", fhevmExecutorAdd);

        // Deploy empty proxy implementation
        address emptyProxyImpl = address(new EmptyUUPSProxy());

        // Deploy proxy to deterministic address
        deployCodeTo(
            "DeployInfra.s.sol:DeployableERC1967Proxy",
            abi.encode(emptyProxyImpl, abi.encodeCall(EmptyUUPSProxy.initialize, ())),
            fhevmExecutorAdd
        );
        vm.label(fhevmExecutorAdd, "FHEVMExecutor Proxy");

        // Deploy implementation
        fhevmExecutorImplementation = address(new FHEVMExecutor());
        vm.label(fhevmExecutorImplementation, "FHEVMExecutor Implementation");

        // Upgrade proxy (already broadcasting as owner)
        EmptyUUPSProxy(fhevmExecutorAdd).upgradeToAndCall(
            fhevmExecutorImplementation,
            abi.encodeCall(FHEVMExecutor.initializeFromEmptyProxy, ())
        );

        console.log("       FHEVMExecutor deployed! Implementation:", fhevmExecutorImplementation);
    }

    /**
     * @notice Deploy HCULimit to deterministic address
     */
    function _deployHCULimit() internal {
        console.log("[4/6] Deploying HCULimit to", hcuLimitAdd);

        // Deploy empty proxy implementation
        address emptyProxyImpl = address(new EmptyUUPSProxy());

        // Deploy proxy to deterministic address
        deployCodeTo(
            "DeployInfra.s.sol:DeployableERC1967Proxy",
            abi.encode(emptyProxyImpl, abi.encodeCall(EmptyUUPSProxy.initialize, ())),
            hcuLimitAdd
        );
        vm.label(hcuLimitAdd, "HCULimit Proxy");

        // Deploy implementation
        hcuLimitImplementation = address(new HCULimit());
        vm.label(hcuLimitImplementation, "HCULimit Implementation");

        // Upgrade proxy (already broadcasting as owner)
        EmptyUUPSProxy(hcuLimitAdd).upgradeToAndCall(
            hcuLimitImplementation,
            abi.encodeCall(HCULimit.initializeFromEmptyProxy, ())
        );

        console.log("       HCULimit deployed! Implementation:", hcuLimitImplementation);
    }

    /**
     * @notice Deploy KMSVerifier to deterministic address
     */
    function _deployKMSVerifier() internal {
        console.log("[5/6] Deploying KMSVerifier to", kmsVerifierAdd);

        // Deploy empty proxy implementation
        address emptyProxyImpl = address(new EmptyUUPSProxy());

        // Deploy proxy to deterministic address
        deployCodeTo(
            "DeployInfra.s.sol:DeployableERC1967Proxy",
            abi.encode(emptyProxyImpl, abi.encodeCall(EmptyUUPSProxy.initialize, ())),
            kmsVerifierAdd
        );
        vm.label(kmsVerifierAdd, "KMSVerifier Proxy");

        // Deploy implementation
        kmsVerifierImplementation = address(new KMSVerifier());
        vm.label(kmsVerifierImplementation, "KMSVerifier Implementation");

        // For local testing, verifyingContractSource can be address(0)
        address verifyingContractSource = vm.envOr("KMS_VERIFYING_CONTRACT", address(0));

        // Upgrade proxy with KMS configuration (already broadcasting as owner)
        EmptyUUPSProxy(kmsVerifierAdd).upgradeToAndCall(
            kmsVerifierImplementation,
            abi.encodeCall(
                KMSVerifier.initializeFromEmptyProxy,
                (verifyingContractSource, gatewayChainId, kmsSigners, kmsThreshold)
            )
        );

        console.log("       KMSVerifier deployed! Implementation:", kmsVerifierImplementation);
    }

    /**
     * @notice Deploy InputVerifier to deterministic address
     */
    function _deployInputVerifier() internal {
        console.log("[6/6] Deploying InputVerifier to", inputVerifierAdd);

        // Deploy empty proxy implementation
        address emptyProxyImpl = address(new EmptyUUPSProxy());

        // Deploy proxy to deterministic address
        deployCodeTo(
            "DeployInfra.s.sol:DeployableERC1967Proxy",
            abi.encode(emptyProxyImpl, abi.encodeCall(EmptyUUPSProxy.initialize, ())),
            inputVerifierAdd
        );
        vm.label(inputVerifierAdd, "InputVerifier Proxy");

        // Deploy implementation
        inputVerifierImplementation = address(new InputVerifier());
        vm.label(inputVerifierImplementation, "InputVerifier Implementation");

        // For local testing, verifyingContractSource can be address(0)
        address verifyingContractSource = vm.envOr("INPUT_VERIFYING_CONTRACT", address(0));

        // Upgrade proxy with coprocessor configuration (already broadcasting as owner)
        EmptyUUPSProxy(inputVerifierAdd).upgradeToAndCall(
            inputVerifierImplementation,
            abi.encodeCall(
                InputVerifier.initializeFromEmptyProxy,
                (verifyingContractSource, gatewayChainId, coprocessorSigners, coprocessorThreshold)
            )
        );

        console.log("       InputVerifier deployed! Implementation:", inputVerifierImplementation);
    }

    /**
     * @notice Add pauser to PauserSet
     */
    function _configurePauserSet() internal {
        console.log("\nConfiguring PauserSet...");
        // Already broadcasting as owner
        PauserSet(pauserSetAdd).addPauser(pauser);
        console.log("  Added pauser:", pauser);
    }

    // =========================================================================
    // Verification
    // =========================================================================

    function _verifyDeployment() internal view {
        console.log("\nVerifying deployment...");

        FHEVMExecutor executor = FHEVMExecutor(fhevmExecutorAdd);
        ACL acl = ACL(aclAdd);
        KMSVerifier kmsVerifier = KMSVerifier(kmsVerifierAdd);
        InputVerifier inputVerifier = InputVerifier(inputVerifierAdd);

        // Verify FHEVMExecutor wiring
        require(executor.getACLAddress() == aclAdd, "FHEVMExecutor: ACL address mismatch");
        require(executor.getHCULimitAddress() == hcuLimitAdd, "FHEVMExecutor: HCULimit address mismatch");
        console.log("  FHEVMExecutor wiring: OK");

        // Verify ACL wiring
        require(acl.getPauserSetAddress() == pauserSetAdd, "ACL: PauserSet address mismatch");
        console.log("  ACL wiring: OK");

        // Verify KMSVerifier config
        require(kmsVerifier.getThreshold() == kmsThreshold, "KMSVerifier: threshold mismatch");
        console.log("  KMSVerifier config: OK");

        // Verify InputVerifier config
        require(inputVerifier.getThreshold() == coprocessorThreshold, "InputVerifier: threshold mismatch");
        console.log("  InputVerifier config: OK");

        console.log("  All verifications passed!");
    }

    // =========================================================================
    // Output
    // =========================================================================

    function _logDeploymentSummary() internal view {
        console.log("\n========================================");
        console.log("Deployment Complete!");
        console.log("========================================\n");

        console.log("Proxy Addresses (deterministic):");
        console.log("  ACL:", aclAdd);
        console.log("  FHEVMExecutor:", fhevmExecutorAdd);
        console.log("  KMSVerifier:", kmsVerifierAdd);
        console.log("  InputVerifier:", inputVerifierAdd);
        console.log("  HCULimit:", hcuLimitAdd);
        console.log("  PauserSet:", pauserSetAdd);

        console.log("\nImplementation Addresses:");
        console.log("  ACL:", aclImplementation);
        console.log("  FHEVMExecutor:", fhevmExecutorImplementation);
        console.log("  KMSVerifier:", kmsVerifierImplementation);
        console.log("  InputVerifier:", inputVerifierImplementation);
        console.log("  HCULimit:", hcuLimitImplementation);
    }
}
