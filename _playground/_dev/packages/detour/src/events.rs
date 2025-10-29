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
    match key.code {
        // Quit
        KeyCode::Char('q') | KeyCode::Char('Q') => {
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
            app.navigate_next_column();
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
            // Reload config
        }
        KeyCode::Char('v') => {
            // Validate
        }
        KeyCode::Char('s') => {
            app.view_mode = crate::app::ViewMode::StatusOverview;
        }
        
        _ => {}
    }
}


