// Detour operations - bind mount management via shell script

use std::process::Command;
use std::fs;
use std::path::Path;

pub struct DetourManager {
    script_path: String,
}

impl DetourManager {
    pub fn new() -> Self {
        // Find the detour core script
        let script_path = Self::find_script_path();
        Self { script_path }
    }
    
    fn find_script_path() -> String {
        // Try multiple locations
        let candidates = vec![
            "/home/pi/.local/share/detour/lib/detour-core.sh",
            "/home/pi/_playground/_dev/packages/detour/lib/detour-core.sh",
            "/usr/local/share/detour/lib/detour-core.sh",
        ];
        
        for path in candidates {
            if Path::new(path).exists() {
                return path.to_string();
            }
        }
        
        // Fallback
        "/home/pi/_playground/_dev/packages/detour/lib/detour-core.sh".to_string()
    }
    
    pub fn call_script(&self, command: &str) -> Result<String, String> {
        let output = Command::new("bash")
            .arg(&self.script_path)
            .arg(command)
            .output()
            .map_err(|e| format!("Failed to execute script: {}", e))?;
        
        if output.status.success() {
            Ok(String::from_utf8_lossy(&output.stdout).to_string())
        } else {
            Err(String::from_utf8_lossy(&output.stderr).to_string())
        }
    }
    
    pub fn apply_all(&self) -> Result<String, String> {
        self.call_script("apply")
    }
    
    pub fn remove_all(&self) -> Result<String, String> {
        self.call_script("remove")
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
    
    pub fn get_status(&self) -> Result<Vec<DetourStatus>, String> {
        // Check which detours are actually mounted
        let mounts = self.get_active_mounts()?;
        Ok(mounts)
    }
    
    fn get_active_mounts(&self) -> Result<Vec<DetourStatus>, String> {
        let output = Command::new("mount")
            .output()
            .map_err(|e| format!("Failed to check mounts: {}", e))?;
        
        let mount_output = String::from_utf8_lossy(&output.stdout);
        let statuses = Vec::new();
        
        // Parse mount output for detour bind mounts
        // This is a simplified version - real implementation would be more robust
        for line in mount_output.lines() {
            if line.contains("detour") || line.contains("bind") {
                // Extract paths if possible
                // Format: /custom/path on /original/path type none (rw,bind)
                // This is simplified - would need better parsing
            }
        }
        
        Ok(statuses)
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

impl Default for DetourManager {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(Debug, Clone)]
pub struct DetourStatus {
    pub original: String,
    pub custom: String,
    pub active: bool,
}

#[derive(Debug, Clone)]
pub struct FileInfo {
    pub size: u64,
    pub modified_secs: u64,
    pub exists: bool,
}


