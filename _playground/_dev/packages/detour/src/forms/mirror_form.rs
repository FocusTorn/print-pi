// Mirror form handling logic

use crate::app::AddMirrorForm;
use crate::forms::base;

pub fn handle_char(form: &mut AddMirrorForm, c: char) {
    let field = match form.active_field {
        0 => &mut form.source_path,
        1 => &mut form.target_path,
        2 => &mut form.description,
        _ => return,
    };
    base::handle_char(field, &mut form.cursor_pos, c);
}

pub fn handle_backspace(form: &mut AddMirrorForm) {
    let field = match form.active_field {
        0 => &mut form.source_path,
        1 => &mut form.target_path,
        2 => &mut form.description,
        _ => return,
    };
    base::handle_backspace(field, &mut form.cursor_pos);
}

pub fn move_cursor_left(form: &mut AddMirrorForm) {
    base::move_cursor_left(&mut form.cursor_pos);
}

pub fn move_cursor_right(form: &mut AddMirrorForm) {
    let len = match form.active_field {
        0 => form.source_path.len(),
        1 => form.target_path.len(),
        2 => form.description.len(),
        _ => 0,
    };
    base::move_cursor_right(len, &mut form.cursor_pos);
}

pub fn next_field(form: &mut AddMirrorForm) -> bool {
    if form.active_field < 2 {
        form.active_field += 1;
        let field = match form.active_field {
            0 => &form.source_path,
            1 => &form.target_path,
            2 => &form.description,
            _ => &form.source_path,
        };
        form.cursor_pos = field.len();
        false
    } else {
        true // Last field, signal to submit
    }
}

pub fn prev_field(form: &mut AddMirrorForm) {
    if form.active_field > 0 {
        form.active_field -= 1;
        let field = match form.active_field {
            0 => &form.source_path,
            1 => &form.target_path,
            2 => &form.description,
            _ => &form.source_path,
        };
        form.cursor_pos = field.len();
    }
}

pub fn complete_path(form: &mut AddMirrorForm) {
    let current_text = match form.active_field {
        0 => &form.source_path,
        1 => &form.target_path,
        _ => return, // Don't complete description field
    };

    if let Some(completed) = base::complete_path_tab(current_text) {
        match form.active_field {
            0 => {
                form.source_path = completed.clone();
                form.cursor_pos = completed.len();
            }
            1 => {
                form.target_path = completed.clone();
                form.cursor_pos = completed.len();
            }
            _ => {}
        }
    }
}

pub fn paste_clipboard(form: &mut AddMirrorForm) {
    if let Some(text) = base::paste_clipboard() {
        // Insert clipboard text at cursor position
        for c in text.chars() {
            handle_char(form, c);
        }
    }
}

