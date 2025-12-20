//! FHE Event Parser
//!
//! Parses and logs FHE operation events from the FHEVMExecutor contract.
//! Event signatures match those in FHEEvents.sol from Zama's fhevm.

use alloy::rpc::types::Log;

// pub const FHE_EVENT_NAMES: &[&str] = &[
//     "FheAdd",
//     "FheSub",
//     "FheMul",
//     "FheDiv",
//     "FheRem",
//     "FheLe",
//     "FheLt",
//     "FheGe",
//     "FheGt",
//     "FheEq",
//     "FheNe",
//     "FheBitAnd",
//     "FheBitOr",
//     "FheBitXor",
//     "FheShl",
//     "FheShr",
//     "FheNeg",
//     "FheNot",
//     "FheIfThenElse",
//     "TrivialEncrypt",
//     "Cast",
//     "VerifyInput",
//     "FheRand",
//     "FheRandBounded",
// ];

pub fn log_executor_event(log: &Log) {
    let topics = log.topics();

    if topics.is_empty() {
        println!("[parser] Event with no topics from {:?}", log.address());
        return;
    }

    let topic0 = &topics[0];

    println!();
    println!("[PARSER] FHE EXECUTOR EVENT DETECTED");
    println!("───────────────────────────────────────────────────────────────");
    println!("  Block:       {:?}", log.block_number.unwrap_or(0));
    println!(
        "  Tx Hash:     {:?}",
        log.transaction_hash
            .map(|h| format!("{:?}", h))
            .unwrap_or_else(|| "N/A".to_string())
    );
    println!("  Log Index:   {:?}", log.log_index.unwrap_or(0));
    println!("  Emitter:     {:?}", log.address());
    println!("  Topic0:      {:?}", topic0);

    // Log data size and hex
    let data = log.data();
    println!("  Data bytes:  {}", data.data.len());

    if !data.data.is_empty() {
        // Print first 128 bytes max for readability
        let preview_len = std::cmp::min(128, data.data.len());
        println!(
            "  Data (hex):  0x{}...",
            hex::encode(&data.data[..preview_len])
        );
    }

    // Log additional topics
    for (i, topic) in topics.iter().enumerate().skip(2) {
        println!("  Topic{}:      {:?}", i, topic);
    }
    println!("═══════════════════════════════════════════════════════════════");
    println!();
}

pub fn log_any_event(log: &Log, label: &str) {
    let topics = log.topics();

    let topic0_str = if !topics.is_empty() {
        format!("{:?}", topics[0])
    } else {
        "none".to_string()
    };

    println!(
        "[{}] Event: emitter={:?} topic0={} data_len={}",
        label,
        log.address(),
        &topic0_str[..std::cmp::min(18, topic0_str.len())],
        log.data().data.len()
    );
}
