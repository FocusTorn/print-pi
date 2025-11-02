// Include operations - file content injection

use std::path::Path;
use std::fs;
use std::process::Command;

pub struct IncludeManager;

#[derive(Debug, Clone, Copy)]
enum FileType {
    Yaml,
    CHeader,
    Shell,
    Config,
    RaspberryPiConfig,  // For /boot/firmware/config.txt format
    Unknown,
}

impl IncludeManager {
    pub fn new() -> Self {
        Self
    }

    // Write file with automatic sudo fallback on permission denied
    fn write_file_with_sudo(target: &Path, contents: &str) -> Result<(), String> {
        // Try normal write first
        match fs::write(target, contents) {
            Ok(_) => Ok(()),
            Err(e) if e.kind() == std::io::ErrorKind::PermissionDenied => {
                // Permission denied - write to temp file, then use sudo to copy it
                let target_str = target.to_string_lossy().to_string();
                let temp_file = format!("/tmp/detour_include_{}", std::process::id());
                
                // Write to temp file
                fs::write(&temp_file, contents)
                    .map_err(|e| format!("Failed to write temp file: {}", e))?;
                
                // Use sudo cp to copy temp file to target
                let output = Command::new("sudo")
                    .arg("cp")
                    .arg(&temp_file)
                    .arg(&target_str)
                    .output()
                    .map_err(|e| format!("Failed to execute sudo cp: {}", e))?;

                // Clean up temp file
                let _ = fs::remove_file(&temp_file);

                if !output.status.success() {
                    let stderr = String::from_utf8_lossy(&output.stderr);
                    return Err(format!("Failed to write file with sudo: {}", stderr));
                }

                Ok(())
            }
            Err(e) => Err(format!("Failed to write target file: {}", e))
        }
    }

    fn get_file_type(target: &Path) -> FileType {
        // First, try to detect by existing include directives in the file
        if target.exists() {
            if let Ok(content) = fs::read_to_string(target) {
                // Check for existing include patterns in the file
                for line in content.lines().take(100) {
                    let trimmed = line.trim();
                    
                    // YAML: !include directive
                    if trimmed.contains("!include") || trimmed.contains("!include_dir") {
                        return FileType::Yaml;
                    }
                    
                    // C/C++: #include directive
                    if trimmed.starts_with("#include") {
                        return FileType::CHeader;
                    }
                    
                    // Shell: source or . command
                    if trimmed.starts_with("source") || (trimmed.starts_with(".") && trimmed.len() > 2) {
                        return FileType::Shell;
                    }
                    
                    // Raspberry Pi config.txt: simple "include" (not #include)
                    if trimmed.starts_with("include ") && !trimmed.starts_with("#include") {
                        return FileType::RaspberryPiConfig;
                    }
                }
            }
        }

        // Fallback to extension-based detection
        if let Some(ext) = target.extension().and_then(|e| e.to_str()) {
            match ext.to_lowercase().as_str() {
                "yaml" | "yml" => return FileType::Yaml,
                "h" | "hpp" | "hxx" | "c" | "cpp" | "cxx" => return FileType::CHeader,
                "sh" | "bash" => return FileType::Shell,
                "conf" | "config" | "cfg" | "ini" => return FileType::Config,
                _ => {}
            }
        }

        // Last resort: content-based heuristics (only if file exists and no includes found)
        if target.exists() {
            if let Ok(content) = fs::read_to_string(target) {
                let sample = content.lines().take(20).collect::<Vec<_>>().join("\n").to_lowercase();
                
                // Raspberry Pi config.txt heuristics
                if sample.contains("dtparam=") || sample.contains("dtoverlay=") || 
                   (sample.contains("arm_") && sample.len() < 2000) {
                    return FileType::RaspberryPiConfig;
                }
                
                // YAML heuristics
                if content.trim_start().starts_with("---") {
                    return FileType::Yaml;
                }
                
                // Shell script heuristics
                if content.trim_start().starts_with("#!") && 
                   (content.contains("/bin/") || content.contains("/usr/bin/")) {
                    return FileType::Shell;
                }
            }
        }

        FileType::Unknown
    }

    pub fn apply(&self, target: &Path, include: &Path) -> Result<(), String> {
        // Verify include file exists
        if !include.exists() {
            return Err(format!("Include file does not exist: {}", include.display()));
        }

        let file_type = Self::get_file_type(target);
        let include_relative = self.get_relative_path(target, include)?;

        match file_type {
            FileType::Yaml => self.apply_yaml(target, include, &include_relative),
            FileType::CHeader => self.apply_cheader(target, include, &include_relative),
            FileType::Shell => self.apply_shell(target, include, &include_relative),
            FileType::RaspberryPiConfig => self.apply_rpi_config(target, include, &include_relative),
            FileType::Config | FileType::Unknown => {
                // Try to detect based on content or use generic approach
                self.apply_generic(target, include, &include_relative)
            }
        }
    }

    pub fn remove(&self, target: &Path, include: &Path) -> Result<(), String> {
        if !target.exists() {
            return Ok(()); // Nothing to remove
        }

        let file_type = Self::get_file_type(target);
        let include_relative = self.get_relative_path(target, include)?;

        match file_type {
            FileType::Yaml => self.remove_yaml(target, include, &include_relative),
            FileType::CHeader => self.remove_cheader(target, include, &include_relative),
            FileType::Shell => self.remove_shell(target, include, &include_relative),
            FileType::RaspberryPiConfig => self.remove_rpi_config(target, include, &include_relative),
            FileType::Config | FileType::Unknown => {
                self.remove_generic(target, include, &include_relative)
            }
        }
    }

    fn get_relative_path(&self, target: &Path, include: &Path) -> Result<String, String> {
        // Try to get canonical paths
        let target_dir = target.parent()
            .and_then(|p| p.canonicalize().ok())
            .ok_or_else(|| "Cannot determine target directory".to_string())?;
        
        let include_path = include.canonicalize().or_else(|_| {
            include.file_name()
                .and_then(|name| include.parent().map(|p| p.join(name)))
                .and_then(|p| p.canonicalize().ok())
                .ok_or_else(|| std::io::Error::new(std::io::ErrorKind::NotFound, "Include file not found"))
        })
        .map_err(|_| format!("Cannot resolve include file: {}", include.display()))?;

        // Try relative path calculation
        if let Ok(relative) = include_path.strip_prefix(&target_dir) {
            // Include is in same directory or subdirectory
            Ok(relative.to_string_lossy().to_string())
        } else {
            // Fall back to just the file name if in same directory, or absolute path
            if target_dir == include_path.parent().and_then(|p| p.canonicalize().ok()).unwrap_or_default() {
                Ok(include.file_name()
                    .and_then(|n| n.to_str())
                    .unwrap_or("")
                    .to_string())
            } else {
                // Use absolute path as fallback
                Ok(include_path.to_string_lossy().to_string())
            }
        }
    }

    // YAML file handlers
    fn apply_yaml(&self, target: &Path, _include: &Path, include_path: &str) -> Result<(), String> {
        use serde_yaml::{Value, Mapping};
        
        // Read target file or create empty YAML
        let target_content = if target.exists() {
            fs::read_to_string(target)
                .map_err(|e| format!("Failed to read target file: {}", e))?
        } else {
            // Create directory if needed
            if let Some(parent) = target.parent() {
                fs::create_dir_all(parent)
                    .map_err(|e| format!("Failed to create target directory: {}", e))?;
            }
            String::new()
        };

        // Parse target as YAML
        let mut config: Value = if target_content.trim().is_empty() {
            Value::Mapping(Mapping::new())
        } else {
            serde_yaml::from_str(&target_content)
                .map_err(|e| format!("Failed to parse target YAML: {}", e))?
        };

        // Check if include already exists
        if self.has_yaml_include(&config, include_path) {
            return Ok(()); // Already included
        }

        // Add include directive
        self.add_yaml_include(&mut config, include_path)?;

        // Write back to target file
        let updated_content = serde_yaml::to_string(&config)
            .map_err(|e| format!("Failed to serialize YAML: {}", e))?;
        
        Self::write_file_with_sudo(target, &updated_content)?;

        Ok(())
    }

    fn remove_yaml(&self, target: &Path, _include: &Path, include_path: &str) -> Result<(), String> {
        use serde_yaml::Value;
        
        let target_content = fs::read_to_string(target)
            .map_err(|e| format!("Failed to read target file: {}", e))?;

        if target_content.trim().is_empty() {
            return Ok(());
        }

        let mut config: Value = serde_yaml::from_str(&target_content)
            .map_err(|e| format!("Failed to parse target YAML: {}", e))?;

        if !self.has_yaml_include(&config, include_path) {
            return Ok(()); // Not included
        }

        self.remove_yaml_include(&mut config, include_path)?;

        let updated_content = serde_yaml::to_string(&config)
            .map_err(|e| format!("Failed to serialize YAML: {}", e))?;
        
        Self::write_file_with_sudo(target, &updated_content)?;

        Ok(())
    }

    fn has_yaml_include(&self, config: &serde_yaml::Value, include_path: &str) -> bool {
        if let serde_yaml::Value::Mapping(mapping) = config {
            for (_, value) in mapping.iter() {
                if self.check_yaml_value_for_include(value, include_path) {
                    return true;
                }
            }
        }
        false
    }

    fn check_yaml_value_for_include(&self, value: &serde_yaml::Value, include_path: &str) -> bool {
        match value {
            serde_yaml::Value::String(s) => {
                s == include_path || 
                s.contains(&format!("!include {}", include_path)) ||
                s.ends_with(include_path)
            }
            serde_yaml::Value::Sequence(seq) => {
                for item in seq {
                    if self.check_yaml_value_for_include(item, include_path) {
                        return true;
                    }
                }
                false
            }
            serde_yaml::Value::Mapping(map) => {
                for (_, v) in map.iter() {
                    if self.check_yaml_value_for_include(v, include_path) {
                        return true;
                    }
                }
                false
            }
            _ => false,
        }
    }

    fn add_yaml_include(&self, config: &mut serde_yaml::Value, include_path: &str) -> Result<(), String> {
        use serde_yaml::Value;
        
        if let Value::Mapping(ref mut mapping) = config {
            let key_name = Path::new(include_path)
                .file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("include");
            
            let include_value = Value::String(format!("!include {}", include_path));
            
            if let Some(existing) = mapping.get_mut(key_name) {
                match existing {
                    Value::Sequence(ref mut seq) => {
                        seq.push(include_value);
                    }
                    _ => {
                        let old_value = existing.clone();
                        *existing = Value::Sequence(vec![old_value, include_value]);
                    }
                }
            } else {
                mapping.insert(
                    Value::String(key_name.to_string()),
                    include_value,
                );
            }
            Ok(())
        } else {
            Err("Config is not a mapping".to_string())
        }
    }

    fn remove_yaml_include(&self, config: &mut serde_yaml::Value, include_path: &str) -> Result<(), String> {
        use serde_yaml::Value;
        
        if let Value::Mapping(ref mut mapping) = config {
            let keys_to_remove: Vec<Value> = mapping
                .iter()
                .filter(|(_, v)| self.check_yaml_value_for_include(v, include_path))
                .map(|(k, _)| k.clone())
                .collect();

            for key in keys_to_remove {
                mapping.remove(&key);
            }
            Ok(())
        } else {
            Err("Config is not a mapping".to_string())
        }
    }

    // C/C++ header file handlers
    fn apply_cheader(&self, target: &Path, _include: &Path, include_path: &str) -> Result<(), String> {
        let target_content = if target.exists() {
            fs::read_to_string(target)
                .map_err(|e| format!("Failed to read target file: {}", e))?
        } else {
            if let Some(parent) = target.parent() {
                fs::create_dir_all(parent)
                    .map_err(|e| format!("Failed to create target directory: {}", e))?;
            }
            String::new()
        };

        // Check if include already exists
        let include_line = format!("#include \"{}\"", include_path);
        if target_content.lines().any(|line| line.trim() == include_line) {
            return Ok(()); // Already included
        }

        // Add include at the top (after other includes or at start)
        let mut lines: Vec<&str> = target_content.lines().collect();
        let mut insert_pos = 0;
        
        // Find position after last include statement
        for (i, line) in lines.iter().enumerate().rev() {
            if line.trim().starts_with("#include") {
                insert_pos = i + 1;
                break;
            }
        }

        lines.insert(insert_pos, &include_line);
        
        Self::write_file_with_sudo(target, &lines.join("\n"))?;

        Ok(())
    }

    fn remove_cheader(&self, target: &Path, _include: &Path, include_path: &str) -> Result<(), String> {
        let target_content = fs::read_to_string(target)
            .map_err(|e| format!("Failed to read target file: {}", e))?;

        let include_line = format!("#include \"{}\"", include_path);
        let lines: Vec<&str> = target_content
            .lines()
            .filter(|line| line.trim() != include_line)
            .collect();

        Self::write_file_with_sudo(target, &lines.join("\n"))?;

        Ok(())
    }

    // Shell script handlers
    fn apply_shell(&self, target: &Path, _include: &Path, include_path: &str) -> Result<(), String> {
        let target_content = if target.exists() {
            fs::read_to_string(target)
                .map_err(|e| format!("Failed to read target file: {}", e))?
        } else {
            if let Some(parent) = target.parent() {
                fs::create_dir_all(parent)
                    .map_err(|e| format!("Failed to create target directory: {}", e))?;
            }
            String::new()
        };

        // Check if include already exists (source or . command)
        let source_line = format!("source \"{}\"", include_path);
        let dot_line = format!(". \"{}\"", include_path);
        
        if target_content.lines().any(|line| {
            let trimmed = line.trim();
            trimmed == source_line || trimmed == dot_line
        }) {
            return Ok(()); // Already included
        }

        // Add source at the end (or after shebang)
        let mut lines: Vec<&str> = target_content.lines().collect();
        let mut insert_pos = 0;
        
        // Skip shebang if present
        if !lines.is_empty() && lines[0].starts_with("#!") {
            insert_pos = 1;
        }

        lines.insert(insert_pos, &source_line);
        
        Self::write_file_with_sudo(target, &lines.join("\n"))?;

        Ok(())
    }

    fn remove_shell(&self, target: &Path, _include: &Path, include_path: &str) -> Result<(), String> {
        let target_content = fs::read_to_string(target)
            .map_err(|e| format!("Failed to read target file: {}", e))?;

        let source_line = format!("source \"{}\"", include_path);
        let dot_line = format!(". \"{}\"", include_path);
        
        let lines: Vec<&str> = target_content
            .lines()
            .filter(|line| {
                let trimmed = line.trim();
                trimmed != source_line && trimmed != dot_line
            })
            .collect();

        Self::write_file_with_sudo(target, &lines.join("\n"))?;

        Ok(())
    }

    // Raspberry Pi config.txt handlers
    fn apply_rpi_config(&self, target: &Path, _include: &Path, include_path: &str) -> Result<(), String> {
        let target_content = if target.exists() {
            fs::read_to_string(target)
                .map_err(|e| format!("Failed to read target file: {}", e))?
        } else {
            if let Some(parent) = target.parent() {
                fs::create_dir_all(parent)
                    .map_err(|e| format!("Failed to create target directory: {}", e))?;
            }
            String::new()
        };

        // Check if include wrapper already exists
        let wrapper_pattern = format!("# BEGIN DETOUR INJECTION\ninclude {}\n# END DETOUR INJECTION", include_path);
        if target_content.contains(&wrapper_pattern) {
            return Ok(()); // Already included
        }

        // Build the wrapper block
        let wrapper_block = format!("# BEGIN DETOUR INJECTION\ninclude {}\n# END DETOUR INJECTION\n", include_path);

        // Add include wrapper at the end of the file
        let new_content = if target_content.trim().is_empty() {
            wrapper_block
        } else if target_content.ends_with('\n') {
            format!("{}{}", target_content, wrapper_block)
        } else {
            format!("{}\n{}", target_content, wrapper_block)
        };

        Self::write_file_with_sudo(target, &new_content)?;

        Ok(())
    }

    fn remove_rpi_config(&self, target: &Path, _include: &Path, include_path: &str) -> Result<(), String> {
        let target_content = fs::read_to_string(target)
            .map_err(|e| format!("Failed to read target file: {}", e))?;

        // Build the wrapper pattern to find
        let wrapper_start = "# BEGIN DETOUR INJECTION";
        let include_line = format!("include {}", include_path);
        let wrapper_end = "# END DETOUR INJECTION";
        
        let lines: Vec<&str> = target_content.lines().collect();
        let mut filtered_lines: Vec<&str> = vec![];
        let mut i = 0;
        
        while i < lines.len() {
            let line = lines[i];
            let trimmed = line.trim();
            
            // Check if we're starting a wrapper block
            if trimmed == wrapper_start {
                // Check if the next lines match our include and end marker
                if i + 2 < lines.len() {
                    let next_line = lines[i + 1].trim();
                    let end_line = lines[i + 2].trim();
                    
                    if next_line == &include_line && end_line == wrapper_end {
                        // Found our wrapper block - skip it (BEGIN, include, END)
                        i += 3;
                        continue;
                    }
                }
            }
            
            // Keep this line
            filtered_lines.push(line);
            i += 1;
        }
        
        let new_content = if filtered_lines.is_empty() {
            String::new()
        } else {
            filtered_lines.join("\n") + "\n"
        };

        Self::write_file_with_sudo(target, &new_content)?;

        Ok(())
    }

    // Generic/config file handlers
    fn apply_generic(&self, target: &Path, _include: &Path, include_path: &str) -> Result<(), String> {
        // For unknown files, try to append a comment-based include
        let target_content = if target.exists() {
            fs::read_to_string(target)
                .map_err(|e| format!("Failed to read target file: {}", e))?
        } else {
            if let Some(parent) = target.parent() {
                fs::create_dir_all(parent)
                    .map_err(|e| format!("Failed to create target directory: {}", e))?;
            }
            String::new()
        };

        // Check if already included (look for include_path in comments)
        if target_content.contains(&include_path) {
            return Ok(()); // Might already be included
        }

        // Append as comment at the end
        let new_content = if target_content.trim().is_empty() {
            format!("# Include: {}\n", include_path)
        } else {
            format!("{}\n# Include: {}\n", target_content, include_path)
        };

        Self::write_file_with_sudo(target, &new_content)?;

        Ok(())
    }

    fn remove_generic(&self, target: &Path, _include: &Path, include_path: &str) -> Result<(), String> {
        let target_content = fs::read_to_string(target)
            .map_err(|e| format!("Failed to read target file: {}", e))?;

        // Remove lines containing the include path in comments
        let lines: Vec<&str> = target_content
            .lines()
            .filter(|line| !line.contains(&include_path))
            .collect();

        Self::write_file_with_sudo(target, &lines.join("\n"))?;

        Ok(())
    }
}


