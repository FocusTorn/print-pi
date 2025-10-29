// Detour - File overlay/detour management system
// Main entry point for the TUI application

use crossterm::{
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{backend::CrosstermBackend, Terminal};
use std::io;

mod app;
mod events;
mod ui;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Check if running in TUI mode or CLI mode
    let args: Vec<String> = std::env::args().collect();
    
    if args.len() > 1 {
        // CLI mode - show message for now
        println!("Detour CLI");
        println!("For TUI, run without arguments: detour");
        println!("\nCurrent implementation: lib/detour-core.sh");
        println!("Run: bin/detour <command>");
        return Ok(());
    }
    
    // TUI mode
    run_tui()
}

fn run_tui() -> Result<(), Box<dyn std::error::Error>> {
    // Setup terminal
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;
    
    // Create app state
    let mut app = app::App::new();
    
    // Main loop
    loop {
        terminal.draw(|f| ui::ui(f, &mut app))?;
        
        events::handle_events(&mut app)?;
        
        if app.should_quit {
            break;
        }
    }
    
    // Restore terminal
    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;
    
    Ok(())
}

