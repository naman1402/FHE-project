use ethers::types::Address;

#[derive(Debug, Clone)]
pub struct Config {
    pub sepolia_websocket_url: String,
    pub tfhe_executor_address: Address,
    pub acl_address: Address,
    pub gateway_address: Address,
}
