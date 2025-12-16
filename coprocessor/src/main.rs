mod config;
mod events;

use anyhow::Result;

#[tokio::main]
async fn main() -> Result<()> {
    println!("FHE Coprocessor Starting:");
    println!();
    let config = config::load_config().expect("Failed to load config from .env");
    
    println!("   WebSocket URL:     {}", config.websocket_url);
    println!("   TFHE Executor:     {:?}", config.tfhe_executor_address);
    println!("   ACL Address:       {:?}", config.acl_address);
    println!();
    
    events::listener::listen_to_events(&config).await?;
    Ok(())
}
