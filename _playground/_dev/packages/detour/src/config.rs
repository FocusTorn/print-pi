// Configuration parsing and management

use serde::{Deserialize, Serialize};
use std::fs;

// Runtime configuration (detours mapping from ~/.detour.yaml)
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct DetourConfig {
    #[serde(default)]
    pub detours: Vec<DetourEntry>,
    #[serde(default)]
    pub injections: Vec<InjectionEntry>,
    #[serde(default)]
    pub mirrors: Vec<MirrorEntry>,
    #[serde(default)]
    pub services: Vec<ServiceEntry>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct DetourEntry {
    pub original: String,
    pub custom: String,
    #[serde(default)]
    pub description: Option<String>,
    #[serde(skip)]
    pub enabled: bool,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct InjectionEntry {
    pub target: String,
    #[serde(rename = "include")]
    pub include_file: String,
    #[serde(default)]
    pub description: Option<String>,
    #[serde(skip)]
    pub enabled: bool,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct MirrorEntry {
    pub source: String,
    pub target: String,
    #[serde(default)]
    pub description: Option<String>,
    #[serde(skip)]
    pub enabled: bool,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct ServiceEntry {
    pub name: String,
    pub action: String,
    #[serde(default)]
    pub description: Option<String>,
    #[serde(skip)]
    pub enabled: bool,
}

impl DetourConfig {
    pub fn parse(path: &str) -> Result<Self, String> {
        let content = fs::read_to_string(path)
            .map_err(|e| format!("Failed to read config: {}", e))?;
        
        // Parse YAML
        let config: DetourConfig = serde_yaml::from_str(&content)
            .map_err(|e| format!("Failed to parse YAML config: {}", e))?;
        
        Ok(config)
    }
    
    pub fn get_config_path() -> String {
        // Primary: Runtime configuration in home directory
        if let Ok(home) = std::env::var("HOME") {
            let runtime_config = format!("{}/.detour.yaml", home);
            if std::path::Path::new(&runtime_config).exists() {
                return runtime_config;
            }
        }
        
        // Fallback: System-wide config
        let system_config = "/etc/detour.yaml";
        if std::path::Path::new(system_config).exists() {
            return system_config.to_string();
        }
        
        // Default: Use home directory path even if it doesn't exist yet
        if let Ok(home) = std::env::var("HOME") {
            format!("{}/.detour.yaml", home)
        } else {
            "/etc/detour.yaml".to_string()
        }
    }
}


