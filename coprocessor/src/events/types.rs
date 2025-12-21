//! FHE Event Types
//! Rust struct representations of FHE operation events from FHEVMExecutor.
//! These match the events defined in Zama's FHEEvents.sol contract.

use alloy::primitives::{Address, B256, U256};

pub type Handle = B256;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum FheType {
    Bool = 0,
    Uint4 = 1,
    Uint8 = 2,
    Uint16 = 3,
    Uint32 = 4,
    Uint64 = 5,
    Uint128 = 6,
    Uint160 = 7,
    Uint256 = 8,
    Bytes64 = 9,
    Bytes128 = 10,
    Bytes256 = 11,
}

impl FheType {
    pub fn from_u8(value: u8) -> Option<Self> {
        match value {
            0 => Some(FheType::Bool),
            1 => Some(FheType::Uint4),
            2 => Some(FheType::Uint8),
            3 => Some(FheType::Uint16),
            4 => Some(FheType::Uint32),
            5 => Some(FheType::Uint64),
            6 => Some(FheType::Uint128),
            7 => Some(FheType::Uint160),
            8 => Some(FheType::Uint256),
            9 => Some(FheType::Bytes64),
            10 => Some(FheType::Bytes128),
            11 => Some(FheType::Bytes256),
            _ => None,
        }
    }

    pub fn name(&self) -> &'static str {
        match self {
            FheType::Bool => "ebool",
            FheType::Uint4 => "euint4",
            FheType::Uint8 => "euint8",
            FheType::Uint16 => "euint16",
            FheType::Uint32 => "euint32",
            FheType::Uint64 => "euint64",
            FheType::Uint128 => "euint128",
            FheType::Uint160 => "eaddress",
            FheType::Uint256 => "euint256",
            FheType::Bytes64 => "ebytes64",
            FheType::Bytes128 => "ebytes128",
            FheType::Bytes256 => "ebytes256",
        }
    }
}

#[derive(Debug, Clone)]
pub struct EventMetadata {
    pub block_number: u64,
    pub tx_hash: Option<B256>,
    pub log_index: u64,
    pub caller: Address,
}

/// Binary FHE operation (add, sub, mul, div, etc.)
/// Events: FheAdd, FheSub, FheMul, FheDiv, FheRem, FheBitAnd, FheBitOr, FheBitXor,
///         FheShl, FheShr, FheRotl, FheRotr, FheEq, FheNe, FheGe, FheGt, FheLe, FheLt,
///         FheMin, FheMax
#[derive(Debug, Clone)]
pub struct BinaryOp {
    pub metadata: EventMetadata,
    pub op_type: BinaryOpType,
    pub lhs: Handle,
    pub rhs: Handle,
    pub scalar_byte: u8,
    pub result: Handle,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BinaryOpType {
    Add,
    Sub,
    Mul,
    Div,
    Rem,
    BitAnd,
    BitOr,
    BitXor,
    Shl,
    Shr,
    Rotl,
    Rotr,
    Eq,
    Ne,
    Ge,
    Gt,
    Le,
    Lt,
    Min,
    Max,
}

impl BinaryOpType {
    pub fn name(&self) -> &'static str {
        match self {
            BinaryOpType::Add => "FheAdd",
            BinaryOpType::Sub => "FheSub",
            BinaryOpType::Mul => "FheMul",
            BinaryOpType::Div => "FheDiv",
            BinaryOpType::Rem => "FheRem",
            BinaryOpType::BitAnd => "FheBitAnd",
            BinaryOpType::BitOr => "FheBitOr",
            BinaryOpType::BitXor => "FheBitXor",
            BinaryOpType::Shl => "FheShl",
            BinaryOpType::Shr => "FheShr",
            BinaryOpType::Rotl => "FheRotl",
            BinaryOpType::Rotr => "FheRotr",
            BinaryOpType::Eq => "FheEq",
            BinaryOpType::Ne => "FheNe",
            BinaryOpType::Ge => "FheGe",
            BinaryOpType::Gt => "FheGt",
            BinaryOpType::Le => "FheLe",
            BinaryOpType::Lt => "FheLt",
            BinaryOpType::Min => "FheMin",
            BinaryOpType::Max => "FheMax",
        }
    }
}

/// Unary FHE operation (neg, not)
/// Events: FheNeg, FheNot
#[derive(Debug, Clone)]
pub struct UnaryOp {
    pub metadata: EventMetadata,
    pub op_type: UnaryOpType,
    pub ct: Handle,
    pub result: Handle,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UnaryOpType {
    Neg,
    Not,
}

impl UnaryOpType {
    pub fn name(&self) -> &'static str {
        match self {
            UnaryOpType::Neg => "FheNeg",
            UnaryOpType::Not => "FheNot",
        }
    }
}

/// Trivial encryption of a plaintext value
/// Event: TrivialEncrypt(address indexed caller, uint256 pt, FheType toType, bytes32 result)
#[derive(Debug, Clone)]
pub struct TrivialEncrypt {
    pub metadata: EventMetadata,
    pub plaintext: U256,
    pub to_type: FheType,
    pub result: Handle,
}

/// Cast operation between FHE types
/// Event: Cast(address indexed caller, bytes32 ct, FheType toType, bytes32 result)
#[derive(Debug, Clone)]
pub struct Cast {
    pub metadata: EventMetadata,
    pub ct: Handle,
    pub to_type: FheType,
    pub result: Handle,
}

/// Conditional select operation
/// Event: FheIfThenElse(address indexed caller, bytes32 control, bytes32 ifTrue, bytes32 ifFalse, bytes32 result)
#[derive(Debug, Clone)]
pub struct IfThenElse {
    pub metadata: EventMetadata,
    pub control: Handle,
    pub if_true: Handle,
    pub if_false: Handle,
    pub result: Handle,
}

/// Input verification (client-side encrypted input)
/// Event: VerifyInput(address indexed caller, bytes32 inputHandle, address userAddress, bytes inputProof, FheType inputType, bytes32 result)
#[derive(Debug, Clone)]
pub struct VerifyInput {
    pub metadata: EventMetadata,
    pub input_handle: Handle,
    pub user_address: Address,
    pub input_proof: Vec<u8>,
    pub input_type: FheType,
    pub result: Handle,
}

/// Random number generation
/// Event: FheRand(address indexed caller, FheType randType, bytes16 seed, bytes32 result)
#[derive(Debug, Clone)]
pub struct FheRand {
    pub metadata: EventMetadata,
    pub rand_type: FheType,
    pub seed: [u8; 16],
    pub result: Handle,
}

/// Bounded random number generation
/// Event: FheRandBounded(address indexed caller, uint256 upperBound, FheType randType, bytes16 seed, bytes32 result)
#[derive(Debug, Clone)]
pub struct FheRandBounded {
    pub metadata: EventMetadata,
    pub upper_bound: U256,
    pub rand_type: FheType,
    pub seed: [u8; 16],
    pub result: Handle,
}

/// 
/// 
/// 
/// Unified enum for all FHE operations
#[derive(Debug, Clone)]
pub enum FheOperation {
    Binary(BinaryOp),
    Unary(UnaryOp),
    TrivialEncrypt(TrivialEncrypt),
    Cast(Cast),
    IfThenElse(IfThenElse),
    VerifyInput(VerifyInput),
    Rand(FheRand),
    RandBounded(FheRandBounded),
    Unknown { topic0: B256, data: Vec<u8> },
}

impl FheOperation {
    /// Get a human-readable name for this operation
    pub fn name(&self) -> &'static str {
        match self {
            FheOperation::Binary(op) => op.op_type.name(),
            FheOperation::Unary(op) => op.op_type.name(),
            FheOperation::TrivialEncrypt(_) => "TrivialEncrypt",
            FheOperation::Cast(_) => "Cast",
            FheOperation::IfThenElse(_) => "FheIfThenElse",
            FheOperation::VerifyInput(_) => "VerifyInput",
            FheOperation::Rand(_) => "FheRand",
            FheOperation::RandBounded(_) => "FheRandBounded",
            FheOperation::Unknown { .. } => "Unknown",
        }
    }

    /// Get the result handle if this operation produces one
    pub fn result_handle(&self) -> Option<Handle> {
        match self {
            FheOperation::Binary(op) => Some(op.result),
            FheOperation::Unary(op) => Some(op.result),
            FheOperation::TrivialEncrypt(op) => Some(op.result),
            FheOperation::Cast(op) => Some(op.result),
            FheOperation::IfThenElse(op) => Some(op.result),
            FheOperation::VerifyInput(op) => Some(op.result),
            FheOperation::Rand(op) => Some(op.result),
            FheOperation::RandBounded(op) => Some(op.result),
            FheOperation::Unknown { .. } => None,
        }
    }

    /// Get the caller address
    pub fn caller(&self) -> Option<Address> {
        match self {
            FheOperation::Binary(op) => Some(op.metadata.caller),
            FheOperation::Unary(op) => Some(op.metadata.caller),
            FheOperation::TrivialEncrypt(op) => Some(op.metadata.caller),
            FheOperation::Cast(op) => Some(op.metadata.caller),
            FheOperation::IfThenElse(op) => Some(op.metadata.caller),
            FheOperation::VerifyInput(op) => Some(op.metadata.caller),
            FheOperation::Rand(op) => Some(op.metadata.caller),
            FheOperation::RandBounded(op) => Some(op.metadata.caller),
            FheOperation::Unknown { .. } => None,
        }
    }
}
