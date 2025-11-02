// Detour operations - bind mount management

use std::process::Command;
use std::fs;

pub struct DetourManager;

impl DetourManager {
    pub fn new() -> Self {
        Self
    }
    
    pub fn apply_detour(&self, original: &str, custom: &str) -> Result<String, String> {
        // Create a bind mount for a specific detour
        let output = Command::new("sudo")
            .arg("mount")
            .arg("--bind")
            .arg(custom)
            .arg(original)
            .output()
            .map_err(|e| format!("Failed to mount detour: {}", e))?;
        
        if output.status.success() {
            Ok(format!("Mounted {} → {}", custom, original))
        } else {
            Err(String::from_utf8_lossy(&output.stderr).to_string())
        }
    }
    
    pub fn remove_detour(&self, original: &str) -> Result<String, String> {
        // Remove a bind mount for a specific detour
        let output = Command::new("sudo")
            .arg("umount")
            .arg(original)
            .output()
            .map_err(|e| format!("Failed to unmount detour: {}", e))?;
        
        if output.status.success() {
            Ok(format!("Unmounted {}", original))
        } else {
            Err(String::from_utf8_lossy(&output.stderr).to_string())
        }
    }
    
    
    pub fn is_active(&self, original: &str) -> bool {
        // Check if specific detour is mounted
        let output = Command::new("mount")
            .output()
            .ok();
        
        if let Some(output) = output {
            let mount_output = String::from_utf8_lossy(&output.stdout);
            mount_output.contains(original)
        } else {
            false
        }
    }
    
    pub fn get_file_info(&self, path: &str) -> Option<FileInfo> {
        let metadata = fs::metadata(path).ok()?;
        let size = metadata.len();
        
        // Get modification time
        let modified = metadata.modified().ok()?;
        let duration = modified.duration_since(std::time::UNIX_EPOCH).ok()?;
        
        Some(FileInfo {
            size,
            modified_secs: duration.as_secs(),
            exists: true,
        })
    }
}

#[derive(Debug, Clone)]
pub struct FileInfo {
    pub size: u64,
    pub modified_secs: u64,
    pub exists: bool,
}


