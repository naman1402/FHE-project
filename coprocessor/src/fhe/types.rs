use alloy::primitives::B256;
use std::collections::HashMap;
use std::sync::{Arc, RwLock};
use tfhe::{FheBool, FheUint64};

#[derive(Clone)]
pub enum Ciphertext {
    Uint64(FheUint64),
    Bool(FheBool),
}

pub type CiphertextStorage = Arc<RwLock<HashMap<B256, Ciphertext>>>;