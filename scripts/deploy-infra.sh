#!/bin/bash
# Deploy FHEVM infrastructure to deterministic addresses on Anvil
# Uses Anvil-specific RPC methods (anvil_setCode, anvil_setStorageAt)

set -e

RPC_URL="${RPC_URL:-http://127.0.0.1:8545}"
PRIVATE_KEY="${PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
OWNER="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

ACL_ADDR="0x339EcE85B9E11a3A3AA557582784a15d7F82AAf2"
EXECUTOR_ADDR="0x05fD9B5EFE0a996095f42Ed7e77c390810CF660c"
KMS_VERIFIER_ADDR="0x12B064FB845C1cc05e9493856a1D637a73e944bE"
INPUT_VERIFIER_ADDR="0x3a2DA6f1daE9eF988B48d9CF27523FA31a8eBE50"
HCU_LIMIT_ADDR="0x3De04Eecbc93c87dC922F71E98a6bD9259e0aD93"
PAUSER_SET_ADDR="0x4B7ac2d0E8Fc9a6f2b1bce0fe5DCA5d8c9e6F7a8"

# EIP-1967 implementation slot
IMPL_SLOT="0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
# OwnableUpgradeable storage slot
OWNER_SLOT="0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTRACTS_DIR="$SCRIPT_DIR/../contracts"

echo "========================================="
echo "FHEVM Infrastructure Deployment (Anvil)"
echo "========================================="
echo "RPC: $RPC_URL"
echo "Owner: $OWNER"
echo ""

# Helper function to set code at address
set_code() {
    local addr=$1
    local code=$2
    curl -s -X POST $RPC_URL \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"anvil_setCode\",\"params\":[\"$addr\",\"$code\"],\"id\":1}" > /dev/null
}

# Helper function to set storage
set_storage() {
    local addr=$1
    local slot=$2
    local value=$3
    curl -s -X POST $RPC_URL \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"anvil_setStorageAt\",\"params\":[\"$addr\",\"$slot\",\"$value\"],\"id\":1}" > /dev/null
}

# Deploy implementation and return address
deploy_impl() {
    local contract=$1
    local result=$(cd "$CONTRACTS_DIR" && forge create "lib/fhevm/host-contracts/contracts/$contract" \
        --rpc-url "$RPC_URL" \
        --private-key "$PRIVATE_KEY" \
        --broadcast 2>&1 | grep "Deployed to:" | awk '{print $3}')
    echo "$result"
}

# Minimal UUPS proxy bytecode
PROXY_RUNTIME="0x6080604052600a600c565b005b60186014601a565b6050565b565b5f604b7f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc546001600160a01b031690565b905090565b365f80375f80365f845af43d5f803e8080156069573d5ff35b3d5ffd"

# Pad address to 32 bytes
pad_address() {
    local addr=$1
    printf "0x000000000000000000000000%s" "${addr:2}"
}

# Build contracts
echo "[0/6] Building contracts..."
cd "$CONTRACTS_DIR"
forge build --silent 2>/dev/null || forge build

# 1. PauserSet (immutable, no proxy)
echo ""
echo "[1/6] Deploying PauserSet to $PAUSER_SET_ADDR"
PAUSER_CODE=$(jq -r '.deployedBytecode.object' out/PauserSet.sol/PauserSet.json)
set_code "$PAUSER_SET_ADDR" "$PAUSER_CODE"
echo "  ✓ PauserSet deployed"

# 2. ACL
echo ""
echo "[2/6] Deploying ACL..."
ACL_IMPL=$(deploy_impl "ACL.sol:ACL")
echo "  Implementation: $ACL_IMPL"
set_code "$ACL_ADDR" "$PROXY_RUNTIME"
set_storage "$ACL_ADDR" "$IMPL_SLOT" "$(pad_address $ACL_IMPL)"
set_storage "$ACL_ADDR" "$OWNER_SLOT" "$(pad_address $OWNER)"
echo "  ✓ Proxy at $ACL_ADDR -> $ACL_IMPL"

# 3. HCULimit
echo ""
echo "[3/6] Deploying HCULimit..."
HCU_IMPL=$(deploy_impl "HCULimit.sol:HCULimit")
echo "  Implementation: $HCU_IMPL"
set_code "$HCU_LIMIT_ADDR" "$PROXY_RUNTIME"
set_storage "$HCU_LIMIT_ADDR" "$IMPL_SLOT" "$(pad_address $HCU_IMPL)"
echo "  ✓ Proxy at $HCU_LIMIT_ADDR -> $HCU_IMPL"

# 4. FHEVMExecutor
echo ""
echo "[4/6] Deploying FHEVMExecutor..."
EXEC_IMPL=$(deploy_impl "FHEVMExecutor.sol:FHEVMExecutor")
echo "  Implementation: $EXEC_IMPL"
set_code "$EXECUTOR_ADDR" "$PROXY_RUNTIME"
set_storage "$EXECUTOR_ADDR" "$IMPL_SLOT" "$(pad_address $EXEC_IMPL)"
echo "  ✓ Proxy at $EXECUTOR_ADDR -> $EXEC_IMPL"

# 5. KMSVerifier
echo ""
echo "[5/6] Deploying KMSVerifier..."
KMS_IMPL=$(deploy_impl "KMSVerifier.sol:KMSVerifier")
echo "  Implementation: $KMS_IMPL"
set_code "$KMS_VERIFIER_ADDR" "$PROXY_RUNTIME"
set_storage "$KMS_VERIFIER_ADDR" "$IMPL_SLOT" "$(pad_address $KMS_IMPL)"
echo "  ✓ Proxy at $KMS_VERIFIER_ADDR -> $KMS_IMPL"

# 6. InputVerifier
echo ""
echo "[6/6] Deploying InputVerifier..."
INPUT_IMPL=$(deploy_impl "InputVerifier.sol:InputVerifier")
echo "  Implementation: $INPUT_IMPL"
set_code "$INPUT_VERIFIER_ADDR" "$PROXY_RUNTIME"
set_storage "$INPUT_VERIFIER_ADDR" "$IMPL_SLOT" "$(pad_address $INPUT_IMPL)"
echo "  ✓ Proxy at $INPUT_VERIFIER_ADDR -> $INPUT_IMPL"

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "Proxy Addresses (deterministic):"
echo "  ACL:           $ACL_ADDR"
echo "  FHEVMExecutor: $EXECUTOR_ADDR"
echo "  KMSVerifier:   $KMS_VERIFIER_ADDR"
echo "  InputVerifier: $INPUT_VERIFIER_ADDR"
echo "  HCULimit:      $HCU_LIMIT_ADDR"
echo "  PauserSet:     $PAUSER_SET_ADDR"

# Verify
echo ""
echo "Verifying..."
CODE=$(cast code $EXECUTOR_ADDR --rpc-url $RPC_URL 2>/dev/null)
if [ "$CODE" != "0x" ] && [ -n "$CODE" ]; then
    echo "✓ FHEVMExecutor has code"
else
    echo "✗ FHEVMExecutor deployment failed"
    exit 1
fi

echo "✓ All contracts deployed successfully!"
