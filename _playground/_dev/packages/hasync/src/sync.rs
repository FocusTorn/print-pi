// Sync operations (YAML ↔ JSON)

use serde_json::Value;
use std::path::{Path, PathBuf};
use std::time::SystemTime;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum SyncError {
    #[error("File not found: {0:?}")]
    FileNotFound(PathBuf),
    #[error("Invalid YAML: {0}")]
    InvalidYaml(String),
    #[error("Invalid JSON: {0}")]
    InvalidJson(String),
    #[error("Backup failed: {0}")]
    BackupFailed(String),
    #[error("Write failed: {0}")]
    WriteFailed(String),
    #[error("Permission denied")]
    PermissionDenied,
    #[error("Validation failed: {0}")]
    ValidationFailed(String),
}

#[derive(Debug, Clone, PartialEq)]
pub enum FileStatus {
    YamlNewer,
    JsonNewer,
    Synced,
    Error(String),
}

pub fn yaml_to_json(yaml_path: &Path, dashboard_key: &str, dashboard_title: &str, dashboard_path: &str) -> Result<Value, SyncError> {
    // Read YAML file
    if !yaml_path.exists() {
        return Err(SyncError::FileNotFound(yaml_path.to_path_buf()));
    }
    
    let content = std::fs::read_to_string(yaml_path)
        .map_err(|e| SyncError::InvalidYaml(format!("Failed to read YAML file: {}", e)))?;
    
    // Parse YAML
    let yaml_value: Value = serde_yaml::from_str(&content)
        .map_err(|e| SyncError::InvalidYaml(format!("Failed to parse YAML: {}", e)))?;
    
    // Convert to Home Assistant dashboard JSON format
    // Structure: { "version": 1, "key": "...", "data": { "config": {...}, "title": "...", "url_path": "..." } }
    let json_value = serde_json::json!({
        "version": 1,
        "key": dashboard_key,
        "data": {
            "config": yaml_value,
            "title": dashboard_title,
            "url_path": dashboard_path
        }
    });
    
    Ok(json_value)
}

pub fn json_to_yaml(_json_path: &Path) -> Result<Value, SyncError> {
    // TODO: Implement JSON to YAML conversion
    Err(SyncError::InvalidJson("Not implemented".to_string()))
}

pub fn detect_newer_file(yaml_path: &Path, json_path: &Path) -> FileStatus {
    let yaml_mtime = get_file_mtime(yaml_path);
    let json_mtime = get_file_mtime(json_path);
    
    match (yaml_mtime, json_mtime) {
        (Some(yaml_time), Some(json_time)) => {
            match yaml_time.cmp(&json_time) {
                std::cmp::Ordering::Greater => FileStatus::YamlNewer,
                std::cmp::Ordering::Less => FileStatus::JsonNewer,
                std::cmp::Ordering::Equal => FileStatus::Synced,
            }
        }
        (Some(_), None) => FileStatus::YamlNewer,  // YAML exists, JSON doesn't
        (None, Some(_)) => FileStatus::JsonNewer,  // JSON exists, YAML doesn't
        (None, None) => FileStatus::Error("Neither file exists".to_string()),
    }
}

pub fn create_backup(file_path: &Path) -> Result<PathBuf, SyncError> {
    if !file_path.exists() {
        return Err(SyncError::BackupFailed("File does not exist".to_string()));
    }
    
    // Generate backup filename with timestamp
    let timestamp = chrono::Local::now().format("%Y%m%d_%H%M%S");
    let backup_path = file_path.with_extension(format!("{}.backup", timestamp));
    
    // Copy file to backup location
    std::fs::copy(file_path, &backup_path)
        .map_err(|e| SyncError::BackupFailed(format!("Failed to create backup: {}", e)))?;
    
    Ok(backup_path)
}

pub fn sync_yaml_to_json(
    yaml_path: &Path,
    json_path: &Path,
    dashboard_key: &str,
    dashboard_title: &str,
    dashboard_path: &str,
) -> Result<PathBuf, SyncError> {
    // Validate YAML file exists
    if !yaml_path.exists() {
        return Err(SyncError::FileNotFound(yaml_path.to_path_buf()));
    }
    
    // Create backup of JSON file if it exists
    let backup_path = if json_path.exists() {
        create_backup(json_path)?
    } else {
        // No backup needed if JSON doesn't exist yet
        PathBuf::new()
    };
    
    // Convert YAML to JSON
    let json_value = yaml_to_json(yaml_path, dashboard_key, dashboard_title, dashboard_path)?;
    
    // Create parent directory if it doesn't exist
    if let Some(parent) = json_path.parent() {
        std::fs::create_dir_all(parent)
            .map_err(|e| SyncError::WriteFailed(format!("Failed to create directory: {}", e)))?;
    }
    
    // Write JSON file
    let json_content = serde_json::to_string_pretty(&json_value)
        .map_err(|e| SyncError::WriteFailed(format!("Failed to serialize JSON: {}", e)))?;
    
    std::fs::write(json_path, json_content)
        .map_err(|e| SyncError::WriteFailed(format!("Failed to write JSON file: {}", e)))?;
    
    Ok(backup_path)
}

pub fn sync_json_to_yaml(_json_path: &Path, _yaml_path: &Path) -> Result<(), SyncError> {
    // TODO: Implement JSON to YAML sync
    Err(SyncError::WriteFailed("Not implemented".to_string()))
}

pub fn get_file_mtime(path: &Path) -> Option<SystemTime> {
    std::fs::metadata(path)
        .ok()?
        .modified()
        .ok()
}

/// Sync scripts directory from source to destination
/// This performs a recursive directory copy, creating backups of existing files
pub fn sync_scripts_directory(
    source: &Path,
    destination: &Path,
    recursive: bool,
) -> Result<Vec<PathBuf>, SyncError> {
    let mut backups = Vec::new();
    
    // Validate source exists
    if !source.exists() {
        return Err(SyncError::FileNotFound(source.to_path_buf()));
    }
    
    // Check if source is a directory
    if !source.is_dir() {
        return Err(SyncError::ValidationFailed(
            format!("Source path is not a directory: {}", source.display())
        ));
    }
    
    // Create destination directory if it doesn't exist
    if let Some(parent) = destination.parent() {
        std::fs::create_dir_all(parent)
            .map_err(|e| SyncError::WriteFailed(format!("Failed to create directory: {}", e)))?;
    }
    
    // Sync files recursively
    sync_scripts_directory_recursive(source, destination, recursive, &mut backups)?;
    
    Ok(backups)
}

fn sync_scripts_directory_recursive(
    source: &Path,
    destination: &Path,
    recursive: bool,
    backups: &mut Vec<PathBuf>,
) -> Result<(), SyncError> {
    // Create destination directory if it doesn't exist
    if !destination.exists() {
        std::fs::create_dir_all(destination)
            .map_err(|e| SyncError::WriteFailed(format!("Failed to create directory: {}", e)))?;
    }
    
    // Read source directory
    let entries = std::fs::read_dir(source)
        .map_err(|e| SyncError::FileNotFound(PathBuf::from(format!("Failed to read directory: {}", e))))?;
    
    for entry in entries {
        let entry = entry.map_err(|e| SyncError::FileNotFound(PathBuf::from(format!("Failed to read entry: {}", e))))?;
        let source_path = entry.path();
        let file_name = entry.file_name();
        let destination_path = destination.join(&file_name);
        
        // Handle directories
        if source_path.is_dir() {
            if recursive {
                sync_scripts_directory_recursive(&source_path, &destination_path, recursive, backups)?;
            }
            continue;
        }
        
        // Handle files
        // Create backup of existing file if it exists
        if destination_path.exists() {
            let backup_path = create_backup(&destination_path)?;
            if !backup_path.as_os_str().is_empty() {
                backups.push(backup_path);
            }
        }
        
        // Copy file
        std::fs::copy(&source_path, &destination_path)
            .map_err(|e| SyncError::WriteFailed(format!("Failed to copy file {}: {}", source_path.display(), e)))?;
    }
    
    Ok(())
}

/// Detect if scripts directory needs syncing by comparing modification times
pub fn detect_scripts_sync_needed(source: &Path, destination: &Path) -> FileStatus {
    // Check if source exists
    if !source.exists() {
        return FileStatus::Error("Source directory does not exist".to_string());
    }
    
    // Check if destination exists
    if !destination.exists() {
        return FileStatus::YamlNewer;  // Source exists, destination doesn't - needs sync
    }
    
    // Compare modification times of directories
    let source_mtime = get_file_mtime(source);
    let dest_mtime = get_file_mtime(destination);
    
    match (source_mtime, dest_mtime) {
        (Some(src_time), Some(dst_time)) => {
            match src_time.cmp(&dst_time) {
                std::cmp::Ordering::Greater => FileStatus::YamlNewer,
                std::cmp::Ordering::Less => FileStatus::JsonNewer,
                std::cmp::Ordering::Equal => FileStatus::Synced,
            }
        }
        (Some(_), None) => FileStatus::YamlNewer,
        (None, Some(_)) => FileStatus::JsonNewer,
        (None, None) => FileStatus::Synced,
    }
}

