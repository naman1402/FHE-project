//! Event Signatures
//!
//! Keccak256 hashes of FHE event signatures for matching topic0.
//! These are computed from the event signatures in FHEEvents.sol.

use alloy::primitives::{keccak256, B256};
use once_cell::sync::Lazy;

fn event_sig(sig: &str) -> B256 {
    keccak256(sig.as_bytes())
}

// Binary operations: FheOp(address indexed caller, bytes32 lhs, bytes32 rhs, bytes1 scalarByte, bytes32 result)
pub static FHE_ADD: Lazy<B256> =
    Lazy::new(|| event_sig("FheAdd(address,bytes32,bytes32,bytes1,bytes32)"));
pub static FHE_SUB: Lazy<B256> =
    Lazy::new(|| event_sig("FheSub(address,bytes32,bytes32,bytes1,bytes32)"));
pub static FHE_MUL: Lazy<B256> =
    Lazy::new(|| event_sig("FheMul(address,bytes32,bytes32,bytes1,bytes32)"));
pub static FHE_DIV: Lazy<B256> =
    Lazy::new(|| event_sig("FheDiv(address,bytes32,bytes32,bytes1,bytes32)"));
pub static FHE_REM: Lazy<B256> =
    Lazy::new(|| event_sig("FheRem(address,bytes32,bytes32,bytes1,bytes32)"));
pub static FHE_BIT_AND: Lazy<B256> =
    Lazy::new(|| event_sig("FheBitAnd(address,bytes32,bytes32,bytes1,bytes32)"));
pub static FHE_BIT_OR: Lazy<B256> =
    Lazy::new(|| event_sig("FheBitOr(address,bytes32,bytes32,bytes1,bytes32)"));
pub static FHE_BIT_XOR: Lazy<B256> =
    Lazy::new(|| event_sig("FheBitXor(address,bytes32,bytes32,bytes1,bytes32)"));
pub static FHE_SHL: Lazy<B256> =
    Lazy::new(|| event_sig("FheShl(address,bytes32,bytes32,bytes1,bytes32)"));
pub static FHE_SHR: Lazy<B256> =
    Lazy::new(|| event_sig("FheShr(address,bytes32,bytes32,bytes1,bytes32)"));
pub static FHE_ROTL: Lazy<B256> =
    Lazy::new(|| event_sig("FheRotl(address,bytes32,bytes32,bytes1,bytes32)"));
pub static FHE_ROTR: Lazy<B256> =
    Lazy::new(|| event_sig("FheRotr(address,bytes32,bytes32,bytes1,bytes32)"));
pub static FHE_EQ: Lazy<B256> =
    Lazy::new(|| event_sig("FheEq(address,bytes32,bytes32,bytes1,bytes32)"));
pub static FHE_NE: Lazy<B256> =
    Lazy::new(|| event_sig("FheNe(address,bytes32,bytes32,bytes1,bytes32)"));
pub static FHE_GE: Lazy<B256> =
    Lazy::new(|| event_sig("FheGe(address,bytes32,bytes32,bytes1,bytes32)"));
pub static FHE_GT: Lazy<B256> =
    Lazy::new(|| event_sig("FheGt(address,bytes32,bytes32,bytes1,bytes32)"));
pub static FHE_LE: Lazy<B256> =
    Lazy::new(|| event_sig("FheLe(address,bytes32,bytes32,bytes1,bytes32)"));
pub static FHE_LT: Lazy<B256> =
    Lazy::new(|| event_sig("FheLt(address,bytes32,bytes32,bytes1,bytes32)"));
pub static FHE_MIN: Lazy<B256> =
    Lazy::new(|| event_sig("FheMin(address,bytes32,bytes32,bytes1,bytes32)"));
pub static FHE_MAX: Lazy<B256> =
    Lazy::new(|| event_sig("FheMax(address,bytes32,bytes32,bytes1,bytes32)"));
pub static FHE_NEG: Lazy<B256> = Lazy::new(|| event_sig("FheNeg(address,bytes32,bytes32)"));
pub static FHE_NOT: Lazy<B256> = Lazy::new(|| event_sig("FheNot(address,bytes32,bytes32)"));
pub static TRIVIAL_ENCRYPT: Lazy<B256> =
    Lazy::new(|| event_sig("TrivialEncrypt(address,uint256,uint8,bytes32)"));
pub static CAST: Lazy<B256> = Lazy::new(|| event_sig("Cast(address,bytes32,uint8,bytes32)"));
pub static FHE_IF_THEN_ELSE: Lazy<B256> =
    Lazy::new(|| event_sig("FheIfThenElse(address,bytes32,bytes32,bytes32,bytes32)"));
pub static VERIFY_INPUT: Lazy<B256> =
    Lazy::new(|| event_sig("VerifyInput(address,bytes32,address,bytes,uint8,bytes32)"));
pub static FHE_RAND: Lazy<B256> =
    Lazy::new(|| event_sig("FheRand(address,uint8,bytes16,bytes32)"));
pub static FHE_RAND_BOUNDED: Lazy<B256> =
    Lazy::new(|| event_sig("FheRandBounded(address,uint256,uint8,bytes16,bytes32)"));

/// Check if a topic0 matches any known FHE event
pub fn is_known_fhe_event(topic0: &B256) -> bool {
    *topic0 == *FHE_ADD
        || *topic0 == *FHE_SUB
        || *topic0 == *FHE_MUL
        || *topic0 == *FHE_DIV
        || *topic0 == *FHE_REM
        || *topic0 == *FHE_BIT_AND
        || *topic0 == *FHE_BIT_OR
        || *topic0 == *FHE_BIT_XOR
        || *topic0 == *FHE_SHL
        || *topic0 == *FHE_SHR
        || *topic0 == *FHE_ROTL
        || *topic0 == *FHE_ROTR
        || *topic0 == *FHE_EQ
        || *topic0 == *FHE_NE
        || *topic0 == *FHE_GE
        || *topic0 == *FHE_GT
        || *topic0 == *FHE_LE
        || *topic0 == *FHE_LT
        || *topic0 == *FHE_MIN
        || *topic0 == *FHE_MAX
        || *topic0 == *FHE_NEG
        || *topic0 == *FHE_NOT
        || *topic0 == *TRIVIAL_ENCRYPT
        || *topic0 == *CAST
        || *topic0 == *FHE_IF_THEN_ELSE
        || *topic0 == *VERIFY_INPUT
        || *topic0 == *FHE_RAND
        || *topic0 == *FHE_RAND_BOUNDED
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_event_signatures() {
        // Print signatures for verification
        println!("FheAdd:          {:?}", *FHE_ADD);
        println!("FheSub:          {:?}", *FHE_SUB);
        println!("FheMul:          {:?}", *FHE_MUL);
        println!("FheLe:           {:?}", *FHE_LE);
        println!("TrivialEncrypt:  {:?}", *TRIVIAL_ENCRYPT);
        println!("FheIfThenElse:   {:?}", *FHE_IF_THEN_ELSE);

        // Verify they're all unique
        let sigs = vec![
            *FHE_ADD,
            *FHE_SUB,
            *FHE_MUL,
            *FHE_LE,
            *TRIVIAL_ENCRYPT,
            *FHE_IF_THEN_ELSE,
        ];
        for (i, sig1) in sigs.iter().enumerate() {
            for (j, sig2) in sigs.iter().enumerate() {
                if i != j {
                    assert_ne!(sig1, sig2, "Signatures at {} and {} should differ", i, j);
                }
            }
        }
    }
}
