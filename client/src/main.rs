mod contracts;
mod fhe;
mod kms;

use alloy::primitives::Address;
use anyhow::Result;

#[tokio::main]
async fn main() -> Result<()> {
    // --- Configuration (from env or defaults) ---
    let kms_url = std::env::var("KMS_URL").unwrap_or_else(|_| "http://127.0.0.1:3000".into());
    let rpc_url = std::env::var("RPC_URL").unwrap_or_else(|_| "http://127.0.0.1:8545".into());
    let private_key = std::env::var("PRIVATE_KEY")
        .unwrap_or_else(|_| "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80".into());
    let contract_address: Address = std::env::var("CONTRACT_ADDRESS")
        .unwrap_or_else(|_| "0x5FbDB2315678afecb367f032d93F642f64180aa3".into())
        .parse()?;
    let recipient: Address = std::env::var("RECIPIENT")
        .unwrap_or_else(|_| "0x70997970C51812dc3A010C7d01b50e0d17dc79C8".into())
        .parse()?;
    let amount: u64 = std::env::var("AMOUNT")
        .unwrap_or_else(|_| "100".into())
        .parse()?;

    println!("=== FHE Client Demo ===");
    println!();

    // --- Step 1: Fetch public key from KMS ---
    println!("[1] Fetching public key from KMS at {}", kms_url);
    let pk = kms::fetch_public_key(&kms_url).await?;
    println!("    ✓ Public key fetched successfully");
    println!();

    // --- Step 2: Encrypt the amount ---
    println!("[2] Encrypting amount using public key: {}", amount);
    let ciphertext = fhe::encrypt(amount, &pk)?;
    println!("    ✓ Ciphertext size: {} bytes", ciphertext.len());
    println!();

    // --- Step 3: Compute handle ---
    println!("[3] Computing handle (keccak256 of ciphertext)");
    let handle = fhe::compute_handle(&ciphertext);
    println!("    ✓ Handle: 0x{}", hex::encode(handle));
    println!();

    // --- Step 4: Prepare payload for contract call ---
    println!("[4] Preparing transfer payload");
    let payload = contracts::build_transfer_payload(&ciphertext, handle);
    println!("    Ciphertext hex: {}...{}", &payload.ciphertext_hex[..20], &payload.ciphertext_hex[payload.ciphertext_hex.len()-8..]);
    println!("    Handle hex:     {}", payload.handle_hex);
    println!();

    // --- Step 5: Create contract client ---
    println!("[5] Creating contract client");
    let client = contracts::EncryptedERC20Client::new(
        contract_address,
        rpc_url.clone(),
        private_key.clone(),
    );
    println!("    Contract: {}", contract_address);
    println!();

    // --- Step 6: Query contract info ---
    println!("[6] Querying contract info");
    match client.name().await {
        Ok(name) => println!("    Name: {}", name),
        Err(e) => println!("    Name: (error: {})", e),
    }
    match client.symbol().await {
        Ok(symbol) => println!("    Symbol: {}", symbol),
        Err(e) => println!("    Symbol: (error: {})", e),
    }
    match client.total_supply().await {
        Ok(supply) => println!("    Total Supply: {}", supply),
        Err(e) => println!("    Total Supply: (error: {})", e),
    }
    println!();

    // --- Step 7: Execute Transfer ---
    println!("[7] Executing transfer on-chain");
    println!("    To: {}", recipient);
    println!("    Amount (encrypted): {}", amount);
    println!();
    
    // Call transfer with handle as encryptedAmount and ciphertext as inputProof
    match client.transfer(recipient, handle, ciphertext.clone()).await {
        Ok(_) => println!("    ✓ Transfer completed successfully!"),
        Err(e) => println!("    ✗ Transfer failed: {}", e),
    }

    println!();
    println!("=== Demo Complete ===");

    Ok(())
}
