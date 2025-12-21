//! FHE Event Parser
//! Event signatures match those in FHEEvents.sol from Zama's fhevm.

use super::signatures::*;
use super::types::*;
use alloy::primitives::{Address, B256, U256};
use alloy::rpc::types::Log;

/// Parse a raw log into a structured FHE operation
pub fn parse_fhe_event(log: &Log) -> Option<FheOperation> {
    let topics = log.topics();

    if topics.is_empty() {
        return None;
    }

    let topic0 = &topics[0];
    let data = &log.data().data;
    let metadata = EventMetadata {
        block_number: log.block_number.unwrap_or(0),
        tx_hash: log.transaction_hash,
        log_index: log.log_index.unwrap_or(0),
        // Caller is indexed (topic1), extract from topics if available
        caller: if topics.len() > 1 {
            Address::from_slice(&topics[1].as_slice()[12..])
        } else {
            Address::ZERO
        },
    };

    let operation = if *topic0 == *FHE_ADD {
        parse_binary_op(BinaryOpType::Add, metadata, data)
    } else if *topic0 == *FHE_SUB {
        parse_binary_op(BinaryOpType::Sub, metadata, data)
    } else if *topic0 == *FHE_MUL {
        parse_binary_op(BinaryOpType::Mul, metadata, data)
    } else if *topic0 == *FHE_DIV {
        parse_binary_op(BinaryOpType::Div, metadata, data)
    } else if *topic0 == *FHE_REM {
        parse_binary_op(BinaryOpType::Rem, metadata, data)
    } else if *topic0 == *FHE_BIT_AND {
        parse_binary_op(BinaryOpType::BitAnd, metadata, data)
    } else if *topic0 == *FHE_BIT_OR {
        parse_binary_op(BinaryOpType::BitOr, metadata, data)
    } else if *topic0 == *FHE_BIT_XOR {
        parse_binary_op(BinaryOpType::BitXor, metadata, data)
    } else if *topic0 == *FHE_SHL {
        parse_binary_op(BinaryOpType::Shl, metadata, data)
    } else if *topic0 == *FHE_SHR {
        parse_binary_op(BinaryOpType::Shr, metadata, data)
    } else if *topic0 == *FHE_ROTL {
        parse_binary_op(BinaryOpType::Rotl, metadata, data)
    } else if *topic0 == *FHE_ROTR {
        parse_binary_op(BinaryOpType::Rotr, metadata, data)
    } else if *topic0 == *FHE_EQ {
        parse_binary_op(BinaryOpType::Eq, metadata, data)
    } else if *topic0 == *FHE_NE {
        parse_binary_op(BinaryOpType::Ne, metadata, data)
    } else if *topic0 == *FHE_GE {
        parse_binary_op(BinaryOpType::Ge, metadata, data)
    } else if *topic0 == *FHE_GT {
        parse_binary_op(BinaryOpType::Gt, metadata, data)
    } else if *topic0 == *FHE_LE {
        parse_binary_op(BinaryOpType::Le, metadata, data)
    } else if *topic0 == *FHE_LT {
        parse_binary_op(BinaryOpType::Lt, metadata, data)
    } else if *topic0 == *FHE_MIN {
        parse_binary_op(BinaryOpType::Min, metadata, data)
    } else if *topic0 == *FHE_MAX {
        parse_binary_op(BinaryOpType::Max, metadata, data)
    } else if *topic0 == *FHE_NEG {
        parse_unary_op(UnaryOpType::Neg, metadata, data)
    } else if *topic0 == *FHE_NOT {
        parse_unary_op(UnaryOpType::Not, metadata, data)
    } else if *topic0 == *TRIVIAL_ENCRYPT {
        parse_trivial_encrypt(metadata, data)
    } else if *topic0 == *CAST {
        parse_cast(metadata, data)
    } else if *topic0 == *FHE_IF_THEN_ELSE {
        parse_if_then_else(metadata, data)
    } else if *topic0 == *VERIFY_INPUT {
        parse_verify_input(metadata, data)
    } else if *topic0 == *FHE_RAND {
        parse_fhe_rand(metadata, data)
    } else if *topic0 == *FHE_RAND_BOUNDED {
        parse_fhe_rand_bounded(metadata, data)
    } else {
        Some(FheOperation::Unknown {
            topic0: *topic0,
            data: data.to_vec(),
        })
    };

    operation
}

/// Parse binary operation data
/// Layout: lhs (32) + rhs (32) + scalarByte (32, padded) + result (32)
fn parse_binary_op(op_type: BinaryOpType, metadata: EventMetadata, data: &[u8]) -> Option<FheOperation> {
    if data.len() < 128 {
        return None;
    }

    let lhs = B256::from_slice(&data[0..32]);
    let rhs = B256::from_slice(&data[32..64]);
    let scalar_byte = data[95]; // Last byte of the 32-byte padded scalar
    let result = B256::from_slice(&data[96..128]);

    Some(FheOperation::Binary(BinaryOp {
        metadata,
        op_type,
        lhs,
        rhs,
        scalar_byte,
        result,
    }))
}

/// Parse unary operation data
/// Layout: ct (32) + result (32)
fn parse_unary_op(op_type: UnaryOpType, metadata: EventMetadata, data: &[u8]) -> Option<FheOperation> {
    if data.len() < 64 {
        return None;
    }

    let ct = B256::from_slice(&data[0..32]);
    let result = B256::from_slice(&data[32..64]);

    Some(FheOperation::Unary(UnaryOp {
        metadata,
        op_type,
        ct,
        result,
    }))
}

/// Parse TrivialEncrypt data
/// Layout: pt (32) + toType (32, padded u8) + result (32)
fn parse_trivial_encrypt(metadata: EventMetadata, data: &[u8]) -> Option<FheOperation> {
    if data.len() < 96 {
        return None;
    }

    let plaintext = U256::from_be_slice(&data[0..32]);
    let to_type_byte = data[63]; // Last byte of padded u8
    let to_type = FheType::from_u8(to_type_byte)?;
    let result = B256::from_slice(&data[64..96]);

    Some(FheOperation::TrivialEncrypt(TrivialEncrypt {
        metadata,
        plaintext,
        to_type,
        result,
    }))
}

/// Parse Cast data
/// Layout: ct (32) + toType (32, padded u8) + result (32)
fn parse_cast(metadata: EventMetadata, data: &[u8]) -> Option<FheOperation> {
    if data.len() < 96 {
        return None;
    }

    let ct = B256::from_slice(&data[0..32]);
    let to_type_byte = data[63];
    let to_type = FheType::from_u8(to_type_byte)?;
    let result = B256::from_slice(&data[64..96]);

    Some(FheOperation::Cast(Cast {
        metadata,
        ct,
        to_type,
        result,
    }))
}

/// Parse FheIfThenElse data
/// Layout: control (32) + ifTrue (32) + ifFalse (32) + result (32)
fn parse_if_then_else(metadata: EventMetadata, data: &[u8]) -> Option<FheOperation> {
    if data.len() < 128 {
        return None;
    }

    let control = B256::from_slice(&data[0..32]);
    let if_true = B256::from_slice(&data[32..64]);
    let if_false = B256::from_slice(&data[64..96]);
    let result = B256::from_slice(&data[96..128]);

    Some(FheOperation::IfThenElse(IfThenElse {
        metadata,
        control,
        if_true,
        if_false,
        result,
    }))
}

/// Parse VerifyInput data
/// Layout: inputHandle (32) + userAddress (32, padded) + inputProof offset (32) + inputType (32) + result (32) + inputProof data...
fn parse_verify_input(metadata: EventMetadata, data: &[u8]) -> Option<FheOperation> {
    if data.len() < 160 {
        return None;
    }

    let input_handle = B256::from_slice(&data[0..32]);
    let user_address = Address::from_slice(&data[44..64]); // Last 20 bytes of padded address
    // Skip inputProof offset at 64..96
    let input_type_byte = data[127]; // Last byte of padded u8
    let input_type = FheType::from_u8(input_type_byte)?;
    let result = B256::from_slice(&data[128..160]);

    // Parse dynamic inputProof if present
    let input_proof = if data.len() > 160 {
        // Read offset and length from ABI encoding
        let offset = U256::from_be_slice(&data[64..96]).to::<usize>();
        if offset + 32 <= data.len() {
            let len = U256::from_be_slice(&data[offset..offset + 32]).to::<usize>();
            if offset + 32 + len <= data.len() {
                data[offset + 32..offset + 32 + len].to_vec()
            } else {
                vec![]
            }
        } else {
            vec![]
        }
    } else {
        vec![]
    };

    Some(FheOperation::VerifyInput(VerifyInput {
        metadata,
        input_handle,
        user_address,
        input_proof,
        input_type,
        result,
    }))
}

/// Parse FheRand data
/// Layout: randType (32, padded u8) + seed (32, first 16 bytes) + result (32)
fn parse_fhe_rand(metadata: EventMetadata, data: &[u8]) -> Option<FheOperation> {
    if data.len() < 96 {
        return None;
    }

    let rand_type_byte = data[31];
    let rand_type = FheType::from_u8(rand_type_byte)?;
    let mut seed = [0u8; 16];
    seed.copy_from_slice(&data[32..48]);
    let result = B256::from_slice(&data[64..96]);

    Some(FheOperation::Rand(FheRand {
        metadata,
        rand_type,
        seed,
        result,
    }))
}

/// Parse FheRandBounded data
/// Layout: upperBound (32) + randType (32, padded u8) + seed (32, first 16 bytes) + result (32)
fn parse_fhe_rand_bounded(metadata: EventMetadata, data: &[u8]) -> Option<FheOperation> {
    if data.len() < 128 {
        return None;
    }

    let upper_bound = U256::from_be_slice(&data[0..32]);
    let rand_type_byte = data[63];
    let rand_type = FheType::from_u8(rand_type_byte)?;
    let mut seed = [0u8; 16];
    seed.copy_from_slice(&data[64..80]);
    let result = B256::from_slice(&data[96..128]);

    Some(FheOperation::RandBounded(FheRandBounded {
        metadata,
        upper_bound,
        rand_type,
        seed,
        result,
    }))
}

/// Log a parsed FHE operation in a human-readable format
pub fn log_fhe_operation(op: &FheOperation) {
    match op {
        FheOperation::TrivialEncrypt(enc) => {
            println!(
                "[parser] op=TrivialEncrypt block={} tx={} caller={} pt={} type={} result={}",
                enc.metadata.block_number,
                short_tx(enc.metadata.tx_hash),
                enc.metadata.caller,
                enc.plaintext,
                enc.to_type.name(),
                short_b256(enc.result)
            );
        }
        FheOperation::Binary(bin) => {
            println!(
                "[parser] op={} block={} tx={} caller={} lhs={} rhs={} scalar={} result={}",
                bin.op_type.name(),
                bin.metadata.block_number,
                short_tx(bin.metadata.tx_hash),
                bin.metadata.caller,
                short_b256(bin.lhs),
                short_b256(bin.rhs),
                if bin.scalar_byte == 1 { "true" } else { "false" },
                short_b256(bin.result)
            );
        }
        FheOperation::Unary(un) => {
            println!(
                "[parser] op={} block={} tx={} caller={} input={} result={}",
                un.op_type.name(),
                un.metadata.block_number,
                short_tx(un.metadata.tx_hash),
                un.metadata.caller,
                short_b256(un.ct),
                short_b256(un.result)
            );
        }
        FheOperation::IfThenElse(ite) => {
            println!(
                "[parser] op=FheIfThenElse block={} tx={} caller={} ctrl={} true={} false={} result={}",
                ite.metadata.block_number,
                short_tx(ite.metadata.tx_hash),
                ite.metadata.caller,
                short_b256(ite.control),
                short_b256(ite.if_true),
                short_b256(ite.if_false),
                short_b256(ite.result)
            );
        }
        FheOperation::Cast(cast) => {
            println!(
                "[parser] op=Cast block={} tx={} caller={} input={} toType={} result={}",
                cast.metadata.block_number,
                short_tx(cast.metadata.tx_hash),
                cast.metadata.caller,
                short_b256(cast.ct),
                cast.to_type.name(),
                short_b256(cast.result)
            );
        }
        FheOperation::VerifyInput(vi) => {
            println!(
                "[parser] op=VerifyInput block={} tx={} caller={} handle={} user={} type={} proof_len={} result={}",
                vi.metadata.block_number,
                short_tx(vi.metadata.tx_hash),
                vi.metadata.caller,
                short_b256(vi.input_handle),
                vi.user_address,
                vi.input_type.name(),
                vi.input_proof.len(),
                short_b256(vi.result)
            );
        }
        FheOperation::Rand(r) => {
            println!(
                "[parser] op=FheRand block={} tx={} caller={} type={} seed={} result={}",
                r.metadata.block_number,
                short_tx(r.metadata.tx_hash),
                r.metadata.caller,
                r.rand_type.name(),
                hex::encode(&r.seed[..4]), // short seed preview
                short_b256(r.result)
            );
        }
        FheOperation::RandBounded(r) => {
            println!(
                "[parser] op=FheRandBounded block={} tx={} caller={} upperBound={} type={} seed={} result={}",
                r.metadata.block_number,
                short_tx(r.metadata.tx_hash),
                r.metadata.caller,
                r.upper_bound,
                r.rand_type.name(),
                hex::encode(&r.seed[..4]),
                short_b256(r.result)
            );
        }
        FheOperation::Unknown { topic0, data } => {
            println!(
                "[parser] op=Unknown topic0={} data_len={}",
                short_b256(*topic0),
                data.len()
            );
        }
    }
}

fn short_b256(value: B256) -> String {
    let hex_str = hex::encode(value);
    format!("0x{}...", &hex_str[..8])
}

fn short_tx(tx: Option<B256>) -> String {
    match tx {
        Some(h) => {
            let hex_str = hex::encode(h);
            format!("0x{}...", &hex_str[..8])
        }
        None => "N/A".to_string(),
    }
}

/// Legacy function for backward compatibility
pub fn log_executor_event(log: &Log) {
    match parse_fhe_event(log) {
        Some(op) => log_fhe_operation(&op),
        None => {
            println!("[Parser] Failed to parse event from {:?}", log.address());
        }
    }
}
