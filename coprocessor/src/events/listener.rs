//! FHE Event Listener
use crate::config::Config;
use crate::events::parser;
use alloy::providers::{Provider, ProviderBuilder, WsConnect};
use alloy::rpc::types::Filter;
use anyhow::{Context, Result};
use futures::StreamExt;

/// Start listening for FHE events from the TFHE Executor contract
/// 
/// This function:
/// 1. Connects to the blockchain via WebSocket
/// 2. Sets up a filter for events from the TFHE Executor address
/// 3. Subscribes to new logs matching the filter
/// 4. Logs each event as it arrives
pub async fn listen_to_events(config: &Config) -> Result<()> {
    println!("[Listener] Connecting to WebSocket at {}...", config.websocket_url);
    
    // Create WebSocket connection
    let ws = WsConnect::new(&config.websocket_url);
    let provider = ProviderBuilder::new()
        .on_ws(ws)
        .await
        .context("Failed to connect to WebSocket endpoint")?;
    println!("[Listener] ✅ Connected to WebSocket!");
    println!("[Listener] 📡 TFHE Executor address: {:?}", config.tfhe_executor_address);
    println!("[Listener] 🔒 ACL address: {:?}", config.acl_address);
    
    // Filter for events from the TFHE Executor contract
    let filter = Filter::new()
        .address(config.tfhe_executor_address);

    // Subscribe to logs (Websocket subscription using the filters)
    let sub = provider
        .subscribe_logs(&filter)
        .await
        .context("Failed to subscribe to logs")?;
    
    // Convert subscription to stream and process events
    let mut stream = sub.into_stream();

        
    println!("[Listener] 🎯 Subscribing to events from TFHE Executor...");
    println!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    println!("[Listener] Waiting for FHE events...");
    println!();
    
    // Forwarding each log to the parser
    while let Some(log) = stream.next().await {
        parser::log_executor_event(&log);
    }
    
    println!("[Listener] Event stream ended unexpectedly");
    Ok(())
}