use crate::handlers::{health::health, keys};
use crate::state::KmsState;
use axum::{routing::{get, post}, Router};

pub fn create_router(state: KmsState) -> Router {
    Router::new()
        .route("/", get(health))
        .route("/health", get(health))
        .route("/keys/generate", post(keys::generate))
        .route("/keys/public", get(keys::public_key))
        .route("/keys/server", get(keys::server_key))
        .with_state(state)
}

// --- IGNORE ---
// POST method to generate and store keys
// GET method to retrieve public key
// GET method to retrieve server key
// POST method to decrypt payload