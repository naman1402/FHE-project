use anyhow::Result;
use serde::{de::DeserializeOwned, Serialize};
use std::path::{Path, PathBuf};
use tfhe::{generate_keys, CompactPublicKey, ConfigBuilder, ServerKey};
use tokio::fs;

// KmsService handles key management operations
// Struct stores the directory path where keys are stored
#[derive(Clone)]
pub struct KmsService {
    dir: PathBuf,
}

impl KmsService {
    pub async fn new(dir: PathBuf) -> Result<Self> {
        fs::create_dir_all(&dir).await?;
        println!("[KmsService] init, dir: {:?}", dir);
        Ok(Self { dir })
    }

    pub async fn generate_and_store(&self) -> Result<()> {
        let config = ConfigBuilder::default().build();
        let (client_key, server_key) = generate_keys(config);
        let public_key = CompactPublicKey::new(&client_key);
        save(&self.dir, "client_key", &client_key).await?;
        save(&self.dir, "server_key", &server_key).await?;
        save(&self.dir, "public_key", &public_key).await?;
        println!("[KmsService] keys generated and stored");
        Ok(())
    }

    pub async fn load_public(&self) -> Result<CompactPublicKey> {
        let public_key: CompactPublicKey = load(&self.dir, "public_key").await?;
        println!("[KmsService] public key loaded");
        Ok(public_key)
    }

    pub async fn load_server(&self) -> Result<ServerKey> {
        let server_key: ServerKey = load(&self.dir, "server_key").await?;
        println!("[KmsService] server key loaded");
        Ok(server_key)
    }
}

// Helper functions to save and load keys
async fn save<T: Serialize>(dir: &Path, name: &str, value: &T) -> Result<()> {
    let bytes = bincode::serialize(value)?;
    fs::write(dir.join(name), bytes).await?;
    Ok(())
}

async fn load<T: DeserializeOwned>(dir: &Path, name: &str) -> Result<T> {
    let bytes = fs::read(dir.join(name)).await?;
    Ok(bincode::deserialize(&bytes)?)
}