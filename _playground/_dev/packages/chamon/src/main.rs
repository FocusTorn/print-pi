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
use std::env;

const VERSION: &str = env!("CARGO_PKG_VERSION");
const NAME: &str = env!("CARGO_PKG_NAME");

fn main() -> Result<(), Box<dyn std::error::Error>> {
    
    // Parse command line arguments ------------------------------------------->> 
    let args: Vec<String> = env::args().collect();
    
    if args.len() > 1 {
        match args[1].as_str() {
            "--version" | "-v" => {
                println!("{} v{}", NAME, VERSION);
                return Ok(());
            }
            "--help" | "-h" => {
                print_help();
                return Ok(());
            }
            _ => {
                eprintln!("Unknown option: {}", args[1]);
                eprintln!("Try '{} --help' for more information.", args[0]);
                std::process::exit(1);
            }
        }
    }
    //--------------------------------------------------------------------------------------------<<
    
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

fn run_app<B: Backend>(terminal: &mut Terminal<B>, app: &mut App) -> io::Result<()> {
    loop {
        // Check for fake async baseline completion
        app.check_baseline_creation();
        
        terminal.draw(|f| ui::ui(f, app))?;

        if events::handle_events(app)? {
            break;
        }
    }
    Ok(())
}

fn print_help() {
    println!("Chamon - System Monitoring TUI");
    println!();
    println!("USAGE:");
    println!("    chamon [OPTIONS]");
    println!();
    println!("OPTIONS:");
    println!("    -h, --help       Print this help message");
    println!("    -v, --version    Print version information");
    println!();
    println!("DESCRIPTION:");
    println!("    A terminal-based system monitoring tool for tracking file changes,");
    println!("    system status, and git repository management.");
    println!();
    println!("CONTROLS:");
    println!("    Arrow Keys    - Navigate columns and selections");
    println!("    Enter         - Execute selected command");
    println!("    q/Esc         - Quit the application");
    println!();
}
