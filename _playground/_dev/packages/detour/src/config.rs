// Configuration parsing and management

use std::fs;

#[derive(Debug, Clone)]
pub struct DetourConfig {
    pub detours: Vec<DetourEntry>,
    pub includes: Vec<IncludeEntry>,
    pub services: Vec<ServiceEntry>,
}

#[derive(Debug, Clone)]
pub struct DetourEntry {
    pub original: String,
    pub custom: String,
    pub enabled: bool,
}

#[derive(Debug, Clone)]
pub struct IncludeEntry {
    pub target: String,
    pub include_file: String,
    pub enabled: bool,
}

#[derive(Debug, Clone)]
pub struct ServiceEntry {
    pub name: String,
    pub action: String,
    pub enabled: bool,
}

impl DetourConfig {
    pub fn parse(path: &str) -> Result<Self, String> {
        let content = fs::read_to_string(path)
            .map_err(|e| format!("Failed to read config: {}", e))?;
        
        let mut detours = Vec::new();
        let mut includes = Vec::new();
        let mut services = Vec::new();
        
        for line in content.lines() {
            let line = line.trim();
            
            // Skip empty lines and comments
            if line.is_empty() || line.starts_with('#') {
                continue;
            }
            
            // Parse detour directive: detour /path/to/original = /path/to/custom
            if line.starts_with("detour ") {
                if let Some((original, custom)) = Self::parse_detour_line(line) {
                    detours.push(DetourEntry {
                        original: original.to_string(),
                        custom: custom.to_string(),
                        enabled: true,
                    });
                }
            }
            
            // Parse include directive: include /path/to/target : /path/to/include
            else if line.starts_with("include ") {
                if let Some((target, include_file)) = Self::parse_include_line(line) {
                    includes.push(IncludeEntry {
                        target: target.to_string(),
                        include_file: include_file.to_string(),
                        enabled: true,
                    });
                }
            }
            
            // Parse service directive: service service_name : action
            else if line.starts_with("service ") {
                if let Some((name, action)) = Self::parse_service_line(line) {
                    services.push(ServiceEntry {
                        name: name.to_string(),
                        action: action.to_string(),
                        enabled: true,
                    });
                }
            }
        }
        
        Ok(DetourConfig {
            detours,
            includes,
            services,
        })
    }
    
    fn parse_detour_line(line: &str) -> Option<(&str, &str)> {
        // Format: detour /path/to/original = /path/to/custom
        let line = line.strip_prefix("detour ")?.trim();
        let parts: Vec<&str> = line.split('=').collect();
        if parts.len() == 2 {
            Some((parts[0].trim(), parts[1].trim()))
        } else {
            None
        }
    }
    
    fn parse_include_line(line: &str) -> Option<(&str, &str)> {
        // Format: include /path/to/target : /path/to/include
        let line = line.strip_prefix("include ")?.trim();
        let parts: Vec<&str> = line.split(':').collect();
        if parts.len() == 2 {
            Some((parts[0].trim(), parts[1].trim()))
        } else {
            None
        }
    }
    
    fn parse_service_line(line: &str) -> Option<(&str, &str)> {
        // Format: service service_name : action
        let line = line.strip_prefix("service ")?.trim();
        let parts: Vec<&str> = line.split(':').collect();
        if parts.len() == 2 {
            Some((parts[0].trim(), parts[1].trim()))
        } else {
            None
        }
    }
    
    pub fn get_config_path() -> String {
        // Primary: detour package directory (build configuration)
        let package_config = "/home/pi/_playground/_dev/packages/detour/detour.conf";
        if std::path::Path::new(package_config).exists() {
            return package_config.to_string();
        }
        
        // Secondary: runtime configuration (future)
        if let Ok(home) = std::env::var("HOME") {
            let runtime_config = format!("{}/.detour.conf", home);
            if std::path::Path::new(&runtime_config).exists() {
                return runtime_config;
            }
        }
        
        // Fallback: system-wide config
        "/etc/detour.conf".to_string()
    }
}


