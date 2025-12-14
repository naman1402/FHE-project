use anyhow::Context;
use std::env;
use ethers::types::Address;

#[derive(Debug, Clone)]
pub struct Config {
    pub sepolia_websocket_url: String,
    pub tfhe_executor_address: Address,
    pub acl_address: Address,
    pub gateway_address: Address,
}


pub fn load_config() -> Result<Config, anyhow::Error> {
    dotenv::dotenv().ok();

    let sepolia_websocket_url = env::var("SEPOLIA_WEBSOCKET_URL").context("SEPOLIA_WEBSOCKET_URL not set")?;
    let tfhe_executor_address = env::var("TFHE_EXECUTOR_ADDRESS").context("TFHE_EXECUTOR_ADDRESS not set")?.parse::<Address>()?;
    let acl_address = env::var("ACL_ADDRESS").context("ACL_ADDRESS not set")?.parse::<Address>()?;
    let gateway_address = env::var("GATEWAY_ADDRESS").context("GATEWAY_ADDRESS not set")?.parse::<Address>()?;

    // let config: Config = Config {
    //     sepolia_websocket_url: sepolia_websocket_url,
    //     tfhe_executor_address: tfhe_executor_address,
    //     acl_address: acl_address,
    //     gateway_address: gateway_address,
    // };
    
    return Ok(Config {
        sepolia_websocket_url: sepolia_websocket_url,
        tfhe_executor_address: tfhe_executor_address,
        acl_address: acl_address,
        gateway_address: gateway_address,
    });
}