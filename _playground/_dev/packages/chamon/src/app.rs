use crate::config::Config;
use ratatui::widgets::{ListState, ScrollbarState};
use std::process::Command;
use serde_json::Value;

#[derive(Clone)]
pub struct FileView { //>
    pub name: String,
    pub index: usize,
} //<

#[derive(Clone)]
pub struct ActionItem { //>
    pub name: String,
    pub description: String,
    pub command: String,
    pub key: Option<char>,
} //<

#[derive(Clone)]
pub struct FileChange { //>
    pub path: String,
    pub change_type: ChangeType,
    pub timestamp: String,
    pub status: FileStatus,
} //<

#[derive(Clone)]
pub enum ChangeType { //>
    Modified,
    New,
} //<

#[derive(Clone)]
pub enum FileStatus { //>
    Tracked,
    Untracked,
    Modified,
} //<

pub struct App { //>
    // Configuration
    pub config: Config,
    
    // Left panel - Actions menu
    pub actions: Vec<ActionItem>,
    pub selected_action: usize,
    pub action_state: ListState,
    pub action_scrollbar: ScrollbarState,
    
    // Right panel - File tree
    pub file_changes: Vec<FileChange>,
    pub selected_file: usize,
    pub file_state: ListState,
    pub file_scrollbar: ScrollbarState,
    
    // File view state
    pub file_views: Vec<FileView>,
    pub active_file_view_index: usize,
    
    // System state
    pub should_quit: bool,
    pub last_check: Option<String>,
} //<

impl App {
    pub fn new() -> App { //>
        let config_content = include_str!("../config.yaml");
        let config: Config = serde_yaml::from_str(config_content)
            .expect("Failed to parse config.yaml - check file format and location");
        
        // Build actions and file views dynamically from config
        let actions = Self::build_actions_from_config(&config);
        let file_views = Self::build_file_views_from_config(&config);
        
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
            file_views,
            active_file_view_index: 0,
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
            ActionItem {
                name: command.name.clone(),
                description: command.desc.clone(),
                command: command.command.clone(),
                key: command.key.chars().next(),
            }
        }).collect()
    } //<

    fn build_file_views_from_config(config: &Config) -> Vec<FileView> { //>
        vec![
            FileView {
                name: config.files_view.tab1.name.clone(),
                index: 0,
            },
            FileView {
                name: config.files_view.tab2.name.clone(),
                index: 1,
            },
        ]
    } //<

    pub fn load_file_changes(&mut self) { //>
        // Load file changes from system-monitor using JSON output
        let output = Command::new("bash")
            .arg("-c")
            .arg("./system-monitor --json check 2>/dev/null || echo '[]'")
            .output();
        
        self.file_changes.clear();
        
        if let Ok(result) = output {
            if result.status.success() {
                let json_str = String::from_utf8_lossy(&result.stdout);
                
                if let Ok(json) = serde_json::from_str::<Value>(&json_str) {
                    if let Some(array) = json.as_array() {
                        for item in array {
                            if let (Some(type_str), Some(path), Some(timestamp), Some(status)) = (
                                item.get("type").and_then(|v| v.as_str()),
                                item.get("path").and_then(|v| v.as_str()),
                                item.get("timestamp").and_then(|v| v.as_str()),
                                item.get("status").and_then(|v| v.as_str()),
                            ) {
                                let change_type = match type_str {
                                    "MODIFIED" => ChangeType::Modified,
                                    "NEW" => ChangeType::New,
                                    _ => ChangeType::Modified,
                                };
                                
                                let file_status = match status {
                                    "tracked" => FileStatus::Tracked,
                                    "untracked" => FileStatus::Untracked,
                                    _ => FileStatus::Modified,
                                };
                                
                                self.file_changes.push(FileChange {
                                    path: path.to_string(),
                                    change_type,
                                    timestamp: timestamp.to_string(),
                                    status: file_status,
                                });
                            }
                        }
                    }
                }
            }
        }
        
        // Reset selected_file if it's out of bounds
        if !self.file_changes.is_empty() {
            self.selected_file = self.selected_file.min(self.file_changes.len() - 1);
            self.file_state.select(Some(self.selected_file));
        } else {
            self.selected_file = 0;
            self.file_state.select(None);
        }
    } //<
    
    pub fn execute_action(&mut self) { //>
        if let Some(action) = self.actions.get(self.selected_action) {
            // Execute the action based on its command
            match action.command.as_str() {
                "refresh" => {
                    self.refresh_file_changes();
                }
                "diff" => {
                    self.show_diff_view();
                }
                "view" => {
                    self.view_selected_file();
                }
                "track" => {
                    self.track_selected_file();
                }
                "untrack" => {
                    self.remove_selected_file();
                }
                "report" => {
                    // Generate report - could be implemented
                    self.last_check = Some("Generate report - not yet implemented".to_string());
                }
                _ => {
                    self.last_check = Some(format!("Unknown command: {}", action.command));
                }
            }
        }
    } //<
    
    pub fn track_selected_file(&mut self) { //>
        if self.file_changes.is_empty() {
            self.last_check = Some("No files to track".to_string());
            return;
        }
        
        if let Some(file) = self.file_changes.get(self.selected_file) {
            let output = Command::new("bash")
                .arg("-c")
                .arg(&format!("./system-tracker add '{}'", file.path))
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
    
    pub fn remove_selected_file(&mut self) { //>
        if self.file_changes.is_empty() {
            self.last_check = Some("No files to untrack".to_string());
            return;
        }
        
        if let Some(file) = self.file_changes.get(self.selected_file) {
            let output = Command::new("bash")
                .arg("-c")
                .arg(&format!("./system-tracker remove '{}'", file.path))
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
    
    pub fn show_diff_view(&mut self) { //>
        if self.file_changes.is_empty() {
            self.last_check = Some("No files to show diff for".to_string());
            return;
        }
        
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

    pub fn view_selected_file(&mut self) { //>
        if self.file_changes.is_empty() {
            self.last_check = Some("No files to view".to_string());
            return;
        }
        
        if let Some(file_change) = self.file_changes.get(self.selected_file) {
            // Use the default editor (usually $EDITOR or nano/vim)
            let editor = std::env::var("EDITOR").unwrap_or_else(|_| "nano".to_string());
            
            let output = Command::new("bash")
                .arg("-c")
                .arg(format!("{} {}", editor, file_change.path))
                .status();
                
            match output {
                Ok(status) => {
                    if status.success() {
                        self.last_check = Some(format!("✓ Opened {} in {}", file_change.path, editor));
                    } else {
                        self.last_check = Some(format!("✗ Failed to open {} in {}", file_change.path, editor));
                    }
                }
                Err(e) => {
                    self.last_check = Some(format!("✗ Error opening {}: {}", file_change.path, e));
                }
            }
        }
    } //<

    pub fn refresh_file_changes(&mut self) { //>
        // Refresh file changes (load_file_changes already calls system-monitor)
        self.load_file_changes();
        let count = self.file_changes.len();
        self.last_check = Some(format!("✓ Refreshed: {} changes found", count));
    } //<
    
    pub fn switch_file_view(&mut self) { //>
        self.active_file_view_index = (self.active_file_view_index + 1) % self.file_views.len();
    } //<
    
    pub fn switch_to_previous_file_view(&mut self) { //>
        if self.active_file_view_index > 0 {
            self.active_file_view_index -= 1;
        } else {
            self.active_file_view_index = self.file_views.len() - 1;
        }
    } //<
    
    pub fn switch_to_next_file_view(&mut self) { //>
        self.active_file_view_index = (self.active_file_view_index + 1) % self.file_views.len();
    } //<
    
    pub fn get_current_action_description(&self) -> String { //>
        if let Some(action) = self.actions.get(self.selected_action) {
            action.description.clone()
        } else {
            "No action selected".to_string()
        }
    } //<
    
    pub fn handle_config_key(&mut self, key: char) { //>
        // Find action by key binding
        if let Some(action_index) = self.actions.iter().position(|action| {
            action.key.map_or(false, |action_key| action_key.to_lowercase().next() == Some(key.to_lowercase().next().unwrap()))
        }) {
            // Execute the action based on its command
            let command = &self.actions[action_index].command;
            
            match command.as_str() {
                "refresh" => {
                    self.refresh_file_changes();
                }
                "diff" => {
                    self.show_diff_view();
                }
                "view" => {
                    self.view_selected_file();
                }
                "track" => {
                    self.track_selected_file();
                }
                "untrack" => {
                    self.remove_selected_file();
                }
                "report" => {
                    // Generate report - could be implemented
                    self.last_check = Some("Generate report - not yet implemented".to_string());
                }
                _ => {
                    self.last_check = Some(format!("Unknown command: {}", command));
                }
            }
        }
    } //<
}
