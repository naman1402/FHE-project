//! FHE Event Listener
use crate::config::Config;
use crate::events::parser::{self, parse_fhe_event};
use crate::fhe::Engine;
use alloy::providers::{Provider, ProviderBuilder, WsConnect};
use alloy::rpc::types::Filter;
use anyhow::{Context, Result};
use futures::StreamExt;
use std::sync::Arc;

/// Start listening for FHE events from the TFHE Executor contract
///
/// # Arguments
/// * `config` - Configuration with WebSocket URL and contract addresses
/// * `engine` - Optional FHE engine for executing operations. If None, only parses/logs events.
///
/// # Event Processing
/// For each event:
/// 1. Parse the raw log into an `FheOperation`
/// 2. Log the operation details
/// 3. If engine is available, execute the operation (compute on ciphertexts)
/// 4. Store results in the engine's ciphertext storage
pub async fn listen_to_events(config: &Config, engine: Option<Arc<Engine>>) -> Result<()> {
    println!(
        "[Listener] Connecting to WebSocket at {}...",
        config.websocket_url
    );

    // Create WebSocket connection to the blockchain node
    let ws = WsConnect::new(&config.websocket_url);
    let provider = ProviderBuilder::new()
        .connect_ws(ws)
        .await
        .context("Failed to connect to WebSocket endpoint")?;

    println!("[Listener] ✓ Connected to WebSocket");
    println!(
        "[Listener] TFHE Executor address: {:?}",
        config.tfhe_executor_address
    );
    println!("[Listener] ACL address: {:?}", config.acl_address);

    // Filter for events from the TFHE Executor contract only
    // This contract emits all FHE operation events (FheAdd, FheSub, etc.)
    let filter = Filter::new().address(config.tfhe_executor_address);

    // Subscribe to logs matching our filter
    // This creates a persistent subscription that receives events in real-time
    let sub = provider
        .subscribe_logs(&filter)
        .await
        .context("Failed to subscribe to logs")?;
    let mut stream = sub.into_stream();

    if engine.is_some() {
        println!("[Listener] Mode: EXECUTE (parsing + FHE computation)");
    } else {
        println!("[Listener] Mode: PARSE-ONLY (no FHE execution)");
    }
    println!("[Listener] Waiting for FHE events...");
    println!();

    let mut event_count = 0;
    let mut success_count = 0;
    let mut error_count = 0;

    while let Some(log) = stream.next().await {
        event_count += 1;

        // Step 1: Parse the raw log into a structured FheOperation
        let operation = match parse_fhe_event(&log) {
            Some(op) => op,
            None => {
                println!("[Listener] Failed to parse event #{}", event_count);
                error_count += 1;
                continue;
            }
        };

        // Step 2: Log the parsed operation
        parser::log_fhe_operation(&operation);

        // Step 3: Execute the operation if we have an engine
        if let Some(ref eng) = engine {
            match eng.handle_operation(&operation) {
                Ok(()) => {
                    success_count += 1;
                    println!(
                        "[Listener] ✓ Executed {} (storage: {} ciphertexts)",
                        operation.name(),
                        eng.storage_count()
                    );
                }
                Err(e) => {
                    error_count += 1;
                    println!(
                        "[Listener] ✗ Failed to execute {}: {}",
                        operation.name(),
                        e
                    );
                }
            }
        }
        println!();
        println!();
    }

    println!("[Listener] Event stream ended");
    println!(
        "[Listener] Summary: {} events, {} successful, {} errors",
        event_count, success_count, error_count
    );
    Ok(())
}
