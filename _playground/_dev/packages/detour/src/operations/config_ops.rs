// Shared config operations - reduces duplication of load/save patterns

use crate::config::DetourConfig;

/// Load config from file, or return empty config if file doesn't exist or is invalid
pub fn load_config(config_path: &str) -> DetourConfig {
    DetourConfig::parse(config_path).unwrap_or_else(|_| DetourConfig {
        detours: vec![],
        includes: vec![],
        services: vec![],
    })
}

/// Save config to file - returns Ok(()) on success, Err with message on failure
pub fn save_config(config_path: &str, config: &DetourConfig) -> Result<(), String> {
    let yaml = serde_yaml::to_string(config)
        .map_err(|e| format!("Failed to serialize config: {}", e))?;
    
    std::fs::write(config_path, yaml)
        .map_err(|e| format!("Failed to write config: {}", e))?;
    
    Ok(())
}

/// Execute a closure with mutable access to config, then save it
/// Returns the result of the closure
pub fn with_config_mut<F, T>(
    config_path: &str,
    mut f: F,
) -> Result<T, String>
where
    F: FnMut(&mut DetourConfig) -> Result<T, String>,
{
    let mut config = load_config(config_path);
    let result = f(&mut config)?;
    save_config(config_path, &config)?;
    Ok(result)
}

