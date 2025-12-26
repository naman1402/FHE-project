use crate::fhe::types::{CiphertextStorage, Ciphertext};
use crate::events::types::{BinaryOpType, FheOperation, IfThenElseOp, TrivialEncryptOp, UnaryOpType};
use tfhe::{ServerKey};

pub struct Engine {
    pub server_key: ServerKey,
    pub storage: CiphertextStorage,
}

impl Engine {
    pub fn new(server_key: ServerKey, storage: CiphertextStorage) -> Self {
        Self { server_key, storage }
    }

    pub fn handle_operation(&self, op: &FheOperation) -> Result<()> {
        match op {}
        Ok(())
    }
}