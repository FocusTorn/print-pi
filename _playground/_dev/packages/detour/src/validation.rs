// Shared validation helpers

/// Validate that a string is not empty
pub fn validate_not_empty(value: &str, field_name: &str) -> Result<(), String> {
    if value.trim().is_empty() {
        Err(format!("{} is required", field_name))
    } else {
        Ok(())
    }
}

/// Validate that multiple fields are not empty
pub fn validate_fields_not_empty(fields: &[(&str, &str)]) -> Result<(), String> {
    for (value, name) in fields {
        validate_not_empty(value, name)?;
    }
    Ok(())
}

/// Format validation error message
pub fn format_validation_error(message: &str) -> String {
    format!("Validation Error: {}", message)
}

