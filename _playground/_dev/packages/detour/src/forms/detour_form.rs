// Detour form handling logic

use crate::app::AddDetourForm;
use crate::forms::base;

pub fn handle_char(form: &mut AddDetourForm, c: char) {
    let field = match form.active_field {
        0 => &mut form.original_path,
        1 => &mut form.custom_path,
        2 => &mut form.description,
        _ => return,
    };
    base::handle_char(field, &mut form.cursor_pos, c);
}

pub fn handle_backspace(form: &mut AddDetourForm) {
    let field = match form.active_field {
        0 => &mut form.original_path,
        1 => &mut form.custom_path,
        2 => &mut form.description,
        _ => return,
    };
    base::handle_backspace(field, &mut form.cursor_pos);
}

pub fn move_cursor_left(form: &mut AddDetourForm) {
    base::move_cursor_left(&mut form.cursor_pos);
}

pub fn move_cursor_right(form: &mut AddDetourForm) {
    let len = match form.active_field {
        0 => form.original_path.len(),
        1 => form.custom_path.len(),
        2 => form.description.len(),
        _ => 0,
    };
    base::move_cursor_right(len, &mut form.cursor_pos);
}

pub fn next_field(form: &mut AddDetourForm) {
    form.active_field = (form.active_field + 1) % 3;
    let field = match form.active_field {
        0 => &form.original_path,
        1 => &form.custom_path,
        2 => &form.description,
        _ => &form.original_path,
    };
    form.cursor_pos = field.len();
}

pub fn complete_path(form: &mut AddDetourForm) {
    let current_text = match form.active_field {
        0 => &form.original_path,
        1 => &form.custom_path,
        _ => return, // Don't complete description field
    };

    if let Some(completed) = base::complete_path_tab(current_text) {
        match form.active_field {
            0 => {
                form.original_path = completed.clone();
                form.cursor_pos = completed.len();
            }
            1 => {
                form.custom_path = completed.clone();
                form.cursor_pos = completed.len();
            }
            _ => {}
        }
    }
}

pub fn paste_clipboard(form: &mut AddDetourForm) {
    if let Some(text) = base::paste_clipboard() {
        // Insert clipboard text at cursor position
        for c in text.chars() {
            handle_char(form, c);
        }
    }
}


