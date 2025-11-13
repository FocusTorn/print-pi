// Configuration management

use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DashboardConfig {
    pub name: String,
    pub yaml_source: PathBuf,
    pub json_storage: PathBuf,
    pub dashboard_key: String,
    pub dashboard_title: String,
    pub dashboard_path: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScriptsConfig {
    pub name: String,
    pub source: PathBuf,
    pub destination: PathBuf,
    pub recursive: Option<bool>,  // Default to true if not specified
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppConfig {
    pub dashboards: Vec<DashboardConfig>,
    pub default_dashboard: Option<String>,
    pub scripts: Option<Vec<ScriptsConfig>>,
}

impl Default for AppConfig {
    fn default() -> Self {
        AppConfig {
            dashboards: vec![],
            default_dashboard: None,
            scripts: None,
        }
    }
}

impl AppConfig {
    pub fn load() -> Result<Self, Box<dyn std::error::Error>> {
        let config_path = get_config_path();
        
        // If config file doesn't exist, return default
        if !config_path.exists() {
            return Ok(AppConfig::default());
        }
        
        // Read and parse config file
        let content = std::fs::read_to_string(&config_path)?;
        let config: AppConfig = serde_yaml::from_str(&content)?;
        
        Ok(config)
    }
    
    pub fn save(&self) -> Result<(), Box<dyn std::error::Error>> {
        let config_path = get_config_path();
        
        // Create config directory if it doesn't exist
        if let Some(parent) = config_path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        
        // Serialize and write config
        let content = serde_yaml::to_string(self)?;
        std::fs::write(&config_path, content)?;
        
        Ok(())
    }
}

pub fn get_config_path() -> PathBuf {
    dirs::home_dir()
        .unwrap_or_else(|| PathBuf::from("/home/pi"))
        .join(".config")
        .join("hasync")
        .join("config.yaml")
}

