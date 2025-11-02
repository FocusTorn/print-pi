// Include form handling logic

use crate::app::AddInjectionForm;
use crate::forms::base;

pub fn handle_char(form: &mut AddInjectionForm, c: char) {
    let field = match form.active_field {
        0 => &mut form.target_path,
        1 => &mut form.include_path,
        2 => &mut form.description,
        _ => return,
    };
    base::handle_char(field, &mut form.cursor_pos, c);
}

pub fn handle_backspace(form: &mut AddInjectionForm) {
    let field = match form.active_field {
        0 => &mut form.target_path,
        1 => &mut form.include_path,
        2 => &mut form.description,
        _ => return,
    };
    base::handle_backspace(field, &mut form.cursor_pos);
}

pub fn move_cursor_left(form: &mut AddInjectionForm) {
    base::move_cursor_left(&mut form.cursor_pos);
}

pub fn move_cursor_right(form: &mut AddInjectionForm) {
    let len = match form.active_field {
        0 => form.target_path.len(),
        1 => form.include_path.len(),
        2 => form.description.len(),
        _ => 0,
    };
    base::move_cursor_right(len, &mut form.cursor_pos);
}

pub fn next_field(form: &mut AddInjectionForm) -> bool {
    if form.active_field < 2 {
        form.active_field += 1;
        form.cursor_pos = 0;
        false
    } else {
        true // Should submit
    }
}

pub fn prev_field(form: &mut AddInjectionForm) {
    if form.active_field > 0 {
        form.active_field -= 1;
        form.cursor_pos = 0;
    }
}

pub fn complete_path(form: &mut AddInjectionForm) -> bool {
    let current_text = match form.active_field {
        0 => &form.target_path,
        1 => &form.include_path,
        2 => return true, // Should submit
        _ => return false,
    };

    if let Some(completed) = base::complete_path_tab(current_text) {
        match form.active_field {
            0 => {
                form.target_path = completed.clone();
                form.cursor_pos = completed.len();
            }
            1 => {
                form.include_path = completed.clone();
                form.cursor_pos = completed.len();
            }
            _ => {}
        }
        false // Don't submit
    } else {
        true // Should submit (next field)
    }
}

pub fn paste_clipboard(form: &mut AddInjectionForm) {
    if let Some(text) = base::paste_clipboard() {
        // Insert clipboard text at cursor position (same as detour form)
        for c in text.chars() {
            handle_char(form, c);
        }
    }
}

