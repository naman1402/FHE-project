use alloy::primitives::B256;
use std::collections::HashMap;
use std::sync::{Arc, RwLock};
use tfhe::{FheBool, FheUint64};

pub enum Ciphertext {
    Uint64(FheUint64),
    Bool(FheBool),
}

// Mapping for storing ciphertexts associated with unique B256 identifiers / handles.
pub type CiphertextStorage = Arc<RwLock<HashMap<B256, Ciphertext>>>;