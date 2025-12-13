# FHE-Project Contracts

FHEVM smart contracts using Zama's fully homomorphic encryption infrastructure.

## Quick Start

```shell
forge build          # Build contracts
forge test           # Run tests
```

## Deploy FHEVM Infrastructure (Local/Anvil)

```shell
# Terminal 1: Start Anvil
anvil

# Terminal 2: Deploy
forge script script/DeployInfra.s.sol:DeployInfra --rpc-url http://localhost:8545 --broadcast -vvvv
```

### What the script does

- Deploys all Zama host contracts to deterministic addresses (proxies + implementations where applicable): ACL, PauserSet, FHEVMExecutor, KMSVerifier, InputVerifier, HCULimit.
- Uses Foundry cheatcodes (`deployCodeTo`, `etch`, `prank`) so it is **Anvil-only**.
- Verifies wiring/thresholds after deployment (ACL ↔ PauserSet, Executor ↔ ACL/HCULimit, KMS/Input verifier thresholds).
- These addresses are what the FHE library and tests expect when `CoprocessorConfig` is set locally.

## Deployed Addresses (Deterministic)

| Contract      | Address                                      |
| ------------- | -------------------------------------------- |
| ACL           | `0x339EcE85B9E11a3A3AA557582784a15d7F82AAf2` |
| FHEVMExecutor | `0x05fD9B5EFE0a996095f42Ed7e77c390810CF660c` |
| KMSVerifier   | `0x12B064FB845C1cc05e9493856a1D637a73e944bE` |
| InputVerifier | `0x3a2DA6f1daE9eF988B48d9CF27523FA31a8eBE50` |
| HCULimit      | `0x3De04Eecbc93c87dC922F71E98a6bD9259e0aD93` |
| PauserSet     | `0x4B7ac2d0E8Fc9a6f2b1bce0fe5DCA5d8c9e6F7a8` |

## Sepolia (Zama Deployed)

For Sepolia testnet, use Zama's pre-deployed infrastructure:

- ACL: `0xf0Ffdc93b7E186bC2f8CB3dAA75D86d1930A433D`
- Coprocessor: `0x92C920834Ec8941d2C77D188936E1f7A6f49c127`
- KMSVerifier: `0xbE0E383937d564D7FF0BC3b46c51f0bF8d5C311A`

## Environment Variables

```shell
PRIVATE_KEY=                    # Deployer private key
KMS_SIGNER_ADDRESS=             # KMS signer (defaults to deployer)
COPROCESSOR_SIGNER_ADDRESS=     # Coprocessor signer (defaults to KMS signer)
```

### Interconnection quick notes

- FHEVMExecutor stores ACL and HCULimit addresses.
- ACL references PauserSet.
- KMSVerifier and InputVerifier are initialized with signer lists + thresholds.
- The deterministic addresses above are the ones the Solidity FHE library calls when `FHE.setCoprocessor` is provided those addresses.

### EncryptedERC20 tests (Foundry)

- Uses `ConfiguredEncryptedERC20` to set `CoprocessorConfig` (ACL, Executor, KMSVerifier) in the token’s storage so FHE ops route to the deployed infra.
- `HostContractsDeployerTestUtils` spins up the same host stack locally (deterministic addresses) for each test.
- Coverage: metadata/initialization, mint events (`TrivialEncrypt`, `FheAdd`), expected transfer event sequence docs, ACL permissions, edge cases (zero/max mint), fuzzed mints.

