use axum::{Router, routing::get};

async fn root() -> &'static str {
    "Welcome to the KMS service!"
}

#[tokio::main]
async fn main() {
    // println!("Hello, world!");
    let app = Router::new().route("/", get(root));
    let port = std::env::var("PORT").unwrap_or_else(|_| "3000".to_string());
    println!("Starting KMS service on port {}", port);
    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{}", port)).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
