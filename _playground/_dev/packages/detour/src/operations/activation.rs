// Shared activation/deactivation logic for detours and injections
// Note: Activation logic is tightly coupled with App state, so this module
// provides simple helpers rather than full abstraction

/// Helper to update config entry enabled state after activation toggle
pub fn update_entry_enabled(
    config_path: &str,
    update_fn: impl FnOnce(&mut crate::config::DetourConfig) -> Result<(), String>,
) -> Result<(), String> {
    use crate::operations::config_ops;
    config_ops::with_config_mut(config_path, update_fn)
}

