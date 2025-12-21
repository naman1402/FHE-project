use std::path::PathBuf;
use anyhow::Result;
use crate::kms::KmsService;

#[derive(Clone)]
pub struct KmsState {
    pub kms_service: KmsService,
}

impl KmsState {
    pub async fn new(key_dir: PathBuf) -> Result<Self> {
        Ok(Self { kms_service: KmsService::new(key_dir).await? })
    }
}