mod config;
mod events;
mod fhe;

use anyhow::Result;
use std::collections::HashMap;
use std::sync::{Arc, RwLock};

#[tokio::main]
async fn main() -> Result<()> {
    println!("═══════════════════════════════════════════════════════════");
    println!("           FHE Coprocessor Starting");
    println!("═══════════════════════════════════════════════════════════");
    println!();

    let config = config::load_config().expect("Failed to load config from .env");

    println!("Configuration:");
    println!("   WebSocket URL:     {}", config.websocket_url);
    println!("   TFHE Executor:     {:?}", config.tfhe_executor_address);
    println!("   ACL Address:       {:?}", config.acl_address);
    println!("   KMS URL:           {}", config.kms_url);
    println!();

    // Initialize ciphertext storage (shared across listener and engine)
    let storage: fhe::CiphertextStorage = Arc::new(RwLock::new(HashMap::new()));
    println!("[Main] Initialized ciphertext storage");

    // Fetch server key from KMS
    println!("[Main] Fetching server key from KMS...");
    let server_key = match fhe::fetch_server_key(&config.kms_url).await {
        Ok(key) => {
            println!("[Main] ✓ Server key loaded successfully");
            key
        }
        Err(e) => {
            println!("[Main] ⚠ Failed to fetch server key: {}", e);
            println!("[Main] ⚠ Running in parse-only mode (no FHE execution)");
            // Continue without engine - will only parse events
            events::listener::listen_to_events(&config, None).await?;
            return Ok(());
        }
    };

    // Create the FHE engine
    let engine = Arc::new(fhe::Engine::new(server_key, storage.clone()));
    println!("[Main] ✓ FHE Engine initialized");
    println!();

    println!("═══════════════════════════════════════════════════════════");
    println!("           Listening for FHE Events...");
    println!("═══════════════════════════════════════════════════════════");
    println!();

    events::listener::listen_to_events(&config, Some(engine)).await?;
    Ok(())
}
