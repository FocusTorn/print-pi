// Mirror operations - symlink management

use std::fs;
use std::path::Path;

pub struct MirrorManager;

impl MirrorManager {
    pub fn new() -> Self {
        Self
    }
    
    /// Create a symlink from source to target
    pub fn apply_mirror(&self, source: &str, target: &str) -> Result<String, String> {
        let source_path = Path::new(source);
        let target_path = Path::new(target);
        
        // Check if source exists
        if !source_path.exists() {
            return Err(format!("Source path does not exist: {}", source));
        }
        
        // Check if target already exists
        if target_path.exists() {
            // If it's already a symlink pointing to the same source, we're done
            if target_path.is_symlink() {
                if let Ok(target_link) = fs::read_link(target_path) {
                    if target_link == source_path {
                        return Ok(format!("Symlink already exists: {} → {}", target, source));
                    }
                }
                // Remove existing symlink if it points elsewhere
                fs::remove_file(target_path)
                    .map_err(|e| format!("Failed to remove existing symlink: {}", e))?;
            } else {
                // Target exists but is not a symlink
                return Err(format!("Target path exists and is not a symlink: {}", target));
            }
        }
        
        // Create parent directory if needed
        if let Some(parent) = target_path.parent() {
            fs::create_dir_all(parent)
                .map_err(|e| format!("Failed to create parent directory: {}", e))?;
        }
        
        // Create symlink
        std::os::unix::fs::symlink(source_path, target_path)
            .map_err(|e| format!("Failed to create symlink: {}", e))?;
        
        Ok(format!("Created symlink: {} → {}", target, source))
    }
    
    /// Remove a symlink
    pub fn remove_mirror(&self, target: &str) -> Result<String, String> {
        let target_path = Path::new(target);
        
        if !target_path.exists() {
            return Ok(format!("Symlink does not exist: {}", target));
        }
        
        if !target_path.is_symlink() {
            return Err(format!("Target is not a symlink: {}", target));
        }
        
        fs::remove_file(target_path)
            .map_err(|e| format!("Failed to remove symlink: {}", e))?;
        
        Ok(format!("Removed symlink: {}", target))
    }
    
    /// Check if a mirror is active (symlink exists and points to source)
    pub fn is_active(&self, source: &str, target: &str) -> bool {
        let target_path = Path::new(target);
        let source_path = Path::new(source);
        
        if !target_path.exists() || !target_path.is_symlink() {
            return false;
        }
        
        if let Ok(link_target) = fs::read_link(target_path) {
            return link_target == source_path;
        }
        
        false
    }
    
    /// Get file info for a path (used for size/modified time)
    pub fn get_file_info(&self, path: &str) -> Option<FileInfo> {
        let path = Path::new(path);
        
        if !path.exists() {
            return None;
        }
        
        match path.metadata() {
            Ok(metadata) => {
                let size = metadata.len();
                let modified_secs = metadata
                    .modified()
                    .ok()?
                    .duration_since(std::time::UNIX_EPOCH)
                    .ok()?
                    .as_secs();
                
                Some(FileInfo {
                    size,
                    modified_secs,
                })
            }
            Err(_) => None,
        }
    }
}

#[derive(Debug, Clone)]
pub struct FileInfo {
    pub size: u64,
    pub modified_secs: u64,
}

