// Event handling for detour TUI

use crossterm::event::{self, Event, KeyCode, KeyEvent, KeyModifiers};
use std::time::Duration;

pub fn handle_events(app: &mut crate::app::App) -> std::io::Result<()> {
    if event::poll(Duration::from_millis(100))? {
        if let Event::Key(key) = event::read()? {
            handle_key_event(key, app);
        }
    }
    Ok(())
}

fn handle_key_event(key: KeyEvent, app: &mut crate::app::App) {
    // If popup is open, handle popup-specific keys
    if app.popup.is_some() {
        handle_popup_keys(key, app);
        return;
    }
    
    // If diff viewer is open, handle diff-specific keys
    if app.diff_viewer.is_some() {
        handle_diff_keys(key, app);
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
            // Right arrow also selects items (like Enter)
            app.handle_enter();
        }
        
        // Tab navigation
        KeyCode::Tab => {
            app.navigate_next_column();
        }
        KeyCode::BackTab => {
            app.navigate_prev_column();
        }
        
        // Actions
        KeyCode::Enter => {
            app.handle_enter();
        }
        KeyCode::Char(' ') => {
            app.handle_space();
        }
        
        // Quick actions
        KeyCode::Char('a') => {
            app.view_mode = crate::app::ViewMode::DetoursAdd;
            app.active_column = crate::app::ActiveColumn::Content;
        }
        KeyCode::Char('r') => {
            app.reload_config();
        }
        KeyCode::Char('v') => {
            app.show_info("Validate", "Config validation coming soon!");
        }
        KeyCode::Char('s') => {
            app.view_mode = crate::app::ViewMode::StatusOverview;
        }
        KeyCode::Char('d') => {
            // Show diff for selected detour
            if app.view_mode == crate::app::ViewMode::DetoursList {
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
                        if popup.is_yes_selected() {
                            // Execute the confirmed action
                            app.close_popup();
                            // The specific action will be handled by the context that created the popup
                        } else {
                            app.close_popup();
                        }
                    }
                    Popup::Input { .. } => {
                        // Get the input value
                        if let Some(_input) = popup.get_input() {
                            app.close_popup();
                            // The input will be processed by the context that created the popup
                        }
                    }
                    Popup::Error { .. } | Popup::Info { .. } => {
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


