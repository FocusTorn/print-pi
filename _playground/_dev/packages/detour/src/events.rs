// Event handling for detour TUI

use crossterm::event::{self, Event, KeyCode, KeyEvent, KeyModifiers, MouseEvent, MouseEventKind};
use std::time::Duration;

pub fn handle_events(app: &mut crate::app::App) -> std::io::Result<()> {
    // Check for auto-dismiss of toasts (2.5 seconds)
    app.toasts.retain(|toast| {
        toast.shown_at.elapsed().map(|d| d.as_secs_f32() <= 2.5).unwrap_or(false)
    });
    
    if event::poll(Duration::from_millis(100))? {
        match event::read()? {
            Event::Key(key) => {
                handle_key_event(key, app);
            }
            Event::Mouse(mouse) => {
                handle_mouse_event(mouse, app);
            }
            _ => {}
        }
    }
    Ok(())
}

fn handle_key_event(key: KeyEvent, app: &mut crate::app::App) {
    // If file browser is open, handle browser-specific keys
    if app.file_browser.is_some() {
        handle_file_browser_keys(key, app);
        return;
    }
    
    // If popup is open, handle popup-specific keys
    if app.popup.is_some() {
        handle_popup_keys(key, app);
        return;
    }
    
    // If validation report is open, handle validation report keys
    if app.validation_report.is_some() {
        handle_validation_report_keys(key, app);
        return;
    }
    
    // If diff viewer is open, handle diff-specific keys
    if app.diff_viewer.is_some() {
        handle_diff_keys(key, app);
        return;
    }
    
    // If in Add/Edit Detour form OR Injections add form AND Column 3 is active, handle form-specific keys
    if (app.view_mode == crate::app::ViewMode::DetoursAdd || app.view_mode == crate::app::ViewMode::DetoursEdit || app.view_mode == crate::app::ViewMode::InjectionsAdd)
        && app.active_column == crate::app::ActiveColumn::Content {
        if app.view_mode == crate::app::ViewMode::InjectionsAdd {
            handle_injection_form_keys(key, app);
        } else {
            handle_form_keys(key, app);
        }
        return;
    }
    
    match key.code {
        // Quit
        KeyCode::Esc | KeyCode::Char('q') | KeyCode::Char('Q') => {
            app.should_quit = true;
        }
        KeyCode::Char('c') if key.modifiers.contains(KeyModifiers::CONTROL) => {
            app.should_quit = true;
        }
        
        // Navigation - Up/Down
        KeyCode::Up | KeyCode::Char('k') => {
            app.navigate_up();
        }
        KeyCode::Down | KeyCode::Char('j') => {
            app.navigate_down();
        }
        
        // Navigation - Left/Right (columns)
        KeyCode::Left | KeyCode::Char('h') => {
            app.navigate_prev_column();
        }
        KeyCode::Right | KeyCode::Char('l') => {
            // Right arrow moves to next column
            app.navigate_next_column();
        }
        
        // Actions
        KeyCode::Enter => {
            app.handle_enter();
        }
        KeyCode::Char(' ') => {
            app.handle_space();
        }
        
        // Quick actions
        KeyCode::Char('n') => {
            // New works regardless of column focus
            if app.view_mode == crate::app::ViewMode::DetoursList {
                app.view_mode = crate::app::ViewMode::DetoursAdd;
                app.add_form = crate::app::AddDetourForm::default();
                app.active_column = crate::app::ActiveColumn::Content;
            } else if app.view_mode == crate::app::ViewMode::InjectionsList {
                app.view_mode = crate::app::ViewMode::InjectionsAdd;
                // Set default values for injection form
                app.injection_form = crate::app::AddInjectionForm {
                    target_path: "/boot/firmware/config.txt".to_string(),
                    include_path: "/home/pi/_playground/root/boot/firmware-config.txt".to_string(),
                    description: String::new(),
                    active_field: 0,
                    cursor_pos: 0,
                    editing_index: None,
                };
                app.active_column = crate::app::ActiveColumn::Content;
            } else if app.view_mode == crate::app::ViewMode::MirrorsList {
                // For now, show message that form is not yet implemented
                app.show_error("Not Implemented".to_string(), 
                    "Mirror add form not yet implemented.\n\nYou can manually add mirrors to ~/.detour.yaml:\n\nmirrors:\n  - source: /home/pi/_playground/path/to/source\n    target: /path/to/target\n    description: Optional description".to_string());
            }
        }
        KeyCode::Char('e') => {
            if key.modifiers.contains(KeyModifiers::CONTROL) {
                // Open config.yaml in default editor
                let config_path = "/home/pi/_playground/_dev/packages/detour/config.yaml";
                use std::process::Command;
                let editor = std::env::var("EDITOR").unwrap_or_else(|_| "nano".to_string());
                if let Err(e) = Command::new(&editor).arg(config_path).status() {
                    app.add_toast(format!("Failed to open editor: {}", e), crate::app::ToastType::Error);
                } else {
                    app.add_toast("Config file opened in editor".to_string(), crate::app::ToastType::Info);
                }
            } else {
                app.handle_edit_action();
            }
        }
        KeyCode::Delete => {
            app.handle_delete_action();
        }
        KeyCode::Char('r') if key.modifiers.contains(KeyModifiers::CONTROL) => {
            app.reload_config();
        }
        KeyCode::Char('v') => {
            // Verify - context aware based on column and selection
            match app.active_column {
                crate::app::ActiveColumn::Actions => {
                    // In Actions column, trigger the selected action
                    let actions = app.get_current_actions();
                    if let Some(selected_action) = actions.get(app.selected_action) {
                        if selected_action == "Verify All" {
                            if app.view_mode == crate::app::ViewMode::DetoursList {
                                app.validate_detours_all();
                            }
                            // For includes, if Verify All action exists, handle it here
                        }
                    }
                }
                crate::app::ActiveColumn::Views => {
                    // In Views column, trigger verify all for the current view
                    if app.view_mode == crate::app::ViewMode::DetoursList {
                        app.validate_detours_all();
                    }
                }
                crate::app::ActiveColumn::Content => {
                    // In Content column, verify single selected item
                    if app.view_mode == crate::app::ViewMode::DetoursList {
                        let idx = app.selected_detour;
                        app.validate_single_detour(idx);
                    } else if app.view_mode == crate::app::ViewMode::InjectionsList {
                        let idx = app.selected_injection;
                        app.validate_single_injection(idx);
                    }
                }
            }
        }
        KeyCode::Char('a') => {
            // Activate All - context aware based on column and selection
            match app.active_column {
                crate::app::ActiveColumn::Actions => {
                    // In Actions column, trigger the selected action
                    let actions = app.get_current_actions();
                    if let Some(selected_action) = actions.get(app.selected_action) {
                        if selected_action == "Activate All" {
                            if app.view_mode == crate::app::ViewMode::DetoursList {
                                app.activate_all_detours();
                            }
                        }
                    }
                }
                crate::app::ActiveColumn::Views | crate::app::ActiveColumn::Content => {
                    // Activate All works from views or content (only for detours)
                    if app.view_mode == crate::app::ViewMode::DetoursList {
                        app.activate_all_detours();
                    }
                }
            }
        }
        KeyCode::Char('s') => {
            app.view_mode = crate::app::ViewMode::StatusOverview;
        }
        KeyCode::Char('d') => {
            // Show diff requires selection (Column 3 focused)
            if app.view_mode == crate::app::ViewMode::DetoursList 
                && app.active_column == crate::app::ActiveColumn::Content {
                if let Some(detour) = app.detours.get(app.selected_detour) {
                    let original = detour.original.clone();
                    let custom = detour.custom.clone();
                    app.show_diff(&original, &custom);
                }
            }
        }
        
        _ => {}
    }
}

fn handle_popup_keys(key: KeyEvent, app: &mut crate::app::App) {
    use crate::popup::Popup;
    
    match key.code {
        // Close popup with Escape
        KeyCode::Esc => {
            app.close_popup();
        }
        
        // For confirm popups
        KeyCode::Left | KeyCode::Char('h') => {
            app.handle_popup_left();
        }
        KeyCode::Right | KeyCode::Char('l') => {
            app.handle_popup_right();
        }
        
        // For input popups
        KeyCode::Char(c) if !key.modifiers.contains(KeyModifiers::CONTROL) => {
            if matches!(app.popup, Some(Popup::Input { .. })) {
                app.handle_popup_input(c);
            }
        }
        KeyCode::Backspace => {
            app.handle_popup_backspace();
        }
        
        // Confirm/Execute
        KeyCode::Enter => {
            if let Some(popup) = &app.popup {
                match popup {
                    Popup::Confirm { .. } => {
                        let is_yes = popup.is_yes_selected();
                        let action = app.pending_action.take();
                        app.close_popup();
                        
                        if is_yes {
                            // Execute pending action if any
                            if let Some(pending) = action {
                                match pending {
                                    crate::app::PendingAction::CreateFileAndSaveDetour => {
                                        app.create_custom_file_and_save();
                                    }
                                    crate::app::PendingAction::DeleteDetour(index) => {
                                        app.confirm_delete_detour(index);
                                    }
                                    crate::app::PendingAction::DeleteDetourAndFile(index, custom_path) => {
                                        app.delete_detour_and_file(index, custom_path, true);
                                    }
                                    crate::app::PendingAction::DeleteInjection(index) => {
                                        app.confirm_delete_injection(index);
                                    }
                                    crate::app::PendingAction::DeleteInjectionAndFile(index, include_file_path) => {
                                        app.delete_injection_and_file(index, include_file_path, true);
                                    }
                                    crate::app::PendingAction::CreateInjectionFileAndSave => {
                                        app.create_injection_file_and_save();
                                    }
                                    crate::app::PendingAction::DeleteMirror(index) => {
                                        app.confirm_delete_mirror(index);
                                    }
                                }
                            }
                        } else {
                            // User selected "No" - handle accordingly
                            match action {
                                Some(crate::app::PendingAction::DeleteDetourAndFile(_index, _)) => {
                                    // Don't delete file, just reload config (detour already deleted from config)
                                    app.reload_config();
                                    if app.selected_detour >= app.detours.len() && app.selected_detour > 0 {
                                        app.selected_detour -= 1;
                                        app.detour_state.select(Some(app.selected_detour));
                                    }
                                }
                                Some(crate::app::PendingAction::DeleteInjectionAndFile(_index, _)) => {
                                    // Don't delete file, just reload config (injection already deleted from config)
                                    app.reload_config();
                                    if app.selected_injection >= app.injections.len() && app.selected_injection > 0 {
                                        app.selected_injection -= 1;
                                        app.injection_state.select(Some(app.selected_injection));
                                    }
                                }
                                _ => {}
                            }
                        }
                    }
                    Popup::Input { .. } | Popup::Error { .. } | Popup::Info { .. } => {
                        app.close_popup();
                    }
                }
            }
        }
        
        _ => {}
    }
}

fn handle_diff_keys(key: KeyEvent, app: &mut crate::app::App) {
    match key.code {
        KeyCode::Esc | KeyCode::Char('q') => {
            app.close_diff();
        }
        KeyCode::Up | KeyCode::Char('k') => {
            app.scroll_diff_up();
        }
        KeyCode::Down | KeyCode::Char('j') => {
            app.scroll_diff_down();
        }
        KeyCode::PageUp => {
            app.scroll_diff_page_up();
        }
        KeyCode::PageDown => {
            app.scroll_diff_page_down();
        }
        _ => {}
    }
}

fn handle_injection_form_keys(key: KeyEvent, app: &mut crate::app::App) {
    match key.code {
        KeyCode::Esc => {
            app.injection_form_cancel();
        }
        KeyCode::Enter => {
            app.injection_form_submit();
        }
        KeyCode::Char('f') if key.modifiers.contains(KeyModifiers::CONTROL) => {
            app.injection_form_open_file_browser();
        }
        KeyCode::Char('v') if key.modifiers.contains(KeyModifiers::CONTROL) => {
            app.injection_form_paste_clipboard();
        }
        KeyCode::Tab => {
            app.injection_form_complete_path();
        }
        KeyCode::Backspace => {
            app.injection_form_backspace();
        }
        KeyCode::Left => {
            app.injection_form_move_cursor_left();
        }
        KeyCode::Right => {
            app.injection_form_move_cursor_right();
        }
        KeyCode::Up => {
            app.injection_form_prev_field();
        }
        KeyCode::Down => {
            app.injection_form_next_field();
        }
        KeyCode::Char(c) if !key.modifiers.contains(KeyModifiers::CONTROL) => {
            app.injection_form_handle_char(c);
        }
        _ => {}
    }
}

fn handle_form_keys(key: KeyEvent, app: &mut crate::app::App) {
    match key.code {
        // Cancel/Go back
        KeyCode::Esc => {
            app.form_cancel();
        }
        
        // Save detour
        KeyCode::Enter => {
            app.form_save_detour();
        }
        
        // Open file browser
        KeyCode::Char('f') if key.modifiers.contains(KeyModifiers::CONTROL) => {
            app.form_open_file_browser();
        }
        
        // Paste from clipboard
        KeyCode::Char('v') if key.modifiers.contains(KeyModifiers::CONTROL) => {
            app.form_paste_clipboard();
        }
        
        // Path completion or next field
        KeyCode::Tab => {
            // If in description field, just move to next field
            // If in path fields, do completion first, then move to next field
            if app.add_form.active_field == 2 {
                app.form_next_field();
            } else {
                app.form_complete_path();
            }
        }
        
        // Text input
        KeyCode::Char(c) if !key.modifiers.contains(KeyModifiers::CONTROL) => {
            app.form_handle_char(c);
        }
        
        // Backspace
        KeyCode::Backspace => {
            app.form_handle_backspace();
        }
        
        // Cursor movement (left/right within field)
        KeyCode::Left => {
            if app.add_form.cursor_pos > 0 {
                app.add_form.cursor_pos -= 1;
            }
        }
        KeyCode::Right => {
            let field_len = match app.add_form.active_field {
                0 => app.add_form.original_path.len(),
                1 => app.add_form.custom_path.len(),
                2 => app.add_form.description.len(),
                _ => 0,
            };
            if app.add_form.cursor_pos < field_len {
                app.add_form.cursor_pos += 1;
            }
        }
        
        // Field navigation (up/down between fields)
        KeyCode::Up => {
            if app.add_form.active_field > 0 {
                app.add_form.active_field -= 1;
                let field_len = match app.add_form.active_field {
                    0 => app.add_form.original_path.len(),
                    1 => app.add_form.custom_path.len(),
                    2 => app.add_form.description.len(),
                    _ => 0,
                };
                app.add_form.cursor_pos = field_len;
            }
        }
        KeyCode::Down => {
            if app.add_form.active_field < 2 {
                app.add_form.active_field += 1;
                let field_len = match app.add_form.active_field {
                    0 => app.add_form.original_path.len(),
                    1 => app.add_form.custom_path.len(),
                    2 => app.add_form.description.len(),
                    _ => 0,
                };
                app.add_form.cursor_pos = field_len;
            }
        }
        
        KeyCode::Home => {
            app.add_form.cursor_pos = 0;
        }
        KeyCode::End => {
            let field_len = match app.add_form.active_field {
                0 => app.add_form.original_path.len(),
                1 => app.add_form.custom_path.len(),
                2 => app.add_form.description.len(),
                _ => 0,
            };
            app.add_form.cursor_pos = field_len;
        }
        
        _ => {}
    }
}

fn handle_file_browser_keys(key: KeyEvent, app: &mut crate::app::App) {
    if let Some(browser) = &mut app.file_browser {
        match key.code {
            // Close browser without selection
            KeyCode::Esc => {
                if app.view_mode == crate::app::ViewMode::InjectionsAdd {
                    app.injection_form_close_file_browser(None);
                } else {
                    app.form_close_file_browser(None);
                }
            }
            
            // Select file/directory
            KeyCode::Enter => {
                if let Some(entry) = browser.entries.get(browser.selected_index) {
                    if entry.is_dir {
                        // Enter directory
                        browser.enter_directory();
                    } else {
                        // Select file
                        let path = browser.get_selected_path();
                        if app.view_mode == crate::app::ViewMode::InjectionsAdd {
                            app.injection_form_close_file_browser(path);
                        } else {
                            app.form_close_file_browser(path);
                        }
                    }
                }
            }
            
            // Navigation
            KeyCode::Up | KeyCode::Char('k') => {
                browser.navigate_up();
            }
            KeyCode::Down | KeyCode::Char('j') => {
                browser.navigate_down();
            }
            
            // Right arrow: enter directory
            KeyCode::Right => {
                if let Some(entry) = browser.entries.get(browser.selected_index) {
                    if entry.is_dir {
                        browser.enter_directory();
                    }
                }
            }
            
            // Left arrow: go to parent directory
            KeyCode::Left => {
                browser.go_to_parent();
            }
            
            _ => {}
        }
    }
}

fn handle_validation_report_keys(key: KeyEvent, app: &mut crate::app::App) {
    match key.code {
        KeyCode::Enter | KeyCode::Esc | KeyCode::Char('q') => {
            app.close_validation_report();
        }
        _ => {}
    }
}

fn handle_mouse_event(mouse: MouseEvent, app: &mut crate::app::App) {
    // Only handle mouse events in file browser for now
    if let Some(browser) = &mut app.file_browser {
        match mouse.kind {
            MouseEventKind::ScrollUp => {
                browser.scroll_up();
            }
            MouseEventKind::ScrollDown => {
                browser.scroll_down();
            }
            _ => {}
        }
    }
}


