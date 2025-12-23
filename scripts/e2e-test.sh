#!/bin/bash
# Tests: Anvil + FHEVM Infra + EncryptedERC20 + KMS + Coprocessor

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project root
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTRACTS_DIR="$PROJECT_ROOT/contracts"
KMS_DIR="$PROJECT_ROOT/KMS"
COPROCESSOR_DIR="$PROJECT_ROOT/coprocessor"
CLIENT_DIR="$PROJECT_ROOT/client"

# Config
ANVIL_PORT=8545
KMS_PORT=3000
RPC_URL="http://127.0.0.1:$ANVIL_PORT"
KMS_URL="http://127.0.0.1:$KMS_PORT"
RECIPIENT="0x70997970C51812dc3A010C7d01b50e0d17dc79C8" # default anvil account[1]

# PIDs for cleanup
ANVIL_PID=""
KMS_PID=""
COPROCESSOR_PID=""

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}[Cleanup] Stopping services...${NC}"
    [ -n "$COPROCESSOR_PID" ] && kill $COPROCESSOR_PID 2>/dev/null && echo "  Stopped coprocessor"
    [ -n "$KMS_PID" ] && kill $KMS_PID 2>/dev/null && echo "  Stopped KMS"
    [ -n "$ANVIL_PID" ] && kill $ANVIL_PID 2>/dev/null && echo "  Stopped Anvil"
    # Also kill by port in case PIDs don't work
    pkill -f "anvil" 2>/dev/null || true
    echo -e "${GREEN}[Cleanup] Done${NC}"
}

trap cleanup EXIT

# Helper functions
log_step() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
    exit 1
}

wait_for_port() {
    local port=$1
    local name=$2
    local max_attempts=30
    local attempt=0
    
    echo -n "  Waiting for $name on port $port"
    while ! nc -z localhost $port 2>/dev/null; do
        attempt=$((attempt + 1))
        if [ $attempt -ge $max_attempts ]; then
            echo ""
            log_error "$name failed to start on port $port"
        fi
        echo -n "."
        sleep 1
    done
    echo " ready!"
}

# ============================================
# STEP 1: Start Anvil
# ============================================
log_step "[1/7] Starting Anvil"

# Kill any existing anvil
pkill -f "anvil" 2>/dev/null || true
sleep 1

cd "$CONTRACTS_DIR"
anvil --host 0.0.0.0 --port $ANVIL_PORT > /tmp/anvil.log 2>&1 &
ANVIL_PID=$!
wait_for_port $ANVIL_PORT "Anvil"
log_success "Anvil started (PID: $ANVIL_PID)"

# ============================================
# STEP 2: Deploy FHEVM Infrastructure
# ============================================
log_step "[2/7] Deploying FHEVM Infrastructure"

# Use our shell-based deployment script
"$PROJECT_ROOT/scripts/deploy-infra.sh" 2>&1

# Verify FHEVMExecutor has code
EXECUTOR_CODE=$(cast code 0x05fD9B5EFE0a996095f42Ed7e77c390810CF660c --rpc-url $RPC_URL 2>/dev/null)
if [ "$EXECUTOR_CODE" = "0x" ] || [ -z "$EXECUTOR_CODE" ]; then
    log_error "FHEVMExecutor not deployed correctly"
fi
log_success "FHEVM Infrastructure deployed"
echo "  FHEVMExecutor: 0x05fD9B5EFE0a996095f42Ed7e77c390810CF660c"
echo "  ACL: 0x339EcE85B9E11a3A3AA557582784a15d7F82AAf2"

# ============================================
# STEP 3: Deploy EncryptedERC20 Token
# ============================================
log_step "[3/7] Deploying EncryptedERC20 Token"

cd "$CONTRACTS_DIR"
TOKEN_OUTPUT=$(forge script script/DeployToken.s.sol:DeployToken \
    --rpc-url $RPC_URL \
    --broadcast \
    2>&1)

TOKEN_ADDRESS=$(echo "$TOKEN_OUTPUT" | grep -oP 'Address: \K0x[a-fA-F0-9]{40}' | head -1)
if [ -z "$TOKEN_ADDRESS" ]; then
    echo "$TOKEN_OUTPUT" | tail -20
    log_error "Failed to get token address"
fi
log_success "EncryptedERC20 deployed at $TOKEN_ADDRESS"

# ============================================
# STEP 4: Start KMS
# ============================================
log_step "[4/7] Starting KMS Service"

cd "$KMS_DIR"
cargo run > /tmp/kms.log 2>&1 &
KMS_PID=$!
wait_for_port $KMS_PORT "KMS"
log_success "KMS started (PID: $KMS_PID)"

# ============================================
# STEP 5: Generate FHE Keys
# ============================================
log_step "[5/7] Generating FHE Keys"

# Check if keys already exist
if [ -f "$KMS_DIR/keys/public_key" ] && [ -f "$KMS_DIR/keys/server_key" ]; then
    echo "  Keys already exist, skipping generation..."
else
    echo "  Generating keys (this takes a few minutes)..."
    KEYGEN_RESULT=$(curl -s -X POST $KMS_URL/keys/generate)
    echo "  $KEYGEN_RESULT"
fi

# Verify keys are accessible
curl -s $KMS_URL/keys/public > /dev/null || log_error "Failed to fetch public key"
log_success "FHE keys ready"

# ============================================
# STEP 6: Start Coprocessor
# ============================================
log_step "[6/7] Starting Coprocessor"

cd "$COPROCESSOR_DIR"
cargo run > /tmp/coprocessor.log 2>&1 &
COPROCESSOR_PID=$!
sleep 3

# Check if coprocessor is running
if ! ps -p $COPROCESSOR_PID > /dev/null 2>&1; then
    log_error "Coprocessor failed to start. Check /tmp/coprocessor.log"
fi
log_success "Coprocessor started (PID: $COPROCESSOR_PID)"
echo "  Listening on FHEVMExecutor: 0x05fD9B5EFE0a996095f42Ed7e77c390810CF660c"

# ============================================
# STEP 7: Trigger FHE Operations (Mint + Transfer)
# ============================================
log_step "[7/7] Triggering FHE Operations (Mint + Transfer)"

echo "  Minting 1,000,000 tokens..."
cd "$CONTRACTS_DIR"
MINT_OUTPUT=$(TOKEN=$TOKEN_ADDRESS AMOUNT=1000000 forge script script/DeployToken.s.sol:MintToken \
    --rpc-url $RPC_URL \
    --broadcast \
    2>&1)

if echo "$MINT_OUTPUT" | grep -q "SUCCESSFUL"; then
    log_success "Mint transaction successful!"
else
    echo "$MINT_OUTPUT" | tail -20
    log_error "Mint transaction failed"
fi

echo "  Transferring full balance to $RECIPIENT..."
TRANSFER_OUTPUT=$(TOKEN=$TOKEN_ADDRESS TO=$RECIPIENT forge script script/DeployToken.s.sol:TransferToken \
    --rpc-url $RPC_URL \
    --broadcast \
    2>&1)

if echo "$TRANSFER_OUTPUT" | grep -q "SUCCESSFUL"; then
    log_success "Transfer transaction successful!"
else
    echo "$TRANSFER_OUTPUT" | tail -20
    log_error "Transfer transaction failed"
fi

# ============================================
# Results
# ============================================
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}E2E Test Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Deployed Addresses:"
echo "  FHEVM Executor: 0x05fD9B5EFE0a996095f42Ed7e77c390810CF660c"
echo "  ACL:            0x339EcE85B9E11a3A3AA557582784a15d7F82AAf2"
echo "  Token:          $TOKEN_ADDRESS"
echo ""
echo "Services Running:"
echo "  Anvil:       http://127.0.0.1:$ANVIL_PORT (PID: $ANVIL_PID)"
echo "  KMS:         http://127.0.0.1:$KMS_PORT (PID: $KMS_PID)"
echo "  Coprocessor: PID: $COPROCESSOR_PID"
echo ""
echo "Logs:"
echo "  Anvil:       /tmp/anvil.log"
echo "  KMS:         /tmp/kms.log"
echo "  Coprocessor: /tmp/coprocessor.log"
echo ""
echo -e "${YELLOW}Check coprocessor log for parsed FHE events:${NC}"
echo "  tail -f /tmp/coprocessor.log"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop all services${NC}"

# Keep script running to maintain background processes
wait
