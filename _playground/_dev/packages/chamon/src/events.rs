use crate::app::{App, ActiveColumn, ViewMode};
use crate::baseline::Baseline;
use crossterm::event::{Event, KeyCode, KeyEvent, KeyEventKind, MouseEvent};
use std::io;
use std::time::Duration;

pub fn handle_events(app: &mut App) -> io::Result<bool> { //>
    if crossterm::event::poll(Duration::from_millis(100))? {
        match crossterm::event::read()? {
            Event::Key(key) => {
                if key.kind == KeyEventKind::Press {
                    handle_keyboard_input(app, key);
                }
            }
            Event::Mouse(mouse) => {
                handle_mouse_input(app, mouse);
            }
            _ => {}
        }
    }
    
    Ok(app.should_quit)
} //<

fn handle_keyboard_input(app: &mut App, key: KeyEvent) {
    // If popup is visible, handle popup input only
    if app.popup.is_some() {
        handle_popup_input(app, key);
        return;
    }
    
    let key_code = key.code;
    
    match key_code {
        KeyCode::Char('q') | KeyCode::Esc => { //>
            app.should_quit = true;
        } //<
        KeyCode::Up => { //>
            app.move_up();
        } //<
        KeyCode::Down => { //>
            app.move_down();
        } //<
        KeyCode::Left => { //>
            app.move_left();
        } //<
        KeyCode::Right => { //>
            app.move_right();
        } //<
        KeyCode::Enter => { //>
            // In Column 2: check if command has select indicator
            if app.active_column == ActiveColumn::Commands {
                let commands = app.get_current_commands().clone();
                if let Some(cmd) = commands.get(app.selected_command) {
                    if cmd.select.is_some() {
                        // Has select - move to Column 3 (same as right arrow)
                        app.move_right();
                    } else {
                        // No select - execute command
                        app.execute_current_command();
                    }
                }
            } else if app.active_column == ActiveColumn::Content {
                // In Column 3, execute command
                app.execute_current_command();
            }
        } //<
        
        // Key bindings for commands (work from any column)
        KeyCode::Char(c) => {
            handle_key_command(app, c);
        }
        
        // Delete key - check panel-specific bindings
        KeyCode::Delete => {
            handle_panel_binding(app, "del");
        }
        
        _ => {}
    }
}

fn handle_key_command(app: &mut App, key: char) {
    // Column 1 bindings are ALWAYS active (view selectors)
    match key {
        'c' => {
            // Select Changes view and focus column 2
            app.selected_view = 0;
            app.view_state.select(Some(0));
            app.view_mode = ViewMode::Changes;
            app.active_column = ActiveColumn::Commands;
            app.selected_command = 0;
            app.last_selected_command = 0;
            app.command_state.select(Some(0));
            return;
        }
        'b' => {
            // Select Baseline view and focus column 2
            app.selected_view = 1;
            app.view_state.select(Some(1));
            app.view_mode = ViewMode::Baseline;
            app.active_column = ActiveColumn::Commands;
            app.selected_command = 0;
            app.last_selected_command = 0;
            app.command_state.select(Some(0));
            // Reload baseline versions when switching to baseline view
            app.baseline_versions = Baseline::list_versions(&app.data_dir).unwrap_or_default();
            // Start at index 0 (first delta baseline, Initial is at bottom)
            app.selected_baseline = 0;
            app.baseline_list_state.select(Some(0));
            return;
        }
        _ => {}
    }
    
    // Column 2 bindings - only active for current view's commands
    let commands = app.get_current_commands().clone();
    if let Some(index) = commands.iter().position(|cmd| cmd.key == Some(key)) {
        let is_temp_command = app.active_column == ActiveColumn::Content && index != app.selected_command;
        
        if is_temp_command {
            // Store current selection before temp switch
            app.last_selected_command = app.selected_command;
        }
        
        // FIRST: Update the visual selection to show which command is executing
        app.selected_command = index;
        app.command_state.select(Some(index));
        
        // SECOND: Execute command (may show popup or perform action)
        app.execute_current_command();
        
        // THIRD: Handle post-execution behavior
        if is_temp_command {
            // For temp commands, revert happens after popup is dismissed or command completes
            // The popup system will handle reverting via popup_confirm/popup_cancel
            // For non-popup commands, revert immediately
            if app.popup.is_none() {
                app.selected_command = app.last_selected_command;
                app.command_state.select(Some(app.last_selected_command));
            }
        } else {
            // Permanent selection - move focus to column 3 if command has select indicator
            if commands[index].select.is_some() {
                // Commands with select indicator - move to column 3
                app.active_column = ActiveColumn::Content;
                app.last_selected_command = index; // Remember this as the "active" command
            }
            // Commands without select stay in column 2 (they execute immediately)
        }
    }
    
    // Check panel-specific bindings
    handle_panel_binding(app, &key.to_string());
}

fn handle_panel_binding(app: &mut App, key_str: &str) { //>
    // Check if baseline panel is active and has bindings for this key
    if app.view_mode == ViewMode::Baseline && app.active_column == ActiveColumn::Content {
        let bindings = app.config.baseline_panel.help_line.bindings.clone();
        
        for binding in bindings {
            if binding.key == key_str {
                app.execute_command(&binding.command);
                return;
            }
        }
    }
    
    // Add more panel bindings here as needed (changes panel, etc.)
} //<

fn handle_popup_input(app: &mut App, key: KeyEvent) { //>
    // Check popup type for different handling
    let is_input_popup = if let Some(popup) = &app.popup {
        matches!(popup.popup_type, 
            crate::app::PopupType::InputDirectory { .. } | 
            crate::app::PopupType::InputRemapPath { .. })
    } else {
        false
    };
    
    let key_code = key.code;
    match key_code {
        KeyCode::Esc => {
            app.popup_cancel();
        }
        KeyCode::Left => {
            app.popup_move_left();
        }
        KeyCode::Right => {
            app.popup_move_right();
        }
        KeyCode::Enter => {
            app.popup_confirm();
        }
        KeyCode::Backspace => {
            if is_input_popup {
                app.popup_backspace();
            }
        }
        KeyCode::Char(c) => {
            if is_input_popup {
                // Text input for directory path
                app.popup_input_char(c);
            } else {
                // Confirmation popup shortcuts
                match c {
                    'y' => {
                        // Directly select Yes
                        if let Some(popup) = &mut app.popup {
                            match &mut popup.popup_type {
                                crate::app::PopupType::ConfirmDeleteBaseline { selected_option, .. } | 
                                crate::app::PopupType::ConfirmOverwriteInitial { selected_option, .. } => {
                                    *selected_option = 0;
                                }
                                _ => {}
                            }
                        }
                        app.popup_confirm();
                    }
                    'n' => {
                        // Directly select No (cancel)
                        app.popup_cancel();
                    }
                    _ => {}
                }
            }
        }
        _ => {
            // Ignore all other keys when popup is visible
        }
    }
} //<

fn handle_mouse_input(_app: &mut App, _mouse: MouseEvent) {
    // Mouse input simplified for now - can be enhanced later
    // TODO: Implement column detection and click handling for new 3-column layout
}
