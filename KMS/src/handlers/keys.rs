use axum::{extract::State, http::StatusCode, Json};
use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine;
use serde::Serialize;
use crate::state::KmsState;

#[derive(Serialize)]
pub struct PublicKeyResponse {
    pub public_key: String,
}

#[derive(Serialize)]
pub struct ServerKeyResponse {
    pub server_key: String,
}

pub async fn generate(State(state): State<KmsState>) -> Result<Json<&'static str>, StatusCode> {
    state
        .kms_service
        .generate_and_store()
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    Ok(Json("Keys generated and stored successfully"))
}

pub async fn public_key(State(state): State<KmsState>) -> Result<Json<PublicKeyResponse>, StatusCode> {
    let public_key = state
        .kms_service
        .load_public()
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let bytes = bincode::serialize(&public_key).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(PublicKeyResponse {
        public_key: BASE64.encode(&bytes),
    }))
}

pub async fn server_key(State(state): State<KmsState>) -> Result<Json<ServerKeyResponse>, StatusCode> {
    let server_key = state
        .kms_service
        .load_server()
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let bytes = bincode::serialize(&server_key).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(ServerKeyResponse {
        server_key: BASE64.encode(&bytes),
    }))
}