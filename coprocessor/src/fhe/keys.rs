use anyhow::Result;
use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use reqwest::Client;
use serde::Deserialize;
use tfhe::ServerKey;

#[derive(Deserialize)]
struct ServerKeyResponse {
    server_key_base64: String,
}

pub async fn fetch_server_key(url: &str) -> Result<ServerKey> {
    let resp: ServerKeyResponse = Client::new().get(format!("{}/keys/server", url)).send().await?.json().await?;
    let bytes = STANDARD.decode(&resp.server_key_base64)?;
    let server_key = bincode::deserialize(&bytes)?;
    Ok(server_key)
}
