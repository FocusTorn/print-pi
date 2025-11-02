// Shared form operations - simple helpers that work with field references

/// Handle character input - inserts char at cursor position
pub fn handle_char(field: &mut String, cursor_pos: &mut usize, c: char) {
    let pos = (*cursor_pos).min(field.len());
    field.insert(pos, c);
    *cursor_pos += 1;
}

/// Handle backspace - removes char before cursor
pub fn handle_backspace(field: &mut String, cursor_pos: &mut usize) {
    if *cursor_pos > 0 && *cursor_pos <= field.len() {
        field.remove(*cursor_pos - 1);
        *cursor_pos -= 1;
    }
}

/// Move cursor left
pub fn move_cursor_left(cursor_pos: &mut usize) {
    if *cursor_pos > 0 {
        *cursor_pos -= 1;
    }
}

/// Move cursor right
pub fn move_cursor_right(field_len: usize, cursor_pos: &mut usize) {
    if *cursor_pos < field_len {
        *cursor_pos += 1;
    }
}

/// Complete path with tab - returns the completed path if found, or None
pub fn complete_path_tab(current_text: &str) -> Option<String> {
    use crate::filebrowser::{complete_path, expand_path_shorthand};
    
    // Try zsh-style expansion first
    if let Some(expansions) = expand_path_shorthand(current_text) {
        if !expansions.is_empty() {
            return Some(expansions[0].clone());
        }
    }
    
    // Fall back to standard tab completion
    let completions = complete_path(current_text);
    if !completions.is_empty() {
        return Some(completions[0].clone());
    }
    
    None
}

/// Paste from clipboard - returns clipboard text or None
pub fn paste_clipboard() -> Option<String> {
    use arboard::Clipboard;
    if let Ok(mut clipboard) = Clipboard::new() {
        if let Ok(text) = clipboard.get_text() {
            return Some(text);
        }
    }
    None
}

