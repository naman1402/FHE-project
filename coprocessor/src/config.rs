use alloy::primitives::Address;
use anyhow::Context;
use std::env;

#[derive(Debug, Clone)]
pub struct Config {
    pub websocket_url: String,
    pub tfhe_executor_address: Address,
    pub acl_address: Address,
}

pub fn load_config() -> Result<Config, anyhow::Error> {
    dotenv::dotenv().ok();

    let websocket_url = env::var("WEBSOCKET_URL").context("WEBSOCKET_URL not set")?;
    let tfhe_executor_address = env::var("TFHE_EXECUTOR_ADDRESS")
        .context("TFHE_EXECUTOR_ADDRESS not set")?
        .parse::<Address>()?;
    let acl_address = env::var("ACL_ADDRESS")
        .context("ACL_ADDRESS not set")?
        .parse::<Address>()?;

    Ok(Config {
        websocket_url,
        tfhe_executor_address,
        acl_address,
    })
}
