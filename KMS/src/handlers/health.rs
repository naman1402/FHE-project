use axum::Json;
use serde_json::{json, Value};

pub async fn health() -> Json<Value> {
    Json(json!({
        "status": "Ok",
        "message": "KMS service is healthy"
    }))
}