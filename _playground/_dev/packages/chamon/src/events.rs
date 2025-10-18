use crate::app::App;
use crossterm::event::{Event, KeyCode, KeyEventKind, MouseEvent, MouseEventKind};
use std::io;
use std::time::Duration;

pub fn handle_events(app: &mut App) -> io::Result<bool> { //>
    if crossterm::event::poll(Duration::from_millis(250))? {
        match crossterm::event::read()? {
            Event::Key(key) => {
                if key.kind == KeyEventKind::Press {
                    handle_keyboard_input(app, key.code);
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

fn handle_keyboard_input(app: &mut App, key_code: KeyCode) {
    match key_code {
        KeyCode::Char('q') => { //>
            app.should_quit = true;
        } //<
        KeyCode::Char('w') => { //>
            app.switch_file_view();
        } //<
        KeyCode::PageUp => { //>
            app.switch_to_previous_file_view();
        } //<
        KeyCode::PageDown => { //>
            app.switch_to_next_file_view();
        } //<
        KeyCode::Char('h') => { //>
            // Show help - could be implemented later
        } //<
        KeyCode::Up => { //>
            if app.selected_action > 0 {
                app.selected_action -= 1;
                app.action_state.select(Some(app.selected_action));
            }
        } //<
        KeyCode::Down => { //>
            if app.selected_action < app.actions.len() - 1 {
                app.selected_action += 1;
                app.action_state.select(Some(app.selected_action));
            }
        } //<
        KeyCode::Right => { //>
            if !app.file_changes.is_empty() && app.selected_file < app.file_changes.len() - 1 {
                app.selected_file += 1;
                app.file_state.select(Some(app.selected_file));
                // Update scrollbar position
                app.file_scrollbar = app.file_scrollbar.position(app.selected_file);
            }
        } //<
        KeyCode::Left => { //>
            if !app.file_changes.is_empty() && app.selected_file > 0 {
                app.selected_file -= 1;
                app.file_state.select(Some(app.selected_file));
                // Update scrollbar position
                app.file_scrollbar = app.file_scrollbar.position(app.selected_file);
            }
        } //<
        KeyCode::Enter => { //>
            app.execute_action();
        } //<
        
        // Dynamic key bindings from config
        KeyCode::Char(c) => {
            app.handle_config_key(c);
        }
        
        _ => {}
    }
}

fn handle_mouse_input(app: &mut App, mouse: MouseEvent) {
    // Calculate the widest command text for positioning (same logic as UI)
    let max_command_width = app.actions.iter()
        .map(|action| action.name.len())
        .max()
        .unwrap_or(20);
    
    // Calculate the boundary between panels dynamically
    let commands_area_end = 12 + max_command_width as u16;
    
    match mouse.kind {
        MouseEventKind::ScrollUp => {
            // Scroll up - prioritize the panel that's more likely to be focused
            if mouse.column < commands_area_end {
                // Left side - scroll commands
                if app.selected_action > 0 {
                    app.selected_action -= 1;
                    app.action_state.select(Some(app.selected_action));
                }
            } else {
                // Right side - scroll files
                if !app.file_changes.is_empty() && app.selected_file > 0 {
                    app.selected_file -= 1;
                    app.file_state.select(Some(app.selected_file));
                    app.file_scrollbar = app.file_scrollbar.position(app.selected_file);
                }
            }
        }
        MouseEventKind::ScrollDown => {
            // Scroll down - same logic as scroll up
            if mouse.column < commands_area_end {
                // Left side - scroll commands
                if app.selected_action < app.actions.len() - 1 {
                    app.selected_action += 1;
                    app.action_state.select(Some(app.selected_action));
                }
            } else {
                // Right side - scroll files
                if !app.file_changes.is_empty() && app.selected_file < app.file_changes.len() - 1 {
                    app.selected_file += 1;
                    app.file_state.select(Some(app.selected_file));
                    app.file_scrollbar = app.file_scrollbar.position(app.selected_file);
                }
            }
        }
        MouseEventKind::Down(button) => {
            match button {
                crossterm::event::MouseButton::Left => {
                    handle_left_click(app, mouse);
                }
                crossterm::event::MouseButton::Right => {
                    // Right click - could show context menu or execute action
                    app.execute_action();
                }
                crossterm::event::MouseButton::Middle => {
                    // Middle click - could be used for special actions
                    app.show_diff_view();
                }
            }
        }
        _ => {}
    }
}

fn handle_left_click(app: &mut App, mouse: MouseEvent) {
    // Calculate the widest command text for positioning (same logic as UI)
    let max_command_width = app.actions.iter()
        .map(|action| action.name.len())
        .max()
        .unwrap_or(20);
    
    // Calculate the boundary between panels dynamically
    // Commands area: inner_area.x + 1 to inner_area.x + 1 + max_command_width + 10
    // File area starts at: inner_area.x + 1 + max_command_width + 10
    // Since inner_area.x = area.x + 1, and area.x = 0, inner_area.x = 1
    // So commands area: 1 + 1 to 1 + 1 + max_command_width + 10 = 2 to 12 + max_command_width
    // File area starts at: 12 + max_command_width
    let commands_area_end = 12 + max_command_width as u16;
    
    if mouse.column < commands_area_end {
        // Left panel - commands area
        // Calculate which command was clicked based on row
        let command_index = mouse.row.saturating_sub(4) as usize; // Account for border + title area
        
        if command_index < app.actions.len() {
            app.selected_action = command_index;
            app.action_state.select(Some(command_index));
        }
    } else {
        // Right panel - files area
        // Calculate which file was clicked based on row
        let file_index = mouse.row.saturating_sub(4) as usize; // Account for border + title area
        
        if !app.file_changes.is_empty() && file_index < app.file_changes.len() {
            app.selected_file = file_index;
            app.file_state.select(Some(file_index));
            app.file_scrollbar = app.file_scrollbar.position(file_index);
        }
    }
}
