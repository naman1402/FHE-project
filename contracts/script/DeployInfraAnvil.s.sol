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

contract DeployableERC1967Proxy is ERC1967Proxy {
    constructor(address impl, bytes memory data) ERC1967Proxy(impl, data) {}
}

/**
 * @title DeployInfraAnvil
 * @notice Deploy FHEVM infrastructure to deterministic addresses on Anvil
 */
contract DeployInfraAnvil is Script, Test {
    // EIP-1967 implementation slot
    bytes32 constant IMPL_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
    // OwnableUpgradeable storage slot
    bytes32 constant OWNER_SLOT = 0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300;
    
    address public owner;

    function run() external {
        uint256 pk = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        owner = vm.addr(pk);

        console.log("FHEVM Infra Deployment - Owner:", owner);

        vm.startBroadcast(pk);

        _deployPauserSet();
        _deployACL();
        _deployHCULimit();
        _deployFHEVMExecutor();
        _deployKMSVerifier();
        _deployInputVerifier();

        vm.stopBroadcast();

        _logSummary();
    }

    function _deployPauserSet() internal {
        console.log("[1/6] PauserSet ->", pauserSetAdd);
        PauserSet impl = new PauserSet();
        vm.etch(pauserSetAdd, address(impl).code);
    }

    function _deployACL() internal {
        console.log("[2/6] ACL ->", aclAdd);
        address emptyImpl = address(new EmptyUUPSProxyACL());
        address tempProxy = address(new DeployableERC1967Proxy(
            emptyImpl,
            abi.encodeCall(EmptyUUPSProxyACL.initialize, (owner))
        ));
        _etchProxy(aclAdd, tempProxy);
        // Copy owner storage slot
        vm.store(aclAdd, OWNER_SLOT, vm.load(tempProxy, OWNER_SLOT));
        
        address aclImpl = address(new ACL());
        EmptyUUPSProxyACL(aclAdd).upgradeToAndCall(
            aclImpl,
            abi.encodeCall(ACL.initializeFromEmptyProxy, ())
        );
    }

    function _deployHCULimit() internal {
        console.log("[3/6] HCULimit ->", hcuLimitAdd);
        address emptyImpl = address(new EmptyUUPSProxy());
        address tempProxy = address(new DeployableERC1967Proxy(
            emptyImpl,
            abi.encodeCall(EmptyUUPSProxy.initialize, ())
        ));
        _etchProxy(hcuLimitAdd, tempProxy);
        
        address impl = address(new HCULimit());
        EmptyUUPSProxy(hcuLimitAdd).upgradeToAndCall(
            impl,
            abi.encodeCall(HCULimit.initializeFromEmptyProxy, ())
        );
    }

    function _deployFHEVMExecutor() internal {
        console.log("[4/6] FHEVMExecutor ->", fhevmExecutorAdd);
        address emptyImpl = address(new EmptyUUPSProxy());
        address tempProxy = address(new DeployableERC1967Proxy(
            emptyImpl,
            abi.encodeCall(EmptyUUPSProxy.initialize, ())
        ));
        _etchProxy(fhevmExecutorAdd, tempProxy);
        
        address impl = address(new FHEVMExecutor());
        EmptyUUPSProxy(fhevmExecutorAdd).upgradeToAndCall(
            impl,
            abi.encodeCall(FHEVMExecutor.initializeFromEmptyProxy, ())
        );
    }

    function _deployKMSVerifier() internal {
        console.log("[5/6] KMSVerifier ->", kmsVerifierAdd);
        address emptyImpl = address(new EmptyUUPSProxy());
        address tempProxy = address(new DeployableERC1967Proxy(
            emptyImpl,
            abi.encodeCall(EmptyUUPSProxy.initialize, ())
        ));
        _etchProxy(kmsVerifierAdd, tempProxy);
        
        address[] memory signers = new address[](1);
        signers[0] = owner;
        
        address impl = address(new KMSVerifier());
        EmptyUUPSProxy(kmsVerifierAdd).upgradeToAndCall(
            impl,
            abi.encodeCall(KMSVerifier.initializeFromEmptyProxy, (owner, uint64(block.chainid), signers, 1))
        );
    }

    function _deployInputVerifier() internal {
        console.log("[6/6] InputVerifier ->", inputVerifierAdd);
        address emptyImpl = address(new EmptyUUPSProxy());
        address tempProxy = address(new DeployableERC1967Proxy(
            emptyImpl,
            abi.encodeCall(EmptyUUPSProxy.initialize, ())
        ));
        _etchProxy(inputVerifierAdd, tempProxy);
        
        address[] memory signers = new address[](1);
        signers[0] = owner;
        
        address impl = address(new InputVerifier());
        EmptyUUPSProxy(inputVerifierAdd).upgradeToAndCall(
            impl,
            abi.encodeCall(InputVerifier.initializeFromEmptyProxy, (owner, uint64(block.chainid), signers, 1))
        );
    }

    function _etchProxy(address target, address temp) internal {
        vm.etch(target, temp.code);
        vm.store(target, IMPL_SLOT, vm.load(temp, IMPL_SLOT));
    }

    function _logSummary() internal pure {
        console.log("\n=== Deployment Complete ===");
        console.log("FHEVMExecutor:", fhevmExecutorAdd);
        console.log("ACL:", aclAdd);
        console.log("KMSVerifier:", kmsVerifierAdd);
        console.log("InputVerifier:", inputVerifierAdd);
        console.log("HCULimit:", hcuLimitAdd);
        console.log("PauserSet:", pauserSetAdd);
    }
}
