// Application state management

use ratatui::widgets::ListState;
use crate::config::DetourConfig;
use crate::manager::DetourManager;
use crate::popup::Popup;
use crate::diff::DiffViewer;

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ActiveColumn {
    Views,
    Actions,
    Content,
}

#[derive(Debug, Clone, PartialEq)]
pub enum ViewMode {
    DetoursList,
    DetoursAdd,
    IncludesList,
    ServicesList,
    StatusOverview,
    LogsLive,
    ConfigEdit,
}

#[derive(Debug, Clone)]
pub struct Detour {
    pub original: String,
    pub custom: String,
    pub active: bool,
    pub size: u64,
    pub modified: String,
}

impl Detour {
    pub fn modified_ago(&self) -> String {
        // TODO: Calculate actual time ago
        self.modified.clone()
    }
    
    pub fn size_display(&self) -> String {
        if self.size > 1024 * 1024 {
            format!("{:.1} MB", self.size as f64 / 1024.0 / 1024.0)
        } else if self.size > 1024 {
            format!("{:.1} KB", self.size as f64 / 1024.0)
        } else {
            format!("{} B", self.size)
        }
    }
    
    pub fn status_text(&self) -> String {
        if self.active {
            "✓ Active".to_string()
        } else {
            "○ Inactive".to_string()
        }
    }
}

pub struct App {
    pub should_quit: bool,
    pub active_column: ActiveColumn,
    pub view_mode: ViewMode,
    
    // Navigation state
    pub selected_view: usize,
    pub selected_action: usize,
    pub selected_detour: usize,
    pub selected_include: usize,
    pub selected_service: usize,
    
    // List states for rendering
    pub view_state: ListState,
    pub action_state: ListState,
    pub detour_state: ListState,
    pub include_state: ListState,
    pub service_state: ListState,
    
    // Data
    pub views: Vec<String>,
    pub detours: Vec<Detour>,
    pub includes: Vec<Include>,
    pub services: Vec<Service>,
    pub logs: Vec<LogEntry>,
    pub profile: String,
    pub status_message: Option<String>,
    pub error_message: Option<String>,
    pub popup: Option<Popup>,
    pub diff_viewer: Option<DiffViewer>,
    
    // Managers
    pub detour_manager: DetourManager,
    pub config_path: String,
}

#[derive(Debug, Clone)]
pub struct Include {
    pub target: String,
    pub include_file: String,
    pub active: bool,
}

#[derive(Debug, Clone)]
pub struct Service {
    pub name: String,
    pub action: String,
    pub status: String,
}

#[derive(Debug, Clone)]
pub struct LogEntry {
    pub timestamp: String,
    pub level: String,
    pub message: String,
}

impl App {
    pub fn new() -> Self {
        let mut view_state = ListState::default();
        view_state.select(Some(0));
        
        let mut action_state = ListState::default();
        action_state.select(Some(0));
        
        let mut detour_state = ListState::default();
        detour_state.select(Some(0));
        
        let mut include_state = ListState::default();
        include_state.select(Some(0));
        
        let mut service_state = ListState::default();
        service_state.select(Some(0));
        
        // Initialize detour manager
        let detour_manager = DetourManager::new();
        
        // Get config path
        let config_path = DetourConfig::get_config_path();
        
        // Load config if it exists
        let (detours, includes, services) = if let Ok(config) = DetourConfig::parse(&config_path) {
            // Convert config entries to app structs
            let detours = config.detours.iter().map(|entry| {
                let file_info = detour_manager.get_file_info(&entry.custom);
                let is_active = detour_manager.is_active(&entry.original);
                
                Detour {
                    original: entry.original.clone(),
                    custom: entry.custom.clone(),
                    active: is_active,
                    size: file_info.as_ref().map(|f| f.size).unwrap_or(0),
                    modified: Self::time_ago(file_info.as_ref().map(|f| f.modified_secs).unwrap_or(0)),
                }
            }).collect();
            
            let includes = config.includes.iter().map(|entry| Include {
                target: entry.target.clone(),
                include_file: entry.include_file.clone(),
                active: entry.enabled,
            }).collect();
            
            let services = config.services.iter().map(|entry| Service {
                name: entry.name.clone(),
                action: entry.action.clone(),
                status: "Unknown".to_string(),
            }).collect();
            
            (detours, includes, services)
        } else {
            // Use demo data if no config
            (
                vec![
                    Detour {
                        original: "/etc/nginx/nginx.conf".to_string(),
                        custom: "/home/pi/_playground/nginx/nginx.conf".to_string(),
                        active: false,
                        size: 12800,
                        modified: "2h ago".to_string(),
                    },
                ],
                vec![],
                vec![],
            )
        };
        
        Self {
            should_quit: false,
            active_column: ActiveColumn::Views,
            view_mode: ViewMode::DetoursList,
            
            selected_view: 0,
            selected_action: 0,
            selected_detour: 0,
            selected_include: 0,
            selected_service: 0,
            
            view_state,
            action_state,
            detour_state,
            include_state,
            service_state,
            
            views: vec![
                "Detours".to_string(),
                "Includes".to_string(),
                "Services".to_string(),
                "Status".to_string(),
                "Logs".to_string(),
                "Config".to_string(),
            ],
            
            detours,
            includes,
            services,
            logs: vec![],
            profile: "default".to_string(),
            status_message: None,
            error_message: None,
            popup: None,
            diff_viewer: None,
            
            detour_manager,
            config_path,
        }
    }
    
    pub fn show_diff(&mut self, original: &str, custom: &str) {
        match DiffViewer::new(original.to_string(), custom.to_string()) {
            Ok(diff) => {
                self.diff_viewer = Some(diff);
            }
            Err(e) => {
                self.show_error("Diff Error", e);
            }
        }
    }
    
    pub fn close_diff(&mut self) {
        self.diff_viewer = None;
    }
    
    pub fn scroll_diff_up(&mut self) {
        if let Some(diff) = &mut self.diff_viewer {
            diff.scroll_up();
        }
    }
    
    pub fn scroll_diff_down(&mut self) {
        if let Some(diff) = &mut self.diff_viewer {
            diff.scroll_down(20); // Approximate visible lines
        }
    }
    
    pub fn scroll_diff_page_up(&mut self) {
        if let Some(diff) = &mut self.diff_viewer {
            diff.scroll_page_up(20);
        }
    }
    
    pub fn scroll_diff_page_down(&mut self) {
        if let Some(diff) = &mut self.diff_viewer {
            diff.scroll_page_down(20, 20);
        }
    }
    
    pub fn show_confirm(&mut self, title: impl Into<String>, message: impl Into<String>) {
        self.popup = Some(Popup::confirm(title, message));
    }
    
    pub fn show_input(&mut self, title: impl Into<String>, prompt: impl Into<String>) {
        self.popup = Some(Popup::input(title, prompt));
    }
    
    pub fn show_error(&mut self, title: impl Into<String>, message: impl Into<String>) {
        let message_str: String = message.into();
        self.popup = Some(Popup::error(title, message_str.clone()));
        self.add_log("ERROR", &message_str);
    }
    
    pub fn show_info(&mut self, title: impl Into<String>, message: impl Into<String>) {
        self.popup = Some(Popup::info(title, message));
    }
    
    pub fn close_popup(&mut self) {
        self.popup = None;
    }
    
    pub fn handle_popup_input(&mut self, c: char) {
        if let Some(popup) = &mut self.popup {
            popup.handle_char(c);
        }
    }
    
    pub fn handle_popup_backspace(&mut self) {
        if let Some(popup) = &mut self.popup {
            popup.handle_backspace();
        }
    }
    
    pub fn handle_popup_left(&mut self) {
        if let Some(popup) = &mut self.popup {
            popup.handle_left();
        }
    }
    
    pub fn handle_popup_right(&mut self) {
        if let Some(popup) = &mut self.popup {
            popup.handle_right();
        }
    }
    
    fn time_ago(secs: u64) -> String {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        
        let diff = now.saturating_sub(secs);
        
        if diff < 60 {
            format!("{}s ago", diff)
        } else if diff < 3600 {
            format!("{}m ago", diff / 60)
        } else if diff < 86400 {
            format!("{}h ago", diff / 3600)
        } else {
            format!("{}d ago", diff / 86400)
        }
    }
    
    pub fn reload_config(&mut self) {
        if let Ok(config) = DetourConfig::parse(&self.config_path) {
            // Reload detours
            self.detours = config.detours.iter().map(|entry| {
                let file_info = self.detour_manager.get_file_info(&entry.custom);
                let is_active = self.detour_manager.is_active(&entry.original);
                
                Detour {
                    original: entry.original.clone(),
                    custom: entry.custom.clone(),
                    active: is_active,
                    size: file_info.as_ref().map(|f| f.size).unwrap_or(0),
                    modified: Self::time_ago(file_info.as_ref().map(|f| f.modified_secs).unwrap_or(0)),
                }
            }).collect();
            
            // Reload includes
            self.includes = config.includes.iter().map(|entry| Include {
                target: entry.target.clone(),
                include_file: entry.include_file.clone(),
                active: entry.enabled,
            }).collect();
            
            // Reload services
            self.services = config.services.iter().map(|entry| Service {
                name: entry.name.clone(),
                action: entry.action.clone(),
                status: "Unknown".to_string(),
            }).collect();
            
            self.status_message = Some("Config reloaded".to_string());
        } else {
            self.error_message = Some("Failed to reload config".to_string());
        }
    }
    
    pub fn apply_all_detours(&mut self) {
        match self.detour_manager.apply_all() {
            Ok(_) => {
                self.status_message = Some("Detours applied successfully".to_string());
                self.reload_config();
            }
            Err(e) => {
                self.error_message = Some(format!("Failed to apply detours: {}", e));
            }
        }
    }
    
    pub fn remove_all_detours(&mut self) {
        match self.detour_manager.remove_all() {
            Ok(_) => {
                self.status_message = Some("Detours removed successfully".to_string());
                self.reload_config();
            }
            Err(e) => {
                self.error_message = Some(format!("Failed to remove detours: {}", e));
            }
        }
    }
    
    pub fn add_log(&mut self, level: &str, message: &str) {
        let timestamp = chrono::Local::now().format("%H:%M:%S").to_string();
        self.logs.push(LogEntry {
            timestamp,
            level: level.to_string(),
            message: message.to_string(),
        });
        
        // Keep only last 1000 logs
        if self.logs.len() > 1000 {
            self.logs.remove(0);
        }
    }
    
    pub fn get_current_actions(&self) -> Vec<String> {
        match self.view_mode {
            ViewMode::DetoursList | ViewMode::DetoursAdd => vec![
                "List".to_string(),
                "Add".to_string(),
                "Edit".to_string(),
                "Toggle".to_string(),
                "Validate".to_string(),
                "Remove".to_string(),
                "Backup".to_string(),
                "Restore".to_string(),
            ],
            ViewMode::IncludesList => vec![
                "List".to_string(),
                "Add Include".to_string(),
                "Remove".to_string(),
                "Test Injection".to_string(),
            ],
            ViewMode::ServicesList => vec![
                "List".to_string(),
                "Start".to_string(),
                "Stop".to_string(),
                "Restart".to_string(),
                "Status".to_string(),
            ],
            ViewMode::StatusOverview => vec![
                "Overview".to_string(),
                "Health Check".to_string(),
                "Refresh".to_string(),
            ],
            ViewMode::LogsLive => vec![
                "Live View".to_string(),
                "Filter".to_string(),
                "Search".to_string(),
                "Export".to_string(),
                "Clear".to_string(),
            ],
            ViewMode::ConfigEdit => vec![
                "Edit".to_string(),
                "Validate".to_string(),
                "Reload".to_string(),
                "Export".to_string(),
            ],
        }
    }
    
    pub fn active_detours_count(&self) -> usize {
        self.detours.iter().filter(|d| d.active).count()
    }
    
    pub fn status_icon(&self) -> &str {
        if self.detours.iter().all(|d| d.active) {
            "✓ All synced"
        } else {
            "⚠ Some inactive"
        }
    }
    
    pub fn get_current_description(&self) -> String {
        match (&self.view_mode, self.active_column) {
            (ViewMode::DetoursList, ActiveColumn::Content) => {
                "Navigate detours, press [Enter] for details, [Space] to toggle active/inactive".to_string()
            }
            (ViewMode::DetoursList, _) => {
                "View and manage file detours - redirect reads without modifying originals".to_string()
            }
            (ViewMode::DetoursAdd, _) => {
                "Add a new detour - specify original and custom file paths".to_string()
            }
            _ => "Navigate with arrow keys, press [?] for help".to_string(),
        }
    }
    
    pub fn navigate_up(&mut self) {
        match self.active_column {
            ActiveColumn::Views => {
                if self.selected_view > 0 {
                    self.selected_view -= 1;
                    self.view_state.select(Some(self.selected_view));
                }
            }
            ActiveColumn::Actions => {
                let actions = self.get_current_actions();
                if self.selected_action > 0 {
                    self.selected_action -= 1;
                    self.action_state.select(Some(self.selected_action));
                } else {
                    self.selected_action = actions.len() - 1;
                    self.action_state.select(Some(self.selected_action));
                }
            }
            ActiveColumn::Content => {
                match self.view_mode {
                    ViewMode::DetoursList | ViewMode::DetoursAdd => {
                        if self.selected_detour > 0 {
                            self.selected_detour -= 1;
                            self.detour_state.select(Some(self.selected_detour));
                        }
                    }
                    ViewMode::IncludesList => {
                        if self.selected_include > 0 {
                            self.selected_include -= 1;
                            self.include_state.select(Some(self.selected_include));
                        }
                    }
                    ViewMode::ServicesList => {
                        if self.selected_service > 0 {
                            self.selected_service -= 1;
                            self.service_state.select(Some(self.selected_service));
                        }
                    }
                    _ => {}
                }
            }
        }
    }
    
    pub fn navigate_down(&mut self) {
        match self.active_column {
            ActiveColumn::Views => {
                if self.selected_view < self.views.len() - 1 {
                    self.selected_view += 1;
                    self.view_state.select(Some(self.selected_view));
                }
            }
            ActiveColumn::Actions => {
                let actions = self.get_current_actions();
                if self.selected_action < actions.len() - 1 {
                    self.selected_action += 1;
                    self.action_state.select(Some(self.selected_action));
                } else {
                    self.selected_action = 0;
                    self.action_state.select(Some(self.selected_action));
                }
            }
            ActiveColumn::Content => {
                match self.view_mode {
                    ViewMode::DetoursList | ViewMode::DetoursAdd => {
                        if !self.detours.is_empty() && self.selected_detour < self.detours.len() - 1 {
                            self.selected_detour += 1;
                            self.detour_state.select(Some(self.selected_detour));
                        }
                    }
                    ViewMode::IncludesList => {
                        if !self.includes.is_empty() && self.selected_include < self.includes.len() - 1 {
                            self.selected_include += 1;
                            self.include_state.select(Some(self.selected_include));
                        }
                    }
                    ViewMode::ServicesList => {
                        if !self.services.is_empty() && self.selected_service < self.services.len() - 1 {
                            self.selected_service += 1;
                            self.service_state.select(Some(self.selected_service));
                        }
                    }
                    _ => {}
                }
            }
        }
    }
    
    pub fn navigate_next_column(&mut self) {
        self.active_column = match self.active_column {
            ActiveColumn::Views => ActiveColumn::Actions,
            ActiveColumn::Actions => ActiveColumn::Content,
            ActiveColumn::Content => ActiveColumn::Views,
        };
    }
    
    pub fn navigate_prev_column(&mut self) {
        self.active_column = match self.active_column {
            ActiveColumn::Views => ActiveColumn::Views, // Don't wrap past Views
            ActiveColumn::Actions => ActiveColumn::Views,
            ActiveColumn::Content => ActiveColumn::Actions,
        };
    }
    
    pub fn handle_enter(&mut self) {
        match self.active_column {
            ActiveColumn::Views => {
                // Switch view mode based on selected view
                self.view_mode = match self.selected_view {
                    0 => ViewMode::DetoursList,
                    1 => ViewMode::IncludesList,
                    2 => ViewMode::ServicesList,
                    3 => ViewMode::StatusOverview,
                    4 => ViewMode::LogsLive,
                    5 => ViewMode::ConfigEdit,
                    _ => ViewMode::DetoursList,
                };
                self.selected_action = 0;
                self.action_state.select(Some(0));
                self.active_column = ActiveColumn::Actions;
            }
            ActiveColumn::Actions => {
                // Execute action
                let actions = self.get_current_actions();
                if let Some(action) = actions.get(self.selected_action) {
                    match action.as_str() {
                        "Add" => {
                            self.view_mode = ViewMode::DetoursAdd;
                            self.active_column = ActiveColumn::Content;
                        }
                        "List" => {
                            self.view_mode = ViewMode::DetoursList;
                            self.active_column = ActiveColumn::Content;
                        }
                        _ => {
                            self.active_column = ActiveColumn::Content;
                        }
                    }
                }
            }
            ActiveColumn::Content => {
                // Content-specific actions
            }
        }
    }
    
    pub fn handle_space(&mut self) {
        if self.active_column == ActiveColumn::Content {
            match self.view_mode {
                ViewMode::DetoursList => {
                    let log_msg = if let Some(detour) = self.detours.get_mut(self.selected_detour) {
                        detour.active = !detour.active;
                        Some(format!("Toggled detour: {}", detour.original))
                    } else {
                        None
                    };
                    if let Some(msg) = log_msg {
                        self.add_log("INFO", &msg);
                    }
                }
                ViewMode::IncludesList => {
                    let log_msg = if let Some(include) = self.includes.get_mut(self.selected_include) {
                        include.active = !include.active;
                        Some(format!("Toggled include: {}", include.target))
                    } else {
                        None
                    };
                    if let Some(msg) = log_msg {
                        self.add_log("INFO", &msg);
                    }
                }
                _ => {}
            }
        }
    }
}

impl Default for App {
    fn default() -> Self {
        Self::new()
    }
}

