use alloy::{
    network::EthereumWallet,
    primitives::{Address, Bytes},
    providers::{Provider, ProviderBuilder},
    signers::local::PrivateKeySigner,
    sol,
};
use anyhow::Result;

// Generate type-safe bindings for EncryptedERC20
sol! {
    #[sol(rpc)]
    contract EncryptedERC20 {
        function name() public view returns (string memory);
        function symbol() public view returns (string memory);
        function totalSupply() public view returns (uint64);
        function decimals() public view returns (uint8);
        function owner() public view returns (address);
        function mint(uint64 amount) public;
        function transfer(address to, bytes32 encryptedAmount, bytes calldata inputProof) public returns (bool);
        function balanceOf(address user) public view returns (bytes32);

        event Transfer(address indexed from, address indexed to);
        event Mint(address indexed to, uint64 amount);
    }
}

pub struct EncryptedERC20Client {
    pub contract_address: Address,
    pub rpc_url: String,
    pub private_key: String,
}

impl EncryptedERC20Client {
    pub fn new(contract_address: Address, rpc_url: String, private_key: String) -> Self {
        Self {
            contract_address,
            rpc_url,
            private_key,
        }
    }

    async fn provider(&self) -> Result<impl Provider> {
        let signer: PrivateKeySigner = self.private_key.parse()?;
        let wallet = EthereumWallet::from(signer);
        let provider = ProviderBuilder::new()
            .wallet(wallet)
            .connect_http(self.rpc_url.parse()?);
        Ok(provider)
    }

    pub async fn mint(&self, amount: u64) -> Result<()> {
        let provider = self.provider().await?;
        let contract = EncryptedERC20::new(self.contract_address, provider);
        let tx = contract.mint(amount).send().await?;
        let receipt = tx.watch().await?;
        println!("[contracts] mint tx confirmed: {:?}", receipt);
        Ok(())
    }

    pub async fn transfer(
        &self,
        to: Address,
        encrypted_amount: [u8; 32],
        input_proof: Vec<u8>,
    ) -> Result<()> {
        println!("[contracts] sending transfer tx...");
        println!("    to: {} handle: 0x{}, proof size: {} bytes", to, hex::encode(encrypted_amount), input_proof.len());
        
        let provider = self.provider().await?;
        let contract = EncryptedERC20::new(self.contract_address, provider);
        let tx = contract
            .transfer(to, encrypted_amount.into(), Bytes::from(input_proof))
            .send()
            .await?;
        println!("[contracts] tx sent, waiting for confirmation...");
        let receipt = tx.watch().await?;
        println!("[contracts] transfer tx confirmed: {:?}", receipt);
        Ok(())
    }

    pub async fn name(&self) -> Result<String> {
        let provider = self.provider().await?;
        let contract = EncryptedERC20::new(self.contract_address, provider);
        let name = contract.name().call().await?;
        Ok(name.into())
    }

    pub async fn symbol(&self) -> Result<String> {
        let provider = self.provider().await?;
        let contract = EncryptedERC20::new(self.contract_address, provider);
        let symbol = contract.symbol().call().await?;
        Ok(symbol.into())
    }

    pub async fn total_supply(&self) -> Result<u64> {
        let provider = self.provider().await?;
        let contract = EncryptedERC20::new(self.contract_address, provider);
        let supply = contract.totalSupply().call().await?;
        Ok(supply.into())
    }

    // pub async fn balance_of(&self, user: Address) -> Result<[u8; 32]> {
    //     let provider = self.provider().await?;
    //     let contract = EncryptedERC20::new(self.contract_address, provider);
    //     let balance = contract.balanceOf(user).call().await?;
    //     Ok(balance.0)
    // }
}


/// 
/// Helper to prepare transfer calldata (for manual use with cast/forge)
pub struct PreparedCall {
    pub ciphertext_hex: String,
    pub handle_hex: String,
}

pub fn build_transfer_payload(ciphertext: &[u8], handle: [u8; 32]) -> PreparedCall {
    PreparedCall {
        ciphertext_hex: format!("0x{}", hex::encode(ciphertext)),
        handle_hex: format!("0x{}", hex::encode(handle)),
    }
}