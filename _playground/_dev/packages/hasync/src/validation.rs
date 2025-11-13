// Validation logic

use serde_json::Value;
use std::path::Path;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum ValidationError {
    #[error("Invalid YAML: {0}")]
    InvalidYaml(String),
    #[error("Invalid JSON: {0}")]
    InvalidJson(String),
    #[error("File not found: {0:?}")]
    FileNotFound(std::path::PathBuf),
    #[error("Invalid dashboard structure: {0}")]
    InvalidDashboardStructure(String),
}

pub fn validate_yaml(_path: &Path) -> Result<(), ValidationError> {
    // TODO: Implement YAML validation
    Ok(())
}

pub fn validate_json(_path: &Path) -> Result<(), ValidationError> {
    // TODO: Implement JSON validation
    Ok(())
}

pub fn validate_dashboard_structure(_json: &Value) -> Result<(), ValidationError> {
    // TODO: Implement dashboard structure validation
    // Check for required fields: version, key, data, data.config, data.title, data.url_path
    Ok(())
}

