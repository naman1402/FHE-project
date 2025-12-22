use anyhow::Result;
use sha3::{Digest, Keccak256};
use tfhe::{prelude::*, ClientKey, CompactPublicKey};

/// Encrypt a u64 value using the public key
pub fn encrypt(value: u64, pk: &CompactPublicKey) -> Result<Vec<u8>> {
    let ct = tfhe::CompactCiphertextList::builder(pk)
        .push(value)
        .build();
    Ok(bincode::serialize(&ct)?)
}

/// Decrypt ciphertext bytes using the client key (for testing only)
/// @note  This is for testing, in production decryption happens on the coprocessor side
pub fn decrypt(ciphertext: &[u8], sk: &ClientKey) -> Result<u64> {
    let ct: tfhe::CompactCiphertextList = bincode::deserialize(ciphertext)?;
    let expanded = ct.expand()?;
    let value: tfhe::FheUint64 = expanded.get(0)?.ok_or(anyhow::anyhow!("No value in ciphertext"))?;
    let decrypted_value: u64 = value.decrypt(sk);
    Ok(decrypted_value)
}

/// Compute a handle (keccak256 hash) from ciphertext bytes
/// This handle is used to track ciphertexts on-chain
pub fn compute_handle(ciphertext_bytes: &[u8]) -> [u8; 32] {
    let mut hasher = Keccak256::new();
    hasher.update(ciphertext_bytes);
    hasher.finalize().into()
}