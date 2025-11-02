// Shared file operations - duplication, deletion, directory creation

use std::fs;
use std::path::Path;

/// Create parent directories for a file path if they don't exist
pub fn ensure_parent_dirs(file_path: &Path) -> Result<(), String> {
    if let Some(parent) = file_path.parent() {
        fs::create_dir_all(parent)
            .map_err(|e| format!("Failed to create directories: {}", e))?;
    }
    Ok(())
}

/// Duplicate a source file to a destination, creating parent directories if needed
/// Returns the contents that were written
pub fn duplicate_file(source: &Path, dest: &Path) -> Result<String, String> {
    // Create parent directories if needed
    ensure_parent_dirs(dest)?;
    
    // Read source file contents if it exists, otherwise use empty string
    let file_contents = if source.exists() {
        fs::read_to_string(source)
            .map_err(|e| format!("Failed to read source file: {}", e))?
    } else {
        String::new()
    };
    
    // Write to destination
    fs::write(dest, &file_contents)
        .map_err(|e| format!("Failed to write destination file: {}", e))?;
    
    Ok(file_contents)
}

/// Delete a file if it exists
pub fn delete_file(file_path: &Path) -> Result<(), String> {
    if file_path.exists() {
        fs::remove_file(file_path)
            .map_err(|e| format!("Failed to delete file: {}", e))?;
    }
    Ok(())
}

/// Check if a file exists, handling both absolute and relative paths
pub fn file_exists(file_path: &Path) -> bool {
    if file_path.is_absolute() {
        file_path.exists()
    } else {
        file_path.canonicalize().is_ok() || file_path.exists()
    }
}
