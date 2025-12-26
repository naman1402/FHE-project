//! FHE Engine - Executes FHE operations using TFHE-rs
//! 
//! ## How FHE Operations Work
//!
//! In Fully Homomorphic Encryption (FHE), computations happen on encrypted data:
//! - **Ciphertexts** are encrypted values that can be operated on without decryption
//! - **ServerKey** allows computation on ciphertexts (but not decryption)
//! - **Handles** (B256) are unique identifiers linking on-chain references to off-chain ciphertexts
//!
//! When a smart contract calls `TFHE.add(a, b)`:
//! 1. The FHEVMExecutor emits an `FheAdd` event with handles for a, b, and result
//! 2. This engine fetches ciphertexts for a and b from storage
//! 3. Performs encrypted addition: `ct_result = ct_a + ct_b`
//! 4. Stores ct_result under the result handle
//!
//! The result can later be decrypted via the KMS or used in further operations.

use crate::events::types::{ 
    BinaryOp, BinaryOpType, Cast, FheOperation, FheRand, FheRandBounded, FheType, IfThenElse,
    TrivialEncrypt, UnaryOp, UnaryOpType, VerifyInput,
};
use crate::fhe::types::{Ciphertext, CiphertextStorage};
use alloy::primitives::B256;
use anyhow::{bail, Context, Result};
use tfhe::prelude::*;
use tfhe::{set_server_key, FheBool, FheUint64, ServerKey};
use tfhe::prelude::IfThenElse as _; // Ensure trait is in scope

/// FHE computation engine
pub struct Engine {
    pub storage: CiphertextStorage,
}

impl Engine {
    pub fn new(server_key: ServerKey, storage: CiphertextStorage) -> Self {
        set_server_key(server_key);
        Self { storage }
    }

    pub fn handle_operation(&self, op: &FheOperation) -> Result<()> {
        match op {
            FheOperation::TrivialEncrypt(enc) => self.handle_trivial_encrypt(enc),
            FheOperation::Binary(bin) => self.handle_binary_op(bin),
            FheOperation::Unary(un) => self.handle_unary_op(un),
            FheOperation::IfThenElse(ite) => self.handle_if_then_else(ite),
            FheOperation::Cast(cast) => self.handle_cast(cast),
            FheOperation::VerifyInput(vi) => self.handle_verify_input(vi),
            FheOperation::Rand(r) => self.handle_rand(r),
            FheOperation::RandBounded(rb) => self.handle_rand_bounded(rb),
            FheOperation::Unknown { topic0, .. } => {
                println!("[Engine] Skipping unknown operation: {:?}", topic0);
                Ok(())
            }
        }
    }

    fn handle_trivial_encrypt(&self, op: &TrivialEncrypt) -> Result<()> {
        let ct = match op.to_type {
            FheType::Bool => {
                // Convert U256 to bool: 0 = false, anything else = true
                println!("[Engine] TrivialEncrypt: converting plaintext to Bool");
                let val = !op.plaintext.is_zero();
                Ciphertext::Bool(FheBool::encrypt_trivial(val))
            }
            FheType::Uint64 => {
                println!("[Engine] TrivialEncrypt: converting plaintext to Uint64");
                let val: u64 = op
                    .plaintext
                    .try_into()
                    .context("Plaintext too large for u64")?;
                Ciphertext::Uint64(FheUint64::encrypt_trivial(val))
            }
            _ => {
                println!(
                    "[Engine] TrivialEncrypt: unsupported type {:?}, using Uint64",
                    op.to_type
                );
                let val: u64 = op.plaintext.try_into().unwrap_or(u64::MAX);
                Ciphertext::Uint64(FheUint64::encrypt_trivial(val))
            }
        };

        self.store(op.result, ct);
        println!(
            "[Engine] TrivialEncrypt: {} -> handle {}",
            op.plaintext,
            short_handle(op.result)
        );
        Ok(())
    }

    // ============================================================================
    // BINARY OPERATIONS
    // ============================================================================
    //
    // Binary ops take two ciphertexts (or one ciphertext + scalar) and produce a result.
    //
    // Arithmetic: Add, Sub, Mul, Div, Rem, Min, Max
    // Bitwise: BitAnd, BitOr, BitXor, Shl, Shr, Rotl, Rotr
    // Comparison: Eq, Ne, Ge, Gt, Le, Lt (produce FheBool)
    //
    // The `scalar_byte` field indicates if `rhs` is a plaintext scalar (1) or ciphertext (0).

    fn handle_binary_op(&self, op: &BinaryOp) -> Result<()> {
        let is_scalar = op.scalar_byte == 1;
        if is_scalar {
            self.handle_binary_scalar(op)
        } else {
            self.handle_binary_ct_ct(op)
        }
    }

    /// Binary operation: ciphertext OP ciphertext
    fn handle_binary_ct_ct(&self, op: &BinaryOp) -> Result<()> {
        // Comparison operations return FheBool
        let is_comparison = matches!(
            op.op_type,
            BinaryOpType::Eq
                | BinaryOpType::Ne
                | BinaryOpType::Ge
                | BinaryOpType::Gt
                | BinaryOpType::Le
                | BinaryOpType::Lt
        );

        if is_comparison {
            let lhs = self.get_u64(op.lhs)?;
            let rhs = self.get_u64(op.rhs)?;

            let result_bool = match op.op_type {
                BinaryOpType::Eq => lhs.eq(&rhs),
                BinaryOpType::Ne => lhs.ne(&rhs),
                BinaryOpType::Ge => lhs.ge(&rhs),
                BinaryOpType::Gt => lhs.gt(&rhs),
                BinaryOpType::Le => lhs.le(&rhs),
                BinaryOpType::Lt => lhs.lt(&rhs),
                _ => unreachable!(),
            };

            self.store(op.result, Ciphertext::Bool(result_bool));
        } else {
            // Arithmetic/bitwise operations return FheUint64
            let lhs = self.get_u64(op.lhs)?;
            let rhs = self.get_u64(op.rhs)?;

            let result = match op.op_type {
                BinaryOpType::Add => &lhs + &rhs,
                BinaryOpType::Sub => &lhs - &rhs,
                BinaryOpType::Mul => &lhs * &rhs,
                BinaryOpType::Div => &lhs / &rhs,
                BinaryOpType::Rem => &lhs % &rhs,
                BinaryOpType::BitAnd => &lhs & &rhs,
                BinaryOpType::BitOr => &lhs | &rhs,
                BinaryOpType::BitXor => &lhs ^ &rhs,
                BinaryOpType::Shl => &lhs << &rhs,
                BinaryOpType::Shr => &lhs >> &rhs,
                BinaryOpType::Min => lhs.min(&rhs),
                BinaryOpType::Max => lhs.max(&rhs),
                BinaryOpType::Rotl | BinaryOpType::Rotr => {
                    println!("[Engine] Rotate ops not yet implemented");
                    lhs // Return lhs unchanged for now
                }
                _ => bail!("Unexpected comparison op in arithmetic handler"),
            };

            self.store(op.result, Ciphertext::Uint64(result));
        }

        println!(
            "[Engine] {} ct_ct: {} OP {} -> {}",
            op.op_type.name(),
            short_handle(op.lhs),
            short_handle(op.rhs),
            short_handle(op.result)
        );
        Ok(())
    }

    /// Binary operation: ciphertext OP scalar (plaintext)
    fn handle_binary_scalar(&self, op: &BinaryOp) -> Result<()> {
        let lhs = self.get_u64(op.lhs)?;
        let scalar_bytes = op.rhs.as_slice();
        let scalar = u64::from_be_bytes(scalar_bytes[24..32].try_into().unwrap());

        let is_comparison = matches!(
            op.op_type,
            BinaryOpType::Eq
                | BinaryOpType::Ne
                | BinaryOpType::Ge
                | BinaryOpType::Gt
                | BinaryOpType::Le
                | BinaryOpType::Lt
        );

        if is_comparison {
            let result_bool = match op.op_type {
                BinaryOpType::Eq => lhs.eq(scalar),
                BinaryOpType::Ne => lhs.ne(scalar),
                BinaryOpType::Ge => lhs.ge(scalar),
                BinaryOpType::Gt => lhs.gt(scalar),
                BinaryOpType::Le => lhs.le(scalar),
                BinaryOpType::Lt => lhs.lt(scalar),
                _ => unreachable!(),
            };
            self.store(op.result, Ciphertext::Bool(result_bool));
        } else {
            let result = match op.op_type {
                BinaryOpType::Add => lhs + scalar,
                BinaryOpType::Sub => lhs - scalar,
                BinaryOpType::Mul => lhs * scalar,
                BinaryOpType::Div => lhs / scalar,
                BinaryOpType::Rem => lhs % scalar,
                BinaryOpType::BitAnd => lhs & scalar,
                BinaryOpType::BitOr => lhs | scalar,
                BinaryOpType::BitXor => lhs ^ scalar,
                BinaryOpType::Shl => lhs << scalar,
                BinaryOpType::Shr => lhs >> scalar,
                BinaryOpType::Min => lhs.min(scalar),
                BinaryOpType::Max => lhs.max(scalar),
                BinaryOpType::Rotl | BinaryOpType::Rotr => {
                    println!("[Engine] Rotate ops not yet implemented");
                    lhs
                }
                _ => bail!("Unexpected comparison op in scalar arithmetic handler"),
            };
            self.store(op.result, Ciphertext::Uint64(result));
        }

        println!(
            "[Engine] {} scalar: {} OP {} -> {}",
            op.op_type.name(),
            short_handle(op.lhs),
            scalar,
            short_handle(op.result)
        );
        Ok(())
    }

    fn handle_unary_op(&self, op: &UnaryOp) -> Result<()> {
        let result = if let Ok(ct) = self.get_u64(op.ct) {
            match op.op_type {
                UnaryOpType::Neg => Ciphertext::Uint64(-ct),
                UnaryOpType::Not => Ciphertext::Uint64(!ct),
            }
        } else if let Ok(ct) = self.get_bool(op.ct) {
            match op.op_type {
                UnaryOpType::Not => Ciphertext::Bool(!ct),
                UnaryOpType::Neg => Ciphertext::Bool(!ct)
            }
        } else {
            bail!("Handle {} not found in storage", short_handle(op.ct));
        };

        self.store(op.result, result);
        println!(
            "[Engine] {}: {} -> {}",
            op.op_type.name(),
            short_handle(op.ct),
            short_handle(op.result)
        );
        Ok(())
    }

    fn handle_if_then_else(&self, op: &IfThenElse) -> Result<()> {
        let control = self.get_bool(op.control)?;
        let if_true = self.get_u64(op.if_true)?;
        let if_false = self.get_u64(op.if_false)?;
        let result = control.select(&if_true, &if_false);

        self.store(op.result, Ciphertext::Uint64(result));
        println!(
            "[Engine] IfThenElse: ctrl={} ? {} : {} -> {}",
            short_handle(op.control),
            short_handle(op.if_true),
            short_handle(op.if_false),
            short_handle(op.result)
        );
        Ok(())
    }

    fn handle_cast(&self, op: &Cast) -> Result<()> {

        let ct = self.get_any(op.ct)?;
        self.store(op.result, ct);
        println!(
            "[Engine] Cast: {} -> {} (type {:?})",
            short_handle(op.ct),
            short_handle(op.result),
            op.to_type
        );
        Ok(())
    }

    fn handle_verify_input(&self, op: &VerifyInput) -> Result<()> {
        println!(
            "[Engine] VerifyInput: handle={} user={} type={:?} proof_len={}",
            short_handle(op.input_handle),
            op.user_address,
            op.input_type,
            op.input_proof.len()
        );

        let ct = match op.input_type {
            FheType::Bool => Ciphertext::Bool(FheBool::encrypt_trivial(false)),
            _ => Ciphertext::Uint64(FheUint64::encrypt_trivial(0u64)),
        };

        self.store(op.result, ct);
        Ok(())
    }

    fn handle_rand(&self, op: &FheRand) -> Result<()> {
        Ok(())
    }

    fn handle_rand_bounded(&self, op: &FheRandBounded) -> Result<()> {
        Ok(())
    }

    // ============================================================================
    // STORAGE HELPERS
    // ============================================================================

    fn store(&self, handle: B256, ct: Ciphertext) {
        if let Ok(mut guard) = self.storage.write() {
            guard.insert(handle, ct);
        } else {
            println!("[Engine] Warning: failed to acquire storage write lock");
        }
    }

    fn get_u64(&self, handle: B256) -> Result<FheUint64> {
        let guard = self.storage.read().map_err(|_| anyhow::anyhow!("Lock poisoned"))?;
        match guard.get(&handle) {
            Some(Ciphertext::Uint64(ct)) => Ok(ct.clone()),
            Some(Ciphertext::Bool(_)) => bail!("Handle {} is Bool, expected Uint64", short_handle(handle)),
            None => bail!("Handle {} not found in storage", short_handle(handle)),
        }
    }

    fn get_bool(&self, handle: B256) -> Result<FheBool> {
        let guard = self.storage.read().map_err(|_| anyhow::anyhow!("Lock poisoned"))?;
        match guard.get(&handle) {
            Some(Ciphertext::Bool(ct)) => Ok(ct.clone()),
            Some(Ciphertext::Uint64(_)) => bail!("Handle {} is Uint64, expected Bool", short_handle(handle)),
            None => bail!("Handle {} not found in storage", short_handle(handle)),
        }
    }

    fn get_any(&self, handle: B256) -> Result<Ciphertext> {
        let guard = self.storage.read().map_err(|_| anyhow::anyhow!("Lock poisoned"))?;
        guard
            .get(&handle)
            .cloned()
            .ok_or_else(|| anyhow::anyhow!("Handle {} not found", short_handle(handle)))
    }

    pub fn storage_count(&self) -> usize {
        self.storage.read().map(|g| g.len()).unwrap_or(0)
    }
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/// Shorten a B256 handle for logging (first 8 hex chars)
fn short_handle(h: B256) -> String {
    format!("0x{}...", &hex::encode(h)[..8])
}