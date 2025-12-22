use tfhe::{prelude::*, compact::CompactPublicKey};
use anyhow::Result;
use bincode;
use sha3::{Digest ,Keccak256};

pub fn encrypt(value: u64, pk: &CompactPublicKey) -> Result<Vec<u8>> {
    let ct: CompressedFheUint64 = CompressedFheUint64::try_encrypt(value, pk)?;
    Ok(bincode::serialize(&ct)?)
}

pub fn decrypt(ciphertext: &[u8], sk: &ClientKey) -> Result<u64> {
    let ct: CompressedFheUint64 = bincode::deserialize(ciphertext)?;
    let decrypted_value = ct.decrypt(sk)?;
    Ok(decrypted_value)
}

pub fn compute_handle(ciphertext_bytes: &[u8]) -> [u8; 32] {
    let mut hasher = Keccak256::new();
    hasher.update(ciphertext_bytes);
    hasher.finalize().into()
}