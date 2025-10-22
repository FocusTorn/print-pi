use crate::baseline::{Baseline, BaselineComparison, BaselineMetadata};
use crate::config::Config;
use ratatui::widgets::{ListState, ScrollbarState};
use std::path::PathBuf;
use std::process::Command;
use std::time::Instant;
use serde_json::Value;
use std::sync::mpsc;

// Message sent from background baseline generation task to UI
#[derive(Debug)]
pub enum BaselineMessage {
    InitialComplete { baseline: Baseline, path: String },
    DeltaComplete { baseline: Baseline },
    Error { message: String },
}

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
    pub select: Option<String>, // Select indicator (e.g., "►")
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

#[derive(Clone, PartialEq)]
pub enum ViewMode {
    Changes,
    Baseline,
}

#[derive(Clone, PartialEq)]
pub enum ActiveColumn {
    ViewSelector,  // Column 1: Changes/Baseline
    Commands,      // Column 2: Actions
    Content,       // Column 3: Files/Baselines
}

#[derive(Clone, PartialEq)]
pub enum PopupType {
    ConfirmDeleteBaseline { version: String, selected_option: usize }, // 0=Yes, 1=No
    ConfirmOverwriteInitial { selected_option: usize, from_remove: bool }, // from_remove: was triggered by trying to delete
    InputDirectory { prompt: String, input: String, cursor_pos: usize },
    InputRemapPath { prompt: String, input: String, cursor_pos: usize, scan_path: String }, // scan_path stored from first input
}

#[derive(Clone)]
pub struct Popup {
    pub popup_type: PopupType,
    pub visible: bool,
}

pub struct App { //>
    // Configuration
    pub config: Config,
    pub data_dir: PathBuf,
    
    // Column 1: View selector
    pub view_mode: ViewMode,
    pub selected_view: usize,
    pub view_state: ListState,
    
    // Column 2: Commands (contextual based on view_mode)
    pub changes_commands: Vec<ActionItem>,
    pub baseline_commands: Vec<ActionItem>,
    pub selected_command: usize,
    pub last_selected_command: usize, // Store for reverting after temp command
    pub command_state: ListState,
    
    // Right panel - File tree
    pub file_changes: Vec<FileChange>,
    pub selected_file: usize,
    pub file_state: ListState,
    pub file_scrollbar: ScrollbarState,
    
    // File view state
    pub file_views: Vec<FileView>,
    pub active_file_view_index: usize,
    
    // File panel toggles (track which are active)
    pub active_toggles: Vec<bool>, // true = on, false = off
    
    // Baseline state
    pub baseline_status: String,
    pub baseline_versions: Vec<BaselineMetadata>,
    pub baseline_comparison: Option<BaselineComparison>,
    pub creating_baseline: bool,
    pub creating_initial: bool,        // Flag: creating initial vs delta baseline
    pub baseline_create_start: Option<Instant>,
    pub baseline_create_frame: usize, // For throbber animation
    pub baseline_tx: mpsc::Sender<BaselineMessage>, // Channel to send to background threads
    pub baseline_rx: mpsc::Receiver<BaselineMessage>, // Background thread completion channel
    pub initial_baseline_path: Option<String>, // Physical path scanned for initial baseline
    pub initial_baseline_remap_to: Option<String>, // Logical path it remaps to
    pub initial_baseline_file_count: Option<usize>, // File count for initial baseline
    pub selected_baseline: usize,      // Which one is highlighted in the panel
    pub active_baseline: usize,        // Which one is used for comparisons (has arrow)
    pub baseline_list_state: ListState,
    
    // Column navigation
    pub active_column: ActiveColumn,
    
    // Popup state
    pub popup: Option<Popup>,
    
    // System state
    pub should_quit: bool,
    pub last_check: Option<String>,
} //<

impl App {
    pub fn new() -> App { //>
        let config_content = include_str!("../config.yaml");
        let config: Config = serde_yaml::from_str(config_content)
            .expect("Failed to parse config.yaml - check file format and location");
        
        // Build file views from config
        let file_views = Self::build_file_views_from_config(&config);
        
        // Build command lists from config
        let changes_commands = config.commands_view.changes_commands.iter().map(|cmd| {
            ActionItem {
                name: cmd.name.clone(),
                description: cmd.desc.clone(),
                command: cmd.command.clone(),
                key: cmd.key.chars().next(),
                select: cmd.select.clone(),
            }
        }).collect();
        
        let baseline_commands = config.commands_view.baseline_commands.iter().map(|cmd| {
            ActionItem {
                name: cmd.name.clone(),
                description: cmd.desc.clone(),
                command: cmd.command.clone(),
                key: cmd.key.chars().next(),
                select: cmd.select.clone(),
            }
        }).collect();
        
        // Determine data directory
        let data_dir = PathBuf::from("/home/pi/_playground/_dev/packages/chamon/data");
        
        // Load baseline versions if they exist
        let baseline_versions = Baseline::list_versions(&data_dir).unwrap_or_default();
        
        // Load initial baseline info (before moving data_dir)
        let (initial_baseline_path, initial_baseline_remap_to, initial_baseline_file_count) = Self::load_initial_baseline_info(&data_dir);
        
        // Set baseline status based on what's available
        let baseline_status = if baseline_versions.is_empty() {
            if let Some(path) = &initial_baseline_path {
                format!("Active: Initial ({})", path)
            } else {
                "No baselines found".to_string()
            }
        } else {
            // Default to first delta baseline
            format!("Active: {}", baseline_versions[0].version)
        };
        
        let mut baseline_list_state = ListState::default();
        baseline_list_state.select(Some(0));
        
        let mut view_state = ListState::default();
        view_state.select(Some(0));
        
        let mut command_state = ListState::default();
        command_state.select(Some(0));
        
        // Calculate toggle count before moving config
        let toggle_count = config.files_panel.toggles.len();
        
        // Create channel for background baseline generation
        let (baseline_tx, baseline_rx) = mpsc::channel();
        
        let mut app = App {
            config,
            data_dir,
            
            view_mode: ViewMode::Changes,
            selected_view: 0,
            view_state,
            
            changes_commands,
            baseline_commands,
            selected_command: 0,
            last_selected_command: 0,
            command_state,
            
            file_changes: vec![],
            selected_file: 0,
            file_state: ListState::default(),
            file_scrollbar: ScrollbarState::default(),
            
            file_views,
            active_file_view_index: 0,
            
            // Initialize toggles (all off by default)
            active_toggles: vec![false; toggle_count],
            
            baseline_status,
            baseline_versions,
            baseline_comparison: None,
            creating_baseline: false,
            creating_initial: false,
            baseline_create_start: None,
            baseline_create_frame: 0,
            baseline_tx,
            baseline_rx,
            initial_baseline_path,
            initial_baseline_remap_to,
            initial_baseline_file_count,
            selected_baseline: 0,
            active_baseline: 0,
            baseline_list_state,
            
            active_column: ActiveColumn::ViewSelector,
            
            popup: None,
            
            should_quit: false,
            last_check: None,
        };
        
        app.file_state.select(Some(0));
        app.load_file_changes();
        
        // Initialize scrollbar states
        app.file_scrollbar = app.file_scrollbar.content_length(app.file_changes.len());
        
        app
    } //<
    
    fn build_file_views_from_config(config: &Config) -> Vec<FileView> { //>
        config.files_panel.view_type.iter().enumerate().map(|(idx, view)| {
            FileView {
                name: view.name.clone(),
                index: idx,
            }
        }).collect()
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
    
    pub fn get_current_command_description(&self) -> String { //>
        let commands = self.get_current_commands();
        if let Some(action) = commands.get(self.selected_command) {
            action.description.clone()
        } else {
            "No command selected".to_string()
        }
    } //<
    
    // Column Navigation Methods ------------------------------------------>>
    
    pub fn move_left(&mut self) { //>
        self.active_column = match self.active_column {
            ActiveColumn::ViewSelector => ActiveColumn::ViewSelector, // Already leftmost
            ActiveColumn::Commands => {
                // Remember current selection when leaving Column 2
                self.last_selected_command = self.selected_command;
                ActiveColumn::ViewSelector
            }
            ActiveColumn::Content => ActiveColumn::Commands,
        };
    } //<
    
    pub fn move_right(&mut self) { //>
        self.active_column = match self.active_column {
            ActiveColumn::ViewSelector => ActiveColumn::Commands,
            ActiveColumn::Commands => {
                // Only move to content if command has a select indicator
                let current_commands = self.get_current_commands();
                if let Some(cmd) = current_commands.get(self.selected_command) {
                    if cmd.select.is_some() {
                        // Command has select indicator - move to Column 3
                        self.last_selected_command = self.selected_command;
                        ActiveColumn::Content
                    } else {
                        // No select indicator - stay on commands
                        ActiveColumn::Commands
                    }
                } else {
                    ActiveColumn::Commands
                }
            },
            ActiveColumn::Content => ActiveColumn::Content, // Already rightmost
        };
    } //<
    
    pub fn move_up(&mut self) { //>
        match self.active_column {
            ActiveColumn::ViewSelector => {
                if self.selected_view > 0 {
                    self.selected_view -= 1;
                    self.view_state.select(Some(self.selected_view));
                    // Switch view mode
                    self.view_mode = if self.selected_view == 0 {
                        ViewMode::Changes
                    } else {
                        ViewMode::Baseline
                    };
                    // Reset command selection when switching views
                    self.selected_command = 0;
                    self.last_selected_command = 0;
                    self.command_state.select(Some(0));
                }
            }
            ActiveColumn::Commands => {
                if self.selected_command > 0 {
                    self.selected_command -= 1;
                    self.command_state.select(Some(self.selected_command));
                    // Update last_selected_command when manually navigating
                    self.last_selected_command = self.selected_command;
                }
            }
            ActiveColumn::Content => {
                match self.view_mode {
                    ViewMode::Changes => {
                        if self.selected_file > 0 {
                            self.selected_file -= 1;
                            self.file_state.select(Some(self.selected_file));
                            self.file_scrollbar = self.file_scrollbar.position(self.selected_file);
                        }
                    }
                    ViewMode::Baseline => {
                        // Navigate through baselines
                        if self.selected_baseline > 0 {
                            self.selected_baseline -= 1;
                            self.baseline_list_state.select(Some(self.selected_baseline));
                        }
                    }
                }
            }
        }
    } //<
    
    pub fn move_down(&mut self) { //>
        match self.active_column {
            ActiveColumn::ViewSelector => {
                if self.selected_view < 1 {  // Only 2 views: Changes (0) and Baseline (1)
                    self.selected_view += 1;
                    self.view_state.select(Some(self.selected_view));
                    // Switch view mode
                    self.view_mode = if self.selected_view == 0 {
                        ViewMode::Changes
                    } else {
                        ViewMode::Baseline
                    };
                    // Reset command selection when switching views
                    self.selected_command = 0;
                    self.last_selected_command = 0;
                    self.command_state.select(Some(0));
                }
            }
            ActiveColumn::Commands => {
                let max_commands = self.get_current_commands().len();
                if self.selected_command < max_commands.saturating_sub(1) {
                    self.selected_command += 1;
                    self.command_state.select(Some(self.selected_command));
                    // Update last_selected_command when manually navigating
                    self.last_selected_command = self.selected_command;
                }
            }
            ActiveColumn::Content => {
                match self.view_mode {
                    ViewMode::Changes => {
                        if !self.file_changes.is_empty() && self.selected_file < self.file_changes.len() - 1 {
                            self.selected_file += 1;
                            self.file_state.select(Some(self.selected_file));
                            self.file_scrollbar = self.file_scrollbar.position(self.selected_file);
                        }
                    }
                    ViewMode::Baseline => {
                        // Navigate through baselines
                        // Total items = baseline_versions.len() + 1 (Initial at bottom)
                        let max_index = self.baseline_versions.len(); // Last index is Initial
                        if self.selected_baseline < max_index {
                            self.selected_baseline += 1;
                            self.baseline_list_state.select(Some(self.selected_baseline));
                        }
                    }
                }
            }
        }
    } //<
    
    pub fn get_current_commands(&self) -> &Vec<ActionItem> { //>
        match self.view_mode {
            ViewMode::Changes => &self.changes_commands,
            ViewMode::Baseline => &self.baseline_commands,
        }
    } //<
    
    pub fn execute_current_command(&mut self) { //>
        let commands = self.get_current_commands();
        if let Some(action) = commands.get(self.selected_command) {
            let command = action.command.clone();
            self.execute_command(&command);
        }
    } //<
    
    pub fn execute_command(&mut self, command: &str) { //>
        match command {
            // Changes view commands
            "diff" => self.show_diff_view(),
            "view" => self.view_selected_file(),
            "refresh" => self.refresh_file_changes(),
            "track" => self.track_selected_file(),
            "untrack" => self.remove_selected_file(),
            
            // Baseline view commands
            "baseline:generate" => self.create_baseline(),
            "baseline:activate" => {
                // Set selected baseline as active
                // Initial Baseline is at index = baseline_versions.len() (last index)
                let initial_index = self.baseline_versions.len();
                if self.selected_baseline == initial_index {
                    self.active_baseline = initial_index;
                    if let Some(path) = &self.initial_baseline_path {
                        self.last_check = Some(format!("✓ Active baseline set to: Initial ({})", path));
                        self.baseline_status = format!("Active: Initial ({})", path);
                    } else {
                        self.last_check = Some("Cannot activate: Initial baseline not created".to_string());
                    }
                } else {
                    // It's a delta baseline
                    self.active_baseline = self.selected_baseline;
                    if let Some(metadata) = self.baseline_versions.get(self.selected_baseline) {
                        self.last_check = Some(format!("✓ Active baseline set to: {}", metadata.version));
                        self.baseline_status = format!("Active: {}", metadata.version);
                    }
                }
            },
            "baseline:compare" => self.compare_baseline(),
            "baseline:initialize" => {
                // Show confirmation popup warning about deleting all delta baselines
                if self.baseline_versions.is_empty() {
                    // No deltas, just show input (pre-populate with current initial path if exists)
                    let default_input = self.initial_baseline_path.clone().unwrap_or_else(|| "/".to_string());
                    self.popup = Some(Popup {
                        popup_type: PopupType::InputDirectory {
                            prompt: "Enter directory path to scan:".to_string(),
                            input: default_input.clone(),
                            cursor_pos: default_input.len(),
                        },
                        visible: true,
                    });
                } else {
                    // Has deltas, warn first (from_remove: false = user clicked Overwrite)
                    self.popup = Some(Popup {
                        popup_type: PopupType::ConfirmOverwriteInitial {
                            selected_option: 1, // Default to No
                            from_remove: false,
                        },
                        visible: true,
                    });
                }
            },
            "baseline:remove" => {
                // Show confirmation popup
                // Initial Baseline is at index = baseline_versions.len() (last index)
                let initial_index = self.baseline_versions.len();
                if self.selected_baseline == initial_index {
                    // Cannot delete Initial Baseline - ask if they want to overwrite instead
                    self.popup = Some(Popup {
                        popup_type: PopupType::ConfirmOverwriteInitial {
                            selected_option: 1, // Default to No
                            from_remove: true, // User tried to delete it
                        },
                        visible: true,
                    });
                } else if let Some(metadata) = self.baseline_versions.get(self.selected_baseline) {
                    self.popup = Some(Popup {
                        popup_type: PopupType::ConfirmDeleteBaseline {
                            version: metadata.version.clone(),
                            selected_option: 1, // Default to "No"
                        },
                        visible: true,
                    });
                }
            },
            
                _ => {
                    self.last_check = Some(format!("Unknown command: {}", command));
            }
        }
    } //<
    
    //--------------------------------------------------------------------<<
    
    // Popup management methods ------------------------------------------->>
    
    pub fn popup_move_left(&mut self) { //>
        if let Some(popup) = &mut self.popup {
            match &mut popup.popup_type {
                PopupType::ConfirmDeleteBaseline { selected_option, .. } | 
                PopupType::ConfirmOverwriteInitial { selected_option, .. } => {
                    if *selected_option > 0 {
                        *selected_option -= 1;
                    }
                }
                PopupType::InputDirectory { cursor_pos, .. } | 
                PopupType::InputRemapPath { cursor_pos, .. } => {
                    if *cursor_pos > 0 {
                        *cursor_pos -= 1;
                    }
                }
            }
        }
    } //<
    
    pub fn popup_move_right(&mut self) { //>
        if let Some(popup) = &mut self.popup {
            match &mut popup.popup_type {
                PopupType::ConfirmDeleteBaseline { selected_option, .. } | 
                PopupType::ConfirmOverwriteInitial { selected_option, .. } => {
                    if *selected_option < 1 { // 0=Yes, 1=No
                        *selected_option += 1;
                    }
                }
                PopupType::InputDirectory { cursor_pos, input, .. } | 
                PopupType::InputRemapPath { cursor_pos, input, .. } => {
                    if *cursor_pos < input.len() {
                        *cursor_pos += 1;
                    }
                }
            }
        }
    } //<
    
    pub fn popup_input_char(&mut self, c: char) { //>
        if let Some(popup) = &mut self.popup {
            match &mut popup.popup_type {
                PopupType::InputDirectory { input, cursor_pos, .. } | 
                PopupType::InputRemapPath { input, cursor_pos, .. } => {
                    // Clamp cursor_pos to valid range
                    if *cursor_pos > input.len() {
                        *cursor_pos = input.len();
                    }
                    input.insert(*cursor_pos, c);
                    *cursor_pos += 1;
                }
                _ => {}
            }
        }
    } //<
    
    pub fn popup_backspace(&mut self) { //>
        if let Some(popup) = &mut self.popup {
            match &mut popup.popup_type {
                PopupType::InputDirectory { input, cursor_pos, .. } | 
                PopupType::InputRemapPath { input, cursor_pos, .. } => {
                    if *cursor_pos > 0 && !input.is_empty() && *cursor_pos <= input.len() {
                        input.remove(*cursor_pos - 1);
                        *cursor_pos -= 1;
                    }
                }
                _ => {}
            }
        }
    } //<
    
    pub fn popup_confirm(&mut self) { //>
        if let Some(popup) = self.popup.take() {
            match popup.popup_type {
                PopupType::ConfirmDeleteBaseline { version, selected_option } => {
                    if selected_option == 0 { // Yes was selected
                        self.delete_baseline(&version);
                    } else {
                        self.last_check = Some("Delete cancelled".to_string());
                    }
                }
                PopupType::ConfirmOverwriteInitial { selected_option, .. } => {
                    if selected_option == 0 { // Yes was selected
                        // Delete all delta baselines first
                        let baselines_dir = self.data_dir.join("baselines");
                        for metadata in &self.baseline_versions {
                            let baseline_path = baselines_dir.join(format!("baseline-{}.json", metadata.version));
                            let _ = std::fs::remove_file(baseline_path);
                        }
                        // Reload to clear the list
                        self.baseline_versions = Baseline::list_versions(&self.data_dir).unwrap_or_default();
                        
                        // Show input dialog for path (pre-populate with current initial path)
                        let default_input = self.initial_baseline_path.clone().unwrap_or_else(|| "/".to_string());
                        self.popup = Some(Popup {
                            popup_type: PopupType::InputDirectory {
                                prompt: "Enter directory path to scan:".to_string(),
                                input: default_input.clone(),
                                cursor_pos: default_input.len(),
                            },
                            visible: true,
                        });
                        return; // Don't revert command selection yet
                    } else {
                        self.last_check = Some("Overwrite cancelled".to_string());
                    }
                }
                PopupType::InputDirectory { input, .. } => {
                    // After getting scan path, show popup for remap_to path
                    let scan_path = input.clone();
                    let default_remap = scan_path.clone();
                    self.popup = Some(Popup {
                        popup_type: PopupType::InputRemapPath {
                            prompt: "Enter remap path (or leave as-is):".to_string(),
                            input: default_remap.clone(),
                            cursor_pos: default_remap.len(),
                            scan_path,
                        },
                        visible: true,
                    });
                    return; // Don't close popup yet, wait for remap path
                }
                PopupType::InputRemapPath { scan_path, input: remap_to, .. } => {
                    // Now we have both paths, create the baseline
                    self.create_initial_baseline_with_remap(&scan_path, &remap_to);
                }
            }
        }
        // Revert to last selected command after popup closes
        self.selected_command = self.last_selected_command;
        self.command_state.select(Some(self.last_selected_command));
    } //<
    
    pub fn popup_cancel(&mut self) { //>
        self.popup = None;
        self.last_check = Some("Cancelled".to_string());
        // Revert to last selected command after cancelling
        self.selected_command = self.last_selected_command;
        self.command_state.select(Some(self.last_selected_command));
    } //<
    
    fn load_initial_baseline_info(data_dir: &PathBuf) -> (Option<String>, Option<String>, Option<usize>) { //>
        // Check if initial-baseline.json exists and load the scan_path, remap_to, and file_count
        let initial_path = data_dir.join("baselines").join("baseline-initial.json");
        if let Ok(content) = std::fs::read_to_string(&initial_path) {
            if let Ok(json) = serde_json::from_str::<serde_json::Value>(&content) {
                let scan_path = json.get("scan_path").and_then(|v| v.as_str()).map(|s| s.to_string());
                let remap_to = json.get("remap_to").and_then(|v| v.as_str()).map(|s| s.to_string());
                let file_count = json.get("file_count").and_then(|v| v.as_u64()).map(|n| n as usize);
                return (scan_path, remap_to, file_count);
            }
        }
        (None, None, None)
    } //<
    
    fn create_initial_baseline_with_remap(&mut self, scan_path: &str, remap_to: &str) { //>
        self.creating_baseline = true;
        self.creating_initial = true;
        self.baseline_create_start = Some(Instant::now());
        self.initial_baseline_path = Some(scan_path.to_string());
        self.initial_baseline_remap_to = Some(remap_to.to_string());
        
        if scan_path == remap_to {
            self.last_check = Some(format!("Creating initial baseline from: {}", scan_path));
        } else {
            self.last_check = Some(format!("Creating initial baseline: {} → {}", scan_path, remap_to));
        }
    } //<
    
    fn delete_baseline(&mut self, version: &str) { //>
        // Delete the baseline file
        let baseline_path = self.data_dir.join("baselines").join(format!("baseline-{}.json", version));
        match std::fs::remove_file(&baseline_path) {
            Ok(_) => {
                self.last_check = Some(format!("✓ Deleted baseline: {}", version));
                // Reload baseline list
                self.baseline_versions = Baseline::list_versions(&self.data_dir).unwrap_or_default();
                
                // If all delta baselines are deleted, revert to Initial Baseline
                if self.baseline_versions.is_empty() {
                    // Initial is now at index 0 (only item)
                    let initial_index = 0;
                    self.active_baseline = initial_index;
                    if let Some(path) = &self.initial_baseline_path {
                        self.baseline_status = format!("Active: Initial ({})", path);
                    } else {
                        self.baseline_status = "Active: Initial (not created)".to_string();
                    }
                    self.selected_baseline = 0;
                    self.baseline_list_state.select(Some(0));
                } else {
                    // Reset selection if needed (Initial is at index baseline_versions.len())
                    let max_index = self.baseline_versions.len(); // Initial is at this index
                    if self.selected_baseline > max_index {
                        self.selected_baseline = max_index - 1;
                        self.baseline_list_state.select(Some(self.selected_baseline));
                    }
                    // Reset active baseline if it was deleted
                    if self.active_baseline >= self.baseline_versions.len() && self.active_baseline != max_index {
                        self.active_baseline = 0;
                        if let Some(metadata) = self.baseline_versions.get(0) {
                            self.baseline_status = format!("Active: {}", metadata.version);
                        }
                    }
                }
            }
            Err(e) => {
                self.last_check = Some(format!("✗ Failed to delete: {}", e));
            }
        }
    } //<
    
    //--------------------------------------------------------------------<<
    
    // Baseline management methods ---------------------------------------->>
    
    pub fn create_baseline(&mut self) { //>
        // FAKE IMPLEMENTATION FOR UI TESTING (2 second delay to show throbber)
        // TODO: Replace with real async baseline generation
        
        self.creating_baseline = true;
        self.creating_initial = false; // This is a delta baseline
        self.baseline_create_start = Some(Instant::now());
        self.last_check = Some("Creating baseline...".to_string());
    } //<
    
    pub fn check_baseline_creation(&mut self) { //>
        // Update animation frame while creating
        if self.creating_baseline {
            self.baseline_create_frame = (self.baseline_create_frame + 1) % 60;
        }
        
        // Check if baseline creation should start (spawn async task)
        if let Some(_start) = self.baseline_create_start {
            self.spawn_baseline_task();
            self.baseline_create_start = None; // Don't spawn again
        }
        
        // Check for completion messages from async task
        if let Ok(msg) = self.baseline_rx.try_recv() {
            self.handle_baseline_completion(msg);
        }
    } //<
    
    fn spawn_baseline_task(&mut self) { //>
        let data_dir = self.data_dir.clone();
        let config = self.config.baseline.clone();
        let tx = self.baseline_tx.clone();
        let is_initial = self.creating_initial;
        let scan_path = self.initial_baseline_path.clone();
        let remap_to = self.initial_baseline_remap_to.clone();
        
        // Spawn background thread
        std::thread::spawn(move || {
            let result = if is_initial {
                let scan_path_str = scan_path.as_deref().unwrap_or("/");
                let remap_to_str = remap_to.as_deref().unwrap_or(scan_path_str);
                
                match Baseline::create(scan_path_str, remap_to_str, &config) {
                    Ok(baseline) => {
                        BaselineMessage::InitialComplete {
                            baseline,
                            path: scan_path_str.to_string(),
                        }
                    }
                    Err(e) => BaselineMessage::Error {
                        message: format!("Failed to create initial baseline: {}", e),
                    },
                }
            } else {
                match Baseline::create_delta(&data_dir, &config) {
                    Ok(baseline) => BaselineMessage::DeltaComplete { baseline },
                    Err(e) => BaselineMessage::Error {
                        message: format!("Failed to create delta baseline: {}", e),
                    },
                }
            };
            
            let _ = tx.send(result);
        });
    } //<
    
    fn handle_baseline_completion(&mut self, msg: BaselineMessage) { //>
        match msg {
            BaselineMessage::InitialComplete { baseline, path } => {
                match baseline.save(&self.data_dir, true) {
                    Ok(_) => {
                        let file_count = baseline.file_count;
                        self.last_check = Some(format!("✓ Initial baseline created: {} ({} files)", path, file_count));
                        
                        // Store the metadata
                        self.initial_baseline_remap_to = Some(baseline.remap_to.clone());
                        self.initial_baseline_file_count = Some(file_count);
                        
                        // Reload baseline list
                        self.baseline_versions = Baseline::list_versions(&self.data_dir).unwrap_or_default();
                        
                        // Set initial baseline as active
                        let initial_index = self.baseline_versions.len();
                        self.active_baseline = initial_index;
                        self.baseline_status = format!("Active: Initial ({})", path);
                        
                        // Move selection to Initial
                        self.selected_baseline = initial_index;
                        self.baseline_list_state.select(Some(initial_index));
                    }
                    Err(e) => {
                        self.last_check = Some(format!("✗ Failed to save initial baseline: {}", e));
                    }
                }
            }
            BaselineMessage::DeltaComplete { baseline } => {
                match baseline.save(&self.data_dir, false) {
                    Ok(_) => {
                        let file_count = baseline.file_count;
                        let version = baseline.version.clone();
                        
                        self.baseline_status = format!("Latest: {} ({} changes)", version, file_count);
                        self.baseline_versions = Baseline::list_versions(&self.data_dir).unwrap_or_default();
                        self.last_check = Some(format!("✓ Baseline created: {} changes", file_count));
                    }
                    Err(e) => {
                        self.last_check = Some(format!("✗ Failed to save baseline: {}", e));
                    }
                }
            }
            BaselineMessage::Error { message } => {
                self.last_check = Some(format!("✗ {}", message));
            }
        }
        
        self.creating_baseline = false;
        self.creating_initial = false;
        self.baseline_create_frame = 0;
    } //<
    
    pub fn get_throbber(&self) -> &'static str { //>
        // BRAILLE SPINNERS (Smooth, minimal space):
        
        // OPTION 1: Braille dots - Classic smooth rotation
        // const SPINNER_BRAILLE_1: &[&str] = &["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
        
        // OPTION 2: Braille dots - Different pattern (vertical pulse)
        // const SPINNER_BRAILLE_2: &[&str] = &["⠁", "⠂", "⠄", "⡀", "⢀", "⠠", "⠐", "⠈"];
        
        // OPTION 3: Braille dots - Box rotation
        // const SPINNER_BRAILLE_3: &[&str] = &["⠈", "⠐", "⠠", "⢀", "⡀", "⠄", "⠂", "⠁"];
        
        // OPTION 4: Braille dots - Bounce effect
        // const SPINNER_BRAILLE_4: &[&str] = &["⠁", "⠉", "⠙", "⠚", "⠒", "⠂", "⠂", "⠒", "⠲", "⠴", "⠤", "⠄", "⠄", "⠤", "⠴", "⠲", "⠒", "⠂"];
        
        // OPTION 5: Braille dots - Snake
        // const SPINNER_BRAILLE_5: &[&str] = &["⠁", "⠁", "⠉", "⠙", "⠚", "⠒", "⠂", "⠂", "⠒", "⠲", "⠴", "⠤", "⠄", "⠄", "⠤", "⠠", "⠠", "⠤", "⠦", "⠖", "⠒", "⠐", "⠐", "⠒", "⠓", "⠋", "⠉", "⠈", "⠈"];
        
        // OPTION 6: Braille dots - Circular (simplest)
        // const SPINNER_BRAILLE_6: &[&str] = &["⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"];
        
        // OPTION 7: Braille dots - Growing circle
        const SPINNER_BRAILLE_7: &[&str] = &["⣾", "⣷", "⣯", "⣟", "⡿", "⢿", "⣻", "⣽"];
        
        // OTHER STYLES:
        // const SPINNER_ARROWS: &[&str] = &["←", "↖", "↑", "↗", "→", "↘", "↓", "↙"];
        // const SPINNER_BOX: &[&str] = &["┤", "┘", "┴", "└", "├", "┌", "┬", "┐"];
        // const SPINNER_MOON: &[&str] = &["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"];
        // const SPINNER_LINE: &[&str] = &["-", "\\", "|", "/"];
        // const SPINNER_BALL: &[&str] = &["◐", "◓", "◑", "◒"];
        // const SPINNER_BARS: &[&str] = &["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█", "▇", "▆", "▅", "▄", "▃", "▂"];
        
        let frame = self.baseline_create_frame % SPINNER_BRAILLE_7.len(); // Full speed!
        SPINNER_BRAILLE_7[frame]
    } //<
    
    pub fn compare_baseline(&mut self) { //>
        self.last_check = Some("Comparing with active baseline...".to_string());
        
        // Check if active baseline is the initial baseline
        let initial_index = self.baseline_versions.len();
        let baseline_result = if self.active_baseline == initial_index {
            // Load initial baseline
            Baseline::load_initial(&self.data_dir)
        } else {
            // Load delta baseline
            if let Some(metadata) = self.baseline_versions.get(self.active_baseline) {
                Baseline::load(&self.data_dir, &metadata.version)
            } else {
                Err(std::io::Error::new(std::io::ErrorKind::NotFound, "Baseline not found"))
            }
        };
        
        match baseline_result {
            Ok(baseline) => {
                let version_name = if self.active_baseline == initial_index {
                    "Initial"
                } else {
                    self.baseline_versions.get(self.active_baseline).map(|m| m.version.as_str()).unwrap_or("unknown")
                };
                
                match baseline.compare(&self.config.baseline, &self.data_dir) {
                    Ok(comparison) => {
                        let _total_changes = comparison.changed.len() + comparison.new.len() + comparison.deleted.len();
                        self.last_check = Some(format!(
                            "✓ Compared with {}: {} changed, {} new, {} deleted",
                            version_name,
                            comparison.changed.len(),
                            comparison.new.len(),
                            comparison.deleted.len()
                        ));
                        self.baseline_comparison = Some(comparison);
                    }
                    Err(e) => {
                        self.last_check = Some(format!("✗ Failed to compare: {}", e));
                    }
                }
            }
            Err(e) => {
                self.last_check = Some(format!("✗ No baseline found: {}", e));
            }
        }
    } //<
    
    pub fn list_baselines(&mut self) { //>
        match Baseline::list_versions(&self.data_dir) {
            Ok(versions) => {
                self.baseline_versions = versions.clone();
                if versions.is_empty() {
                    self.baseline_status = "No baselines found".to_string();
                    self.last_check = Some("✗ No baselines available".to_string());
                } else {
                    self.baseline_status = format!("{} baseline(s) available", versions.len());
                    self.last_check = Some(format!("✓ Found {} baseline(s)", versions.len()));
                }
            }
            Err(e) => {
                self.last_check = Some(format!("✗ Failed to list baselines: {}", e));
            }
        }
    } //<
    
    //--------------------------------------------------------------------<<
}
