use chamon_tui::{App, events, ui};
use crossterm::{ //>
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
    event::{DisableMouseCapture, EnableMouseCapture},
}; //<
use ratatui::{ //>
    backend::{Backend, CrosstermBackend},
    Terminal,
}; //<
use std::io;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    
    // Check terminal size before starting ------------------------------------>> 
    let terminal_size = crossterm::terminal::size()?;
    if terminal_size.0 < 80 || terminal_size.1 < 13 {
        eprintln!("Terminal too small! Minimum size required: 80x20");
        eprintln!("Current size: {}x{}", terminal_size.0, terminal_size.1);
        eprintln!("Please resize your terminal and try again.");
        return Ok(());
    }
    
    //--------------------------------------------------------------------------------------------<<

    // Setup terminal --------------------------------------------------------->> 
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    //--------------------------------------------------------------------------------------------<<
    
    // Create app and run
    let mut app = App::new();
    let res = run_app(&mut terminal, &mut app);

    // Restore terminal
    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;
    terminal.show_cursor()?;

    if let Err(err) = res {
        println!("{err:?}");
    }

    Ok(())
}

fn run_app<B: Backend>(terminal: &mut Terminal<B>, app: &mut App) -> io::Result<()> { //>
    loop {
        terminal.draw(|f| ui::ui(f, app))?;

        if events::handle_events(app)? {
            break;
        }
    }
    Ok(())
} //<