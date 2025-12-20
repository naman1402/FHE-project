// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {EncryptedERC20} from "../src/EncryptedERC20.sol";

/**
 * @title DeployToken
 * @notice Deploy EncryptedERC20 token
 * @dev Run after DeployInfra.s.sol to ensure FHEVM infrastructure is deployed
 */
contract DeployToken is Script {
    function run() external returns (address) {
        uint256 deployerPrivateKey = vm.envOr(
            "PRIVATE_KEY", 
            uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
        );
        address deployer = vm.addr(deployerPrivateKey);

        console.log("\n========================================");
        console.log("Deploying EncryptedERC20 Token");
        console.log("========================================");
        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);
        EncryptedERC20 token = new EncryptedERC20("Encrypted Token", "eTKN");
        vm.stopBroadcast();

        console.log("  Address:", address(token));
        console.log("  Name:", token.name());
        console.log("  Symbol:", token.symbol());
        console.log("  Owner:", token.owner());

        return address(token);
    }
}

/**
 * @title MintToken
 * @notice Mint tokens on deployed EncryptedERC20
 * @dev Calls mint() which triggers FHE.add() - emits TrivialEncrypt + FheAdd events
 * 
 * Usage:
 *   TOKEN=0x... forge script script/DeployToken.s.sol:MintToken --rpc-url http://127.0.0.1:8545 --broadcast
 */
contract MintToken is Script {
    function run() external {
        address tokenAddr = vm.envAddress("TOKEN");
        uint64 amount = uint64(vm.envOr("AMOUNT", uint256(1000000))); // Default 1 token (6 decimals)
        
        uint256 deployerPrivateKey = vm.envOr(
            "PRIVATE_KEY", 
            uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
        );

        EncryptedERC20 token = EncryptedERC20(tokenAddr);
        
        console.log("\nMinting", amount, "tokens on", tokenAddr);
        console.log("  Before - Total Supply:", token.totalSupply());

        vm.startBroadcast(deployerPrivateKey);
        token.mint(amount);
        vm.stopBroadcast();

        console.log("  After - Total Supply:", token.totalSupply());
    }
}
