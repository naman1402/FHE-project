use serde::Deserialize;
use tfhe::CompactPublicKey;
use reqwest::Client;

#[derive(Deserialize)]
pub struct PublicKeyResponse {
    pub public_key: String,
}

pub async fn fetch_public_key(url: &str) -> Result<CompactPublicKey> {
    let response: PublicKeyResponse = Client::new().get(format!("{}/keys/public", url)).send().await?.json().await?;
    let bytes = base64::engine::general_purpose::STANDARD.decode(&response.public_key)?;
    let public_key: CompactPublicKey = bincode::deserialize(&bytes)?;
    Ok(public_key)
}