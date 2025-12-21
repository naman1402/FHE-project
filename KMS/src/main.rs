use std::net::SocketAddr;

mod handlers;
mod kms;
mod routes;
mod state;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let keys_dir = std::env::var("KEYS_DIR").unwrap_or_else(|_| "./keys".to_string());
    let app = routes::create_router(state::KmsState::new(keys_dir.into()).await?);
    let port = std::env::var("PORT").unwrap_or_else(|_| "3000".to_string());
    let addr = SocketAddr::from(([0, 0, 0, 0], port.parse().unwrap()));
    println!("Starting KMS service on address {}", addr);
    axum::serve(tokio::net::TcpListener::bind(addr).await?, app).await?;
    Ok(())
}
