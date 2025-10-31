// Detour - File overlay/detour management system
// Main entry point for the TUI application

use clap::{Parser, Subcommand};
use crossterm::{
    event::{DisableMouseCapture, EnableMouseCapture},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{backend::CrosstermBackend, Terminal};
use std::io;
use std::process::Command;

use detour::{app, events, ui};

#[derive(Parser)]
#[command(name = "detour")]
#[command(about = "File overlay/detour management system", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    /// Build the detour binary (development mode)
    #[command(alias = "b")]
    Build,
    
    /// Build the detour binary (release mode)
    #[command(alias = "br")]
    BuildRelease,
    
    /// Run build (dev) then start TUI
    #[command(alias = "rb")]
    RunBuild,
    
    /// Run build (release) then start TUI
    #[command(alias = "rbr")]
    RunBuildRelease,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();
    
    match cli.command {
        Some(Commands::Build) => {
            // Build with cargo output visible, no custom messages
            let status = Command::new("cargo")
                .arg("build")
                .arg("--manifest-path")
                .arg("/home/pi/_playground/_dev/packages/detour/Cargo.toml")
                .status()?;
            
            std::process::exit(if status.success() { 0 } else { 1 });
        }
        Some(Commands::BuildRelease) => {
            // Build release with cargo output visible, no custom messages
            let status = Command::new("cargo")
                .arg("build")
                .arg("--release")
                .arg("--manifest-path")
                .arg("/home/pi/_playground/_dev/packages/detour/Cargo.toml")
                .status()?;
            
            std::process::exit(if status.success() { 0 } else { 1 });
        }
        Some(Commands::RunBuild) => {
            // Build in dev mode (show cargo output)
            let status = Command::new("cargo")
                .arg("build")
                .arg("--manifest-path")
                .arg("/home/pi/_playground/_dev/packages/detour/Cargo.toml")
                .status()?;
            
            if !status.success() {
                std::process::exit(1);
            }
            
            // Launch TUI
            run_tui()
        }
        Some(Commands::RunBuildRelease) => {
            // Build in release mode (show cargo output)
            let status = Command::new("cargo")
                .arg("build")
                .arg("--release")
                .arg("--manifest-path")
                .arg("/home/pi/_playground/_dev/packages/detour/Cargo.toml")
                .status()?;
            
            if !status.success() {
                std::process::exit(1);
            }
            
            // Launch TUI
            run_tui()
        }
        None => {
            // No subcommand - launch TUI
            run_tui()
        }
    }
}

fn run_tui() -> Result<(), Box<dyn std::error::Error>> {
    // Setup terminal
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
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
    execute!(terminal.backend_mut(), LeaveAlternateScreen, DisableMouseCapture)?;
    terminal.show_cursor()?;
    
    Ok(())
}

