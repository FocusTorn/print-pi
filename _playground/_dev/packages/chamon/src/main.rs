use crossterm::{ //>
    event::{self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode, KeyEventKind},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
}; //<
use ratatui::{ //>
    backend::{Backend, CrosstermBackend},
    layout::{Alignment, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, ListState, Paragraph, Scrollbar, ScrollbarOrientation, ScrollbarState, BorderType},
    Frame, Terminal,
}; //<
use serde::{ //>
    Deserialize,
    Serialize
}; //<
use std::{ //>
    io,
    process::Command,
    time::Duration,
}; //<

// ┌──────────────────────────────────────────────────────────────────────────────────────────────┐
// │                                   Configuration structures                                   │
// └──────────────────────────────────────────────────────────────────────────────────────────────┘

#[derive(Debug, Deserialize, Serialize)]
struct Config { //>
    title_bar: TitleBar,
    commands_view: CommandsView,
    files_view: FilesView,
    help_line: HelpLine,
} //<

#[derive(Debug, Deserialize, Serialize)]
struct TitleBar { //>
    display: String,
} //<

#[derive(Debug, Deserialize, Serialize)]
struct CommandsView { //>
    commands: Vec<CommandConfig>,
} //<

#[derive(Debug, Deserialize, Serialize)]
struct CommandConfig { //>
    name: String,
    key: String,
    desc: String,
    command: String,
} //<

#[derive(Debug, Deserialize, Serialize)]
struct FilesView { //>
    tab1: TabConfig,
    tab2: TabConfig,
} //<

#[derive(Debug, Deserialize, Serialize)]
struct TabConfig { //>
    name: String,
} //<

#[derive(Debug, Deserialize, Serialize)]
struct HelpLine { //>
    text: String,
} //<

// Application state
struct App { //>
    // Configuration
    config: Config,
    
    // Left panel - Actions menu
    actions: Vec<ActionItem>,
    selected_action: usize,
    action_state: ListState,
    action_scrollbar: ScrollbarState,
    
    // Right panel - File tree
    file_changes: Vec<FileChange>,
    selected_file: usize,
    file_state: ListState,
    file_scrollbar: ScrollbarState,
    
    // File view state
    active_file_view: FileView,
    
    // System state
    should_quit: bool,
    last_check: Option<String>,
} //<

#[derive(Clone)]
enum FileView { //>
    Filtered,
    All,
} //<

#[derive(Clone)]
struct ActionItem { //>
    name: String,
    description: String,
    command: String,
    key: Option<char>,
} //<

#[derive(Clone)]
struct FileChange { //>
    path: String,
    change_type: ChangeType,
    timestamp: String,
    status: FileStatus,
} //<

#[derive(Clone)]
enum ChangeType { //>
    Modified,
    New,
} //<

#[derive(Clone)]
enum FileStatus { //>
    Tracked,
    Untracked,
    Modified,
} //<

impl App {
    fn new() -> App { //>
        let config_content = include_str!("../config.yaml");
        let config: Config = serde_yaml::from_str(config_content)
            .expect("Failed to parse config.yaml - check file format and location");
        
        // Build actions dynamically from config
        let actions = Self::build_actions_from_config(&config);
        
        let mut app = App {
            config,
            actions,
            
            selected_action: 0,
            action_state: ListState::default(),
            action_scrollbar: ScrollbarState::default(),
            file_changes: vec![],
            selected_file: 0,
            file_state: ListState::default(),
            file_scrollbar: ScrollbarState::default(),
            active_file_view: FileView::Filtered,
            should_quit: false,
            last_check: None,
        };
        
        app.action_state.select(Some(0));
        app.file_state.select(Some(0));
        app.load_file_changes();
        
        // Initialize scrollbar states
        app.action_scrollbar = app.action_scrollbar.content_length(app.actions.len());
        app.file_scrollbar = app.file_scrollbar.content_length(app.file_changes.len());
        
        app
    } //<
    
    fn build_actions_from_config(config: &Config) -> Vec<ActionItem> { //>
        config.commands_view.commands.iter().map(|command| {
            // let key = command.key.chars().next().map(|c| c.to_uppercase().next().unwrap_or(c));
            
            ActionItem {
                name: command.name.clone(),
                description: command.desc.clone(),
                command: command.command.clone(),
                key: command.key.chars().next(),
            }
        }).collect()
    } //<
    
    fn load_file_changes(&mut self) { //>
        // Load file changes from system-monitor
        self.file_changes = vec![
            FileChange {
                path: "/path/to/file.txt".to_string(),
                change_type: ChangeType::Modified,
                timestamp: "20241016 14:28:02".to_string(),
                status: FileStatus::Tracked,
            },
            FileChange {
                path: "/path/to/anotherfile.txt".to_string(),
                change_type: ChangeType::Modified,
                timestamp: "20241016 14:13:09".to_string(),
                status: FileStatus::Untracked,
            },
            FileChange {
                path: "/path/to/yetAnotherfile.txt".to_string(),
                change_type: ChangeType::New,
                timestamp: "20241016 14:05:15".to_string(),
                status: FileStatus::Modified,
            },
        ];
    } //<
    
    fn execute_action(&mut self) { //>
        if let Some(action) = self.actions.get(self.selected_action) {
            // Execute the command
            let output = Command::new("bash")
                .arg("-c")
                .arg(&action.command)
                .output();
                
            match output {
                Ok(result) => {
                    if result.status.success() {
                        self.last_check = Some(format!("✓ {} completed successfully", action.name));
                        // Reload file changes after successful action
                        self.load_file_changes();
                    } else {
                        self.last_check = Some(format!("✗ {} failed: {}", 
                            action.name, 
                            String::from_utf8_lossy(&result.stderr)
                        ));
                    }
                }
                Err(e) => {
                    self.last_check = Some(format!("✗ {} error: {}", action.name, e));
                }
            }
        }
    } //<
    
    fn track_selected_file(&mut self) { //>
        if let Some(file) = self.file_changes.get(self.selected_file) {
            let output = Command::new("bash")
                .arg("-c")
                .arg(&format!("system-track add '{}'", file.path))
                .output();
                
            match output {
                Ok(result) => {
                    if result.status.success() {
                        self.last_check = Some(format!("✓ Tracked file: {}", file.path));
                        self.load_file_changes(); // Refresh to update status
                    } else {
                        self.last_check = Some(format!("✗ Failed to track {}: {}", 
                            file.path, 
                            String::from_utf8_lossy(&result.stderr)
                        ));
                    }
                }
                Err(e) => {
                    self.last_check = Some(format!("✗ Error tracking {}: {}", file.path, e));
                }
            }
        }
    } //<
    
    fn remove_selected_file(&mut self) { //>
        if let Some(file) = self.file_changes.get(self.selected_file) {
            let output = Command::new("bash")
                .arg("-c")
                .arg(&format!("system-track remove '{}'", file.path))
                .output();
                
            match output {
                Ok(result) => {
                    if result.status.success() {
                        self.last_check = Some(format!("✓ Removed tracking for: {}", file.path));
                        self.load_file_changes(); // Refresh to update status
                    } else {
                        self.last_check = Some(format!("✗ Failed to remove {}: {}", 
                            file.path, 
                            String::from_utf8_lossy(&result.stderr)
                        ));
                    }
                }
                Err(e) => {
                    self.last_check = Some(format!("✗ Error removing {}: {}", file.path, e));
                }
            }
        }
    } //<
    
    fn show_diff_view(&mut self) { //>
        if let Some(file) = self.file_changes.get(self.selected_file) {
            // Use git diff if available, otherwise show file content
            let output = Command::new("bash")
                .arg("-c")
                .arg(&format!("git diff HEAD -- '{}' 2>/dev/null || echo 'No git diff available for {}'", file.path, file.path))
                .output();
                
            match output {
                Ok(result) => {
                    let diff_content = String::from_utf8_lossy(&result.stdout);
                    self.last_check = Some(format!("Diff for {}: {}", file.path, 
                        if diff_content.len() > 100 { 
                            format!("{}...", &diff_content[..100]) 
                        } else { 
                            diff_content.to_string() 
                        }
                    ));
                }
                Err(e) => {
                    self.last_check = Some(format!("✗ Error showing diff for {}: {}", file.path, e));
                }
            }
        }
    } //<
    
    fn refresh_file_changes(&mut self) { //>
        // Run system-monitor check to refresh file changes
        let output = Command::new("bash")
            .arg("-c")
            .arg("system-monitor check")
            .output();
            
        match output {
            Ok(result) => {
                if result.status.success() {
                    self.last_check = Some("✓ Refreshed file changes".to_string());
                    self.load_file_changes();
                } else {
                    self.last_check = Some(format!("✗ Failed to refresh: {}", 
                        String::from_utf8_lossy(&result.stderr)
                    ));
                }
            }
            Err(e) => {
                self.last_check = Some(format!("✗ Error refreshing: {}", e));
            }
        }
    } //<
    
    fn switch_file_view(&mut self) { //>
        self.active_file_view = match self.active_file_view {
            FileView::Filtered => FileView::All,
            FileView::All => FileView::Filtered,
        };
    } //<
    
    fn get_current_action_description(&self) -> String { //>
        if let Some(action) = self.actions.get(self.selected_action) {
            action.description.clone()
        } else {
            "No action selected".to_string()
        }
    } //<
}

fn main() -> Result<(), Box<dyn std::error::Error>> { //>
    // Setup terminal
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

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
} //<

fn run_app<B: Backend>(terminal: &mut Terminal<B>, app: &mut App) -> io::Result<()> { //>
    loop {
        terminal.draw(|f| ui(f, app))?;

        if crossterm::event::poll(Duration::from_millis(250))? {
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press {
                    match key.code {
                        KeyCode::Char('q') => {
                            app.should_quit = true;
                        }
                        KeyCode::Char('w') => {
                            app.switch_file_view();
                        }
                        KeyCode::Char('h') => {
                            // Show help - could be implemented later
                        }
                        KeyCode::Up => {
                            if app.selected_action > 0 {
                                app.selected_action -= 1;
                                app.action_state.select(Some(app.selected_action));
                            }
                        }
                        KeyCode::Down => {
                            if app.selected_action < app.actions.len() - 1 {
                                app.selected_action += 1;
                                app.action_state.select(Some(app.selected_action));
                            }
                        }
                        KeyCode::Right => {
                            if app.selected_file < app.file_changes.len() - 1 {
                                app.selected_file += 1;
                                app.file_state.select(Some(app.selected_file));
                                // Update scrollbar position
                                app.file_scrollbar = app.file_scrollbar.position(app.selected_file);
                            }
                        }
                        KeyCode::Left => {
                            if app.selected_file > 0 {
                                app.selected_file -= 1;
                                app.file_state.select(Some(app.selected_file));
                                // Update scrollbar position
                                app.file_scrollbar = app.file_scrollbar.position(app.selected_file);
                            }
                        }
                        KeyCode::Enter => {
                            app.execute_action();
                        }
                        KeyCode::Char('b') => {
                            app.refresh_file_changes();
                        }
                        KeyCode::Char('d') => {
                            app.show_diff_view();
                        }
                        KeyCode::Char('v') => {
                            app.show_diff_view();
                        }
                        KeyCode::Char('g') => {
                            // Generate report - could be implemented
                        }
                        KeyCode::Char('t') => {
                            app.track_selected_file();
                        }
                        KeyCode::Char('u') => {
                            app.remove_selected_file();
                        }
                        _ => {}
                    }
                }
            }
        }

        if app.should_quit {
            break;
        }
    }
    Ok(())
} //<

fn ui(f: &mut Frame, app: &mut App) { //>
    let area = f.area();
    
    //> Calculate the widest command text for positioning
    let max_command_width = app.actions.iter()
        .map(|action| action.name.len())
        .max()
        .unwrap_or(20);
    //<--------------------------------------------------------------------------
        
    //> Draw the outer border with thick box drawing characters
    let outer_block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Thick);
    
    f.render_widget(outer_block, area);
    
    //<--------------------------------------------------------------------------
    
    //> Create inner area (accounting for border)
    let inner_area = Rect {
        x: area.x + 1,
        y: area.y + 1,
        width: area.width - 2,
        height: area.height - 2,
    };
    
    //<--------------------------------------------------------------------------
    
    //> Header section text - centered title
    let title_text = &app.config.title_bar.display;
    let title = Paragraph::new(title_text.as_str())
        .alignment(Alignment::Center)
        .style(Style::default().fg(Color::White).add_modifier(Modifier::BOLD));
    f.render_widget(title, Rect {
        x: inner_area.x,
        y: inner_area.y,
        width: inner_area.width,
        height: 1,
    }); //<
    
    //> Title box bottom bar
    let title_bottom_area = Rect {
        x: inner_area.x,
        y: inner_area.y + 1,
        width: inner_area.width,
        height: 1,
    };
    let title_bottom = Paragraph::new("━".repeat(inner_area.width as usize))
        .style(Style::default().fg(Color::White));
    f.render_widget(title_bottom, title_bottom_area);
    
    //<--------------------------------------------------------------------------
    
    //> File list box
    
    let tab_start_x = inner_area.x + 1 + max_command_width as u16 + 10; // 10 spaces from command end
    let tab_width = inner_area.width - (tab_start_x - inner_area.x) - 1; // 1 space from right wall
        
    let file_box_top_area = Rect {
        x: tab_start_x,
        y: inner_area.y + 2, // After title + title bottom bar
        width: tab_width,
        height: 1,
    };
    
    let tab_width_usize = tab_width as usize;
    
    let middle_dash_count = tab_width_usize - 2;
    let middle_dashes = "─".repeat(middle_dash_count);
    let end_part = format!(" ─{}{}", middle_dashes, "┐");
    
    let top_border_spans = match app.active_file_view {
        FileView::Filtered => vec![
            Span::raw("┌─── "),
            Span::styled("Filtered", Style::default().fg(Color::White).add_modifier(Modifier::BOLD)),
            Span::styled(" ─ All", Style::default().fg(Color::DarkGray)),
            Span::raw(end_part.clone()),
        ],
        FileView::All => vec![
            Span::raw("┌─── "),
            Span::styled("Filtered", Style::default().fg(Color::DarkGray)),
            Span::styled(" ─ All", Style::default().fg(Color::White).add_modifier(Modifier::BOLD)),
            Span::raw(end_part),
        ],
    };
    
    let file_box_top = Paragraph::new(Line::from(top_border_spans));
    
    f.render_widget(file_box_top, file_box_top_area);
    
    //<--------------------------------------------------------------------------
    
    //> Commands area - left side, indented one space
    let commands_area = Rect {
        x: inner_area.x + 1, // One space indent
        y: inner_area.y + 3, // After title + title bottom bar + file box top
        width: (max_command_width + 1) as u16,
        height: inner_area.height - 7, // Leave space for bottom
    };
    
    draw_commands_list(f, commands_area, app, max_command_width);
    
    //<--------------------------------------------------------------------------
    
    //> File list box area - positioned according to specs (content area, not including borders)
    let file_box_area = Rect {
        x: tab_start_x,
        y: inner_area.y + 3, // Directly under the top border
        width: tab_width as u16,
        height: inner_area.height - 7, // -5 from bottom + 2 for bottom status
    };
    
    draw_file_view_area(f, file_box_area, app);
    
    //<--------------------------------------------------------------------------
    
    //> Draw left and right borders for empty lines in the file box
    draw_file_box_empty_borders(
        f, 
        tab_start_x, 
        inner_area.y + 3, 
        tab_width as u16, 
        file_box_area.height,
        app
    );
    
    //<--------------------------------------------------------------------------
    
    //> Bottom status area
    let status_area = Rect {
        x: inner_area.x,
        y: inner_area.y + inner_area.height - 4,
        width: inner_area.width,
        height: 4,
    };
    
    //<--------------------------------------------------------------------------
    
    draw_bottom_status(f, status_area, tab_start_x, tab_width as u16, app);
    
} //<

fn draw_commands_list(f: &mut Frame, area: Rect, app: &mut App, max_command_width: usize) { //>
    // Calculate viewport bounds
    let viewport_height = area.height as usize;
    let total_actions = app.actions.len();
    
    // Calculate which actions to show based on selected action and viewport
    let start_index = if app.selected_action >= viewport_height {
        app.selected_action - viewport_height + 1
    } else {
        0
    };
    let end_index = (start_index + viewport_height).min(total_actions);
    
    // Render visible actions only
    for (viewport_i, action_index) in (start_index..end_index).enumerate() {
        if let Some(action) = app.actions.get(action_index) {
            let command_text = action.name.clone();
            
            // Calculate padding to extend to scrollbar
            let scrollbar_x = area.x + (max_command_width + 8) as u16;
            let available_width = scrollbar_x - area.x;
            let padding_width = available_width.saturating_sub(command_text.len() as u16);
            let padding = " ".repeat(padding_width as usize);
            
            // Apply highlight style to entire line if this is the selected item
            let line_style = if action_index == app.selected_action {
                Style::default()
                    .fg(Color::White)
                    .bg(Color::DarkGray)
                    .add_modifier(Modifier::BOLD)
            } else {
                Style::default().fg(Color::White)
            };
            
            // Create the full line text
            let full_line = format!("{}{}", command_text, padding);
            
            // Render the line
            let line_paragraph = Paragraph::new(full_line)
                .style(line_style);
            
            f.render_widget(line_paragraph, Rect {
                x: area.x,
                y: area.y + viewport_i as u16,
                width: available_width - 1,
                height: 1,
            });
        }
    }

    
    
    // Show scrollbar for actions if there are more items than visible
    if total_actions > viewport_height {
        // Update scrollbar state with current viewport and position
        app.action_scrollbar = app.action_scrollbar.content_length(total_actions);
        app.action_scrollbar = app.action_scrollbar.viewport_content_length(viewport_height);
        app.action_scrollbar = app.action_scrollbar.position(app.selected_action);
        
        // Create separate scrollbar area positioned at max_command_width + 8
        let scrollbar_area = Rect {
            x: area.x + (max_command_width + 8) as u16,
            y: area.y,
            width: 1,
            height: area.height,
        };
        
        f.render_stateful_widget(
            Scrollbar::default()
                .orientation(ScrollbarOrientation::VerticalRight)
                .begin_symbol(Some("↑"))
                .end_symbol(Some("↓"))
                .track_symbol(Some("│"))
                .thumb_symbol("█"),
            scrollbar_area,
            &mut app.action_scrollbar,
        );
    }
} //<

fn draw_file_view_area(f: &mut Frame, area: Rect, app: &mut App) { //>
    // Create the file list content area (no borders since they're drawn separately)
    let file_list_area = Rect {
        x: area.x,
        y: area.y,
        width: area.width,
        height: area.height,
    };
    
    let file_items: Vec<ListItem> = app.file_changes
        .iter()
        .enumerate()
        .map(|(i, file)| {
            let path_style = if i == app.selected_file {
                Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD)
            } else {
                Style::default()
            };
            
            let change_text = match file.change_type {
                ChangeType::Modified => "MOD",
                ChangeType::New => "NEW",
            };
            
            let status_icon = match file.status {
                FileStatus::Tracked => "✓",
                FileStatus::Untracked => "!",
                FileStatus::Modified => "!",
            };
            
            // Format: [timestamp] CHANGE_STATUS /path
            let timestamp_text = format!("[{}]", file.timestamp);
            let change_text_owned = change_text.to_string();
            let status_icon_owned = status_icon.to_string();
            let path_owned = file.path.clone();
            
            ListItem::new(vec![
                Line::from(vec![
                    Span::raw("  "), // Two spaces before timestamp
                    Span::styled(timestamp_text, Style::default().fg(Color::White)),
                    Span::raw(" "),
                    Span::styled(change_text_owned, Style::default().fg(Color::Yellow)),
                    Span::raw(" "),
                    Span::styled(status_icon_owned, Style::default().fg(Color::Green)),
                    Span::raw(" "),
                    Span::styled(path_owned, path_style),
                ]),
            ])
        })
        .collect();

    // Create the file list without borders (they're drawn separately as top/bottom lines)
    let files_list = List::new(file_items);

    f.render_stateful_widget(files_list, file_list_area, &mut app.file_state);
    
    // Show scrollbar for files if there are more items than visible
    if app.file_changes.len() > file_list_area.height as usize {
        app.file_scrollbar = app.file_scrollbar.content_length(app.file_changes.len());
        app.file_scrollbar = app.file_scrollbar.viewport_content_length(file_list_area.height as usize);
        app.file_scrollbar = app.file_scrollbar.position(app.selected_file);
        
        f.render_stateful_widget(
            Scrollbar::default()
                .orientation(ScrollbarOrientation::VerticalRight)
                .begin_symbol(Some("↑"))
                .end_symbol(Some("↓")),
            file_list_area,
            &mut app.file_scrollbar,
        );
    }
} //<

fn draw_file_box_empty_borders(f: &mut Frame, start_x: u16, start_y: u16, width: u16, height: u16, _app: &mut App) { //>
    // Draw left and right borders for all lines in the file box
    for y in 0..height {
        // Left border
        let left_border = Paragraph::new("│");
        f.render_widget(left_border, Rect {
            x: start_x,
            y: start_y + y,
            width: 1,
            height: 1,
        });
        
        // Right border
        let right_border = Paragraph::new("│");
        f.render_widget(right_border, Rect {
            x: start_x + width - 1,
            y: start_y + y,
            width: 1,
            height: 1,
        });
    }
} //<

fn draw_bottom_status(f: &mut Frame, area: Rect, file_box_x: u16, file_box_width: u16, app: &mut App) { //>
    // Line 1: Bottom border of the file list box
    let bottom_border = format!("└{}┘", "─".repeat(file_box_width as usize - 2));
    let bottom_paragraph = Paragraph::new(bottom_border)
        .style(Style::default().fg(Color::White));
    f.render_widget(bottom_paragraph, Rect {
        x: file_box_x,
        y: area.y,
        width: file_box_width,
        height: 1,
    });
    
    // Line 2: Navigation hints
    let nav_text = " ↕ commands ←→ files [Q]uit [W]atch [H]elp [PgUp]/[PgDn]: Cycle between file views                                 ";
    let nav_paragraph = Paragraph::new(nav_text)
        .style(Style::default().fg(Color::DarkGray));
    f.render_widget(nav_paragraph, Rect {
        x: area.x,
        y: area.y + 1,
        width: area.width,
        height: 1,
    });
    
    // Line 3: Horizontal divider
    let divider_line = "─".repeat(area.width as usize);
    let divider_paragraph = Paragraph::new(divider_line)
        .style(Style::default().fg(Color::White));
    f.render_widget(divider_paragraph, Rect {
        x: area.x,
        y: area.y + 2,
        width: area.width,
        height: 1,
    });
    
    // Line 4: Dynamic description
    let description = app.get_current_action_description();
    let desc_line = format!(" {:<width$} ", description, width = area.width as usize - 2);
    let desc_paragraph = Paragraph::new(desc_line)
        .style(Style::default().fg(Color::White));
    f.render_widget(desc_paragraph, Rect {
        x: area.x,
        y: area.y + 3,
        width: area.width,
        height: 1,
    });
} //<