// Application state management

use ratatui::widgets::ListState;
use crate::config::DetourConfig;
use crate::manager::DetourManager;
use crate::popup::Popup;
use crate::diff::DiffViewer;

#[derive(Debug, Clone)]
pub struct ValidationReport {
    pub content: String,
    pub has_issues: bool,
}

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
    DetoursEdit,
    IncludesAdd,
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
    pub toasts: Vec<Toast>,  // Stacking toasts on the right
    pub popup: Option<Popup>,
    pub diff_viewer: Option<DiffViewer>,
    pub validation_report: Option<ValidationReport>,
    
    // Managers
    pub detour_manager: DetourManager,
    pub config_path: String,
    
    // Add detour form state
    pub add_form: AddDetourForm,
    pub include_form: AddIncludeForm,
    pub pending_action: Option<PendingAction>,
    pub file_browser: Option<crate::filebrowser::FileBrowser>,
    pub input_context: Option<InputContext>,
}

#[derive(Debug, Clone)]
pub struct AddDetourForm {
    pub original_path: String,
    pub custom_path: String,
    pub description: String,
    pub active_field: usize, // 0=original, 1=custom, 2=description
    pub cursor_pos: usize,
    pub editing_index: Option<usize>,  // For edit mode - which detour we're editing
}
#[derive(Debug, Clone)]
pub struct AddIncludeForm {
    pub target_path: String,
    pub include_path: String,
    pub description: String,
    pub active_field: usize, // 0=target, 1=include, 2=description
    pub cursor_pos: usize,
    pub editing_index: Option<usize>,  // For edit mode - which include we're editing
}

impl Default for AddIncludeForm {
    fn default() -> Self {
        Self {
            target_path: String::new(),
            include_path: String::new(),
            description: String::new(),
            active_field: 0,
            cursor_pos: 0,
            editing_index: None,
        }
    }
}

impl Default for AddDetourForm {
    fn default() -> Self {
        Self {
            original_path: String::new(),
            custom_path: String::new(),
            description: String::new(),
            active_field: 0,
            cursor_pos: 0,
            editing_index: None,
        }
    }
}

#[derive(Debug, Clone)]
pub enum PendingAction {
    CreateFileAndSaveDetour,
    DeleteDetour(usize),  // Index of detour to delete
    DeleteInclude(usize), // Index of include to delete
    CreateIncludeFileAndSave, // Create include file then save
}

#[derive(Debug, Clone)]
pub enum InputContext {
    AddIncludeTarget,
    AddIncludeFile(String), // carries target
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

#[derive(Debug, Clone)]
pub struct Toast {
    pub message: String,
    pub toast_type: ToastType,
    pub shown_at: std::time::Instant,
}

#[derive(Debug, Clone, PartialEq)]
pub enum ToastType {
    Success,
    Error,
    Info,
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
            toasts: vec![],
            popup: None,
            diff_viewer: None,
            validation_report: None,
            
            detour_manager,
            config_path,
            add_form: AddDetourForm::default(),
            include_form: AddIncludeForm::default(),
            pending_action: None,
            file_browser: None,
            input_context: None,
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
    
    pub fn close_validation_report(&mut self) {
        self.validation_report = None;
    }
    
    pub fn is_modal_visible(&self) -> bool {
        self.popup.is_some() || self.file_browser.is_some() || self.validation_report.is_some() || self.diff_viewer.is_some()
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
    
    pub fn add_toast(&mut self, message: impl Into<String>, toast_type: ToastType) {
        self.toasts.push(Toast {
            message: message.into(),
            toast_type,
            shown_at: std::time::Instant::now(),
        });
        
        // Keep only last 5 toasts
        if self.toasts.len() > 5 {
            self.toasts.remove(0);
        }
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
    
    pub fn time_ago(secs: u64) -> String {
        // If timestamp is 0 or very old (before year 2000), file doesn't exist or has invalid timestamp
        if secs == 0 || secs < 946684800 {
            return "Never".to_string();
        }
        
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
            
            self.add_toast("Config reloaded", ToastType::Success);
        } else {
            self.add_toast("Failed to reload config", ToastType::Error);
        }
    }
    
    pub fn apply_all_detours(&mut self) {
        match self.detour_manager.apply_all() {
            Ok(_) => {
                self.add_toast("Detours applied successfully", ToastType::Success);
                self.reload_config();
            }
            Err(e) => {
                self.show_error("Apply Error", format!("Failed to apply detours: {}", e));
            }
        }
    }
    
    pub fn remove_all_detours(&mut self) {
        match self.detour_manager.remove_all() {
            Ok(_) => {
                self.add_toast("Detours removed successfully", ToastType::Success);
                self.reload_config();
            }
            Err(e) => {
                self.show_error("Remove Error", format!("Failed to remove detours: {}", e));
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
            ViewMode::DetoursList | ViewMode::DetoursAdd | ViewMode::DetoursEdit => vec![
                "List".to_string(),
                "Validate".to_string(),
            ],
            ViewMode::IncludesList | ViewMode::IncludesAdd => vec![
                "List".to_string(),
                "Validate".to_string(),
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
            (ViewMode::IncludesList, ActiveColumn::Content) => {
                "Navigate includes, press [Enter] for actions, [Space] to toggle enabled".to_string()
            }
            (ViewMode::IncludesList, _) => {
                "Manage Home Assistant includes - target YAML includes another file".to_string()
            }
            (ViewMode::IncludesAdd, _) => {
                "Add an include - specify target path and include file".to_string()
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
                    
                    // Auto-switch to the selected view
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
                
                // Just preview the action, don't change focus
                self.preview_selected_action();
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
                    
                    // Auto-switch to the selected view
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
                
                // Just preview the action, don't change focus
                self.preview_selected_action();
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
                // Enter moves focus to Actions column
                self.active_column = ActiveColumn::Actions;
            }
            ActiveColumn::Actions => {
                // Enter moves focus to Content column and executes action
                self.execute_selected_action();
            }
            ActiveColumn::Content => {
                // Content-specific actions
            }
        }
    }
    
    fn preview_selected_action(&mut self) {
        // Preview action based on selection (update view only, don't change focus)
        let actions = self.get_current_actions();
        if let Some(action) = actions.get(self.selected_action) {
            match action.as_str() {
                "Add" => {
                    self.view_mode = ViewMode::DetoursAdd;
                }
                "List" => {
                    // Keep context-specific list view while previewing
                    self.view_mode = match self.view_mode {
                        ViewMode::IncludesList => ViewMode::IncludesList,
                        ViewMode::ServicesList => ViewMode::ServicesList,
                        ViewMode::StatusOverview => ViewMode::StatusOverview,
                        ViewMode::LogsLive => ViewMode::LogsLive,
                        ViewMode::ConfigEdit => ViewMode::ConfigEdit,
                        _ => ViewMode::DetoursList,
                    };
                }
                _ => {
                    // Other actions just preview
                }
            }
        }
    }
    
    fn execute_selected_action(&mut self) {
        // Execute action AND move focus to content column
        let actions = self.get_current_actions();
        if let Some(action) = actions.get(self.selected_action) {
            match action.as_str() {
                "Add" => {
                    self.view_mode = ViewMode::DetoursAdd;
                    self.active_column = ActiveColumn::Content;
                }
                "Add Include" => {
                    self.view_mode = ViewMode::IncludesAdd;
                    self.include_form = AddIncludeForm::default();
                    self.active_column = ActiveColumn::Content;
                }
                "List" => {
                    // Keep context-specific list view
                    self.view_mode = match self.view_mode {
                        ViewMode::IncludesList => ViewMode::IncludesList,
                        ViewMode::ServicesList => ViewMode::ServicesList,
                        ViewMode::StatusOverview => ViewMode::StatusOverview,
                        ViewMode::LogsLive => ViewMode::LogsLive,
                        ViewMode::ConfigEdit => ViewMode::ConfigEdit,
                        _ => ViewMode::DetoursList,
                    };
                    self.active_column = ActiveColumn::Content;
                }
                "Validate" => {
                    // Column 2 Validate: context-aware
                    if self.view_mode == ViewMode::DetoursList {
                        self.validate_detours_all();
                    } else if self.view_mode == ViewMode::IncludesList {
                        self.validate_includes_all();
                    }
                    self.active_column = ActiveColumn::Content;
                }
                _ => {
                    self.active_column = ActiveColumn::Content;
                }
            }
        }
    }

    // Includes add form methods
    pub fn includes_form_handle_char(&mut self, c: char) {
        let field = match self.include_form.active_field { 0 => &mut self.include_form.target_path, 1 => &mut self.include_form.include_path, 2 => &mut self.include_form.description, _ => return };
        field.insert(self.include_form.cursor_pos.min(field.len()), c);
        self.include_form.cursor_pos += 1;
    }
    pub fn includes_form_backspace(&mut self) {
        let field = match self.include_form.active_field { 0 => &mut self.include_form.target_path, 1 => &mut self.include_form.include_path, 2 => &mut self.include_form.description, _ => return };
        if self.include_form.cursor_pos > 0 && self.include_form.cursor_pos <= field.len() {
            field.remove(self.include_form.cursor_pos - 1);
            self.include_form.cursor_pos -= 1;
        }
    }
    pub fn includes_form_move_cursor_left(&mut self) {
        if self.include_form.cursor_pos > 0 { self.include_form.cursor_pos -= 1; }
    }
    pub fn includes_form_move_cursor_right(&mut self) {
        let len = match self.include_form.active_field { 0 => self.include_form.target_path.len(), 1 => self.include_form.include_path.len(), 2 => self.include_form.description.len(), _ => 0 };
        if self.include_form.cursor_pos < len { self.include_form.cursor_pos += 1; }
    }
    pub fn includes_form_next_field(&mut self) {
        if self.include_form.active_field < 2 { self.include_form.active_field += 1; } else { self.includes_form_submit(); }
        self.include_form.cursor_pos = 0;
    }
    pub fn includes_form_prev_field(&mut self) { if self.include_form.active_field > 0 { self.include_form.active_field -= 1; self.include_form.cursor_pos = 0; } }
    pub fn includes_form_cancel(&mut self) {
        self.view_mode = ViewMode::IncludesList;
        self.active_column = ActiveColumn::Actions;
        self.selected_action = 0;
        self.action_state.select(Some(0));
    }
    pub fn includes_form_submit(&mut self) { self.save_include_to_config(); }
    pub fn save_include_to_config(&mut self) {
        let target = self.include_form.target_path.trim().to_string();
        let include = self.include_form.include_path.trim().to_string();
        let description = self.include_form.description.trim().to_string();
        if target.is_empty() || include.is_empty() {
            self.show_error("Validation Error", "Target and include paths are required".to_string());
            return;
        }
        // If include file doesn't exist, prompt to create it
        if !std::path::Path::new(&include).exists() {
            self.popup = Some(crate::popup::Popup::Confirm {
                title: "Create Include File?".to_string(),
                message: format!("The include file does not exist.\n\n{}\n\nCreate it now?", include),
                selected: 0,
            });
            self.pending_action = Some(PendingAction::CreateIncludeFileAndSave);
            return;
        }
        let mut config = crate::config::DetourConfig::parse(&self.config_path)
            .unwrap_or_else(|_| crate::config::DetourConfig { detours: vec![], includes: vec![], services: vec![] });
        
        // Check if we're editing or adding
        if let Some(edit_idx) = self.include_form.editing_index {
            // Edit existing include
            if let Some(entry) = config.includes.get_mut(edit_idx) {
                entry.target = target.clone();
                entry.include_file = include.clone();
                entry.description = if description.is_empty() { None } else { Some(description) };
            }
        } else {
            // Add new include
            config.includes.push(crate::config::IncludeEntry { target: target.clone(), include_file: include.clone(), description: if description.is_empty() { None } else { Some(description) }, enabled: false });
        }
        
        if let Ok(yaml) = serde_yaml::to_string(&config) {
            if let Err(e) = std::fs::write(&self.config_path, yaml) {
                self.show_error("Save Error", format!("Failed to write config: {}", e));
                return;
            }
            let action = if self.include_form.editing_index.is_some() {
                "Include updated"
            } else {
                "Include added"
            };
            self.add_toast(action, ToastType::Success);
            self.reload_config();
            self.view_mode = ViewMode::IncludesList;
            self.active_column = ActiveColumn::Content;
        } else {
            self.show_error("Serialization Error", "Failed to create YAML".to_string());
        }
    }

    pub fn create_include_file_and_save(&mut self) {
        let include = self.include_form.include_path.trim().to_string();
        // Try to create empty file and parent dirs
        if let Some(parent) = std::path::Path::new(&include).parent() { let _ = std::fs::create_dir_all(parent); }
        match std::fs::OpenOptions::new().create(true).write(true).append(false).open(&include) {
            Ok(_) => {
                // Proceed saving now that file exists
                self.save_include_to_config();
            }
            Err(e) => {
                self.show_error("Create File Error", format!("Failed to create include file: {}", e));
            }
        }
    }

    pub fn includes_form_open_file_browser(&mut self) {
        use crate::filebrowser::FileBrowser;
        let start_path = match self.include_form.active_field {
            0 => {
                if !self.include_form.target_path.is_empty() {
                    std::path::Path::new(&self.include_form.target_path)
                        .parent()
                        .and_then(|p| p.to_str())
                        .unwrap_or("/home/pi")
                } else {
                    "/home/pi"
                }
            }
            1 => {
                if !self.include_form.include_path.is_empty() {
                    std::path::Path::new(&self.include_form.include_path)
                        .parent()
                        .and_then(|p| p.to_str())
                        .unwrap_or("/home/pi/_playground")
                } else {
                    "/home/pi/_playground"
                }
            }
            _ => "/home/pi",
        };
        self.file_browser = Some(FileBrowser::new(start_path));
    }
    pub fn includes_form_close_file_browser(&mut self, selected_path: Option<String>) {
        if let Some(path) = selected_path {
            match self.include_form.active_field {
                0 => { self.include_form.target_path = path.clone(); self.include_form.cursor_pos = path.len(); }
                1 => { self.include_form.include_path = path.clone(); self.include_form.cursor_pos = path.len(); }
                _ => {}
            }
        }
        self.file_browser = None;
    }
    pub fn includes_form_complete_path(&mut self) {
        use crate::filebrowser::{complete_path, expand_path_shorthand};
        let current_text = match self.include_form.active_field { 0 => &self.include_form.target_path, 1 => &self.include_form.include_path, 2 => { self.includes_form_next_field(); return; }, _ => return };
        if let Some(expansions) = expand_path_shorthand(current_text) {
            if !expansions.is_empty() {
                let expanded = expansions[0].clone();
                match self.include_form.active_field {
                    0 => { self.include_form.target_path = expanded.clone(); self.include_form.cursor_pos = expanded.len(); }
                    1 => { self.include_form.include_path = expanded.clone(); self.include_form.cursor_pos = expanded.len(); }
                    _ => {}
                }
                return;
            }
        }
        let completions = complete_path(current_text);
        if !completions.is_empty() {
            let completed = completions[0].clone();
            match self.include_form.active_field {
                0 => { self.include_form.target_path = completed.clone(); self.include_form.cursor_pos = completed.len(); }
                1 => { self.include_form.include_path = completed.clone(); self.include_form.cursor_pos = completed.len(); }
                _ => {}
            }
        } else {
            self.includes_form_next_field();
        }
    }
    pub fn includes_form_paste_clipboard(&mut self) {
        use arboard::Clipboard;
        if let Ok(mut clipboard) = Clipboard::new() {
            if let Ok(text) = clipboard.get_text() {
                match self.include_form.active_field {
                    0 => { self.include_form.target_path.push_str(&text); self.include_form.cursor_pos = self.include_form.target_path.len(); }
                    1 => { self.include_form.include_path.push_str(&text); self.include_form.cursor_pos = self.include_form.include_path.len(); }
                    _ => {}
                }
            }
        }
    }

    // Includes: start add flow via input popups
    pub fn start_add_include(&mut self) {
        self.input_context = Some(InputContext::AddIncludeTarget);
        self.popup = Some(crate::popup::Popup::Input {
            title: "Add Include - Target path".to_string(),
            prompt: "Enter the target path to include into".to_string(),
            input: String::new(),
            cursor_pos: 0,
        });
    }

    pub fn handle_input_submit(&mut self, value: String) {
        if let Some(ctx) = self.input_context.clone() {
            match ctx {
                InputContext::AddIncludeTarget => {
                    // Next: ask for include file path
                    self.input_context = Some(InputContext::AddIncludeFile(value));
                    self.popup = Some(crate::popup::Popup::Input {
                        title: "Add Include - Include file".to_string(),
                        prompt: "Enter the include file path".to_string(),
                        input: String::new(),
                        cursor_pos: 0,
                    });
                }
                InputContext::AddIncludeFile(target) => {
                    let include_file = value;
                    // Write to config
                    let mut config = crate::config::DetourConfig::parse(&self.config_path)
                        .unwrap_or_else(|_| crate::config::DetourConfig { detours: vec![], includes: vec![], services: vec![] });
                    config.includes.push(crate::config::IncludeEntry {
                        target: target.clone(),
                        include_file: include_file.clone(),
                        description: None,
                        enabled: false,
                    });
                    if let Ok(yaml) = serde_yaml::to_string(&config) {
                        if let Err(e) = std::fs::write(&self.config_path, yaml) {
                            self.show_error("Save Error", format!("Failed to write config: {}", e));
                        } else {
                            self.add_log("SUCCESS", &format!("Added include: {} -> {}", target, include_file));
                            self.add_toast("Include added", ToastType::Success);
                            self.reload_config();
                        }
                    } else {
                        self.show_error("Serialization Error", "Failed to create YAML".to_string());
                    }
                    self.input_context = None;
                }
            }
        }
    }
    
    pub fn handle_space(&mut self) {
        if self.active_column == ActiveColumn::Content {
            match self.view_mode {
                ViewMode::DetoursList => {
                    if let Some(detour) = self.detours.get_mut(self.selected_detour) {
                        let new_state = !detour.active;
                        let original = detour.original.clone();
                        let custom = detour.custom.clone();
                        
                        // Apply or remove the actual bind mount
                        let result = if new_state {
                            self.detour_manager.apply_detour(&original, &custom)
                        } else {
                            self.detour_manager.remove_detour(&original)
                        };
                        
                        match result {
                            Ok(msg) => {
                                // Success - update state and config
                                detour.active = new_state;
                                
                                // Update config file
                                if let Ok(mut config) = crate::config::DetourConfig::parse(&self.config_path) {
                                    if let Some(entry) = config.detours.iter_mut().find(|e| e.original == original) {
                                        entry.enabled = new_state;
                                        
                                        // Save updated config
                                        if let Ok(yaml) = serde_yaml::to_string(&config) {
                                            let _ = std::fs::write(&self.config_path, yaml);
                                        }
                                    }
                                }
                                
                                let action = if new_state { "Activated" } else { "Deactivated" };
                                self.add_log("INFO", &msg);
                                self.add_toast(format!("{} detour", action), ToastType::Success);
                            }
                            Err(err) => {
                                self.show_error("Mount Error", format!("Failed to toggle detour: {}", err));
                            }
                        }
                    }
                }
                ViewMode::IncludesList => {
                    if let Some(include) = self.includes.get_mut(self.selected_include) {
                        let new_state = !include.active;
                        include.active = new_state;
                        let target = include.target.clone();
                        
                        // Update config file
                        if let Ok(mut config) = crate::config::DetourConfig::parse(&self.config_path) {
                            if let Some(entry) = config.includes.iter_mut().find(|e| e.target == target) {
                                entry.enabled = new_state;
                                
                                // Save updated config
                                if let Ok(yaml) = serde_yaml::to_string(&config) {
                                    let _ = std::fs::write(&self.config_path, yaml);
                                }
                            }
                        }
                        
                        let action = if new_state { "Activated" } else { "Deactivated" };
                        self.add_log("INFO", &format!("{} include: {}", action, target));
                        self.add_toast(format!("{} include", action), ToastType::Success);
                    }
                }
                _ => {}
            }
        }
    }
    
    // Add detour form methods
    pub fn form_handle_char(&mut self, c: char) {
        let field = match self.add_form.active_field {
            0 => &mut self.add_form.original_path,
            1 => &mut self.add_form.custom_path,
            2 => &mut self.add_form.description,
            _ => return,
        };
        
        field.insert(self.add_form.cursor_pos, c);
        self.add_form.cursor_pos += 1;
    }
    
    pub fn form_handle_backspace(&mut self) {
        if self.add_form.cursor_pos == 0 {
            return;
        }
        
        let field = match self.add_form.active_field {
            0 => &mut self.add_form.original_path,
            1 => &mut self.add_form.custom_path,
            2 => &mut self.add_form.description,
            _ => return,
        };
        
        self.add_form.cursor_pos -= 1;
        field.remove(self.add_form.cursor_pos);
    }
    
    pub fn form_next_field(&mut self) {
        self.add_form.active_field = (self.add_form.active_field + 1) % 3;
        let field = match self.add_form.active_field {
            0 => &self.add_form.original_path,
            1 => &self.add_form.custom_path,
            2 => &self.add_form.description,
            _ => &self.add_form.original_path,
        };
        self.add_form.cursor_pos = field.len();
    }
    
    pub fn form_save_detour(&mut self) {
        use std::path::Path;
        
        // Validate input
        if self.add_form.original_path.is_empty() || self.add_form.custom_path.is_empty() {
            self.show_error("Validation Error", "Original and Custom paths are required");
            return;
        }
        
        // Check if custom file exists
        let custom_path = Path::new(&self.add_form.custom_path);
        if !custom_path.exists() {
            // File doesn't exist - prompt to create
            self.pending_action = Some(PendingAction::CreateFileAndSaveDetour);
            self.popup = Some(crate::popup::Popup::Confirm {
                title: "File Not Found".to_string(),
                message: format!("Custom file doesn't exist:\n{}\n\nCreate it?", self.add_form.custom_path),
                selected: 0, // Default to "Yes"
            });
            return;
        }
        
        // File exists, proceed with save
        self.save_detour_to_config();
    }
    
    fn save_detour_to_config(&mut self) {
        use crate::config::{DetourConfig, DetourEntry};
        
        // Load existing config
        let mut config = DetourConfig::parse(&self.config_path).unwrap_or_else(|_| DetourConfig {
            detours: vec![],
            includes: vec![],
            services: vec![],
        });
        
        // Check if we're editing or adding
        if let Some(edit_idx) = self.add_form.editing_index {
            // Edit existing detour
            if let Some(entry) = config.detours.get_mut(edit_idx) {
                entry.original = self.add_form.original_path.clone();
                entry.custom = self.add_form.custom_path.clone();
                entry.description = if self.add_form.description.is_empty() {
                    None
                } else {
                    Some(self.add_form.description.clone())
                };
            }
        } else {
            // Add new detour
            config.detours.push(DetourEntry {
                original: self.add_form.original_path.clone(),
                custom: self.add_form.custom_path.clone(),
                description: if self.add_form.description.is_empty() {
                    None
                } else {
                    Some(self.add_form.description.clone())
                },
                enabled: false,
            });
        }
        
        // Save to file
        match serde_yaml::to_string(&config) {
            Ok(yaml) => {
                if let Err(e) = std::fs::write(&self.config_path, yaml) {
                    self.show_error("Save Error", format!("Failed to write config: {}", e));
                    return;
                }
                
                let action = if self.add_form.editing_index.is_some() {
                    "Updated"
                } else {
                    "Added"
                };
                
                self.add_log("SUCCESS", &format!("{} detour: {} → {}", 
                    action, self.add_form.original_path, self.add_form.custom_path));
                self.add_toast(format!("Detour {} successfully!", action.to_lowercase()), ToastType::Success);
                
                // Reset form
                self.add_form = AddDetourForm::default();
                
                // Reload config and switch to list view (after successful save)
                self.reload_config();
                self.view_mode = ViewMode::DetoursList;
                self.selected_action = 0;  // Select "List" in Column 2
                self.action_state.select(Some(0));
                self.active_column = ActiveColumn::Content;
            }
            Err(e) => {
                self.show_error("Serialization Error", format!("Failed to create YAML: {}", e));
            }
        }
    }
    
    pub fn create_custom_file_and_save(&mut self) {
        use std::fs;
        use std::path::Path;
        
        let custom_path = Path::new(&self.add_form.custom_path);
        
        // Create parent directories if needed
        if let Some(parent) = custom_path.parent() {
            if let Err(e) = fs::create_dir_all(parent) {
                self.show_error("File Creation Error", format!("Failed to create directories: {}", e));
                return;
            }
        }
        
        // Create empty file
        if let Err(e) = fs::write(custom_path, "") {
            self.show_error("File Creation Error", format!("Failed to create file: {}", e));
            return;
        }
        
        self.add_log("INFO", &format!("Created file: {}", self.add_form.custom_path));
        
        // Now save the detour
        self.save_detour_to_config();
    }
    
    pub fn form_cancel(&mut self) {
        // Reset form
        self.add_form = AddDetourForm::default();
        
        // Return to List view and select "List" in Column 2
        self.view_mode = ViewMode::DetoursList;
        self.selected_action = 0;  // Select "List"
        self.action_state.select(Some(0));
        self.active_column = ActiveColumn::Content;
    }
    
    // Validate detours with three levels of checks
    pub fn validate_detours_all(&mut self) {
        use std::time::Instant;
        use std::path::Path;
        
        let mut results = Vec::new();
        let start_time = Instant::now();
        
        // Phase 1: Basic Validation (path existence)
        let phase1_start = Instant::now();
        let mut missing_original = 0;
        let mut missing_custom = 0;
        let mut unreadable = 0;
        
        for detour in &self.detours {
            let original_path = Path::new(&detour.original);
            let custom_path = Path::new(&detour.custom);
            
            if !original_path.exists() {
                missing_original += 1;
            }
            if !custom_path.exists() {
                missing_custom += 1;
            }
            
            // Check readability
            if original_path.exists() && std::fs::metadata(&detour.original).is_err() {
                unreadable += 1;
            }
            if custom_path.exists() && std::fs::metadata(&detour.custom).is_err() {
                unreadable += 1;
            }
        }
        
        let phase1_time = phase1_start.elapsed();
        results.push(format!(
            "Phase 1: Basic Validation ({:.2}ms)\n  ✓ Checked {} detours\n  {} missing original paths\n  {} missing custom paths\n  {} unreadable files",
            phase1_time.as_secs_f64() * 1000.0,
            self.detours.len(),
            missing_original,
            missing_custom,
            unreadable
        ));
        
        // Phase 2: State Verification (config vs system)
        let phase2_start = Instant::now();
        let mut config_mismatch = 0;
        let mut mount_check_failed = 0;
        
        for detour in &self.detours {
            // Check if mount state matches config
            let mount_output = std::process::Command::new("findmnt")
                .arg("-n")
                .arg("-o")
                .arg("SOURCE")
                .arg(&detour.original)
                .output();
                
            if let Ok(output) = mount_output {
                let is_mounted = !output.stdout.is_empty();
                if is_mounted != detour.active {
                    config_mismatch += 1;
                }
            } else {
                mount_check_failed += 1;
            }
        }
        
        let phase2_time = phase2_start.elapsed();
        let phase1_2_time = start_time.elapsed();
        results.push(format!(
            "Phase 2: State Verification ({:.2}ms, cumulative: {:.2}ms)\n  {} config/mount mismatches\n  {} mount checks failed",
            phase2_time.as_secs_f64() * 1000.0,
            phase1_2_time.as_secs_f64() * 1000.0,
            config_mismatch,
            mount_check_failed
        ));
        
        // Phase 3: Comprehensive Check
        let phase3_start = Instant::now();
        let mut duplicate_originals = 0;
        let mut conflicts = std::collections::HashMap::new();
        
        for detour in &self.detours {
            *conflicts.entry(&detour.original).or_insert(0) += 1;
        }
        
        for (_, count) in conflicts {
            if count > 1 {
                duplicate_originals += 1;
            }
        }
        
        let phase3_time = phase3_start.elapsed();
        let total_time = start_time.elapsed();
        results.push(format!(
            "Phase 3: Comprehensive Check ({:.2}ms, cumulative: {:.2}ms)\n  {} duplicate original paths\n  All checks passed",
            phase3_time.as_secs_f64() * 1000.0,
            total_time.as_secs_f64() * 1000.0,
            duplicate_originals
        ));
        
        // Summary
        let summary = format!(
            "Validation Complete\n\nTotal time: {:.2}ms\n\n{}",
            total_time.as_secs_f64() * 1000.0,
            results.join("\n\n")
        );
        
        let has_issues = missing_original > 0 
            || missing_custom > 0 
            || unreadable > 0 
            || config_mismatch > 0 
            || duplicate_originals > 0;
        
        // Show validation report in panel view
        self.validation_report = Some(ValidationReport {
            content: summary,
            has_issues,
        });
        
        self.add_log("INFO", &format!(
            "Validation completed in {:.2}ms - {} issues found",
            total_time.as_secs_f64() * 1000.0,
            if has_issues { "some" } else { "no" }
        ));
    }

    pub fn validate_single_detour(&mut self, index: usize) {
        use std::time::Instant;
        use std::path::Path;
        if index >= self.detours.len() { return; }
        let detour = &self.detours[index];
        let mut results = Vec::new();
        let start_time = Instant::now();

        // Phase 1: Basic Validation (path existence)
        let phase1_start = Instant::now();
        let original_path = Path::new(&detour.original);
        let custom_path = Path::new(&detour.custom);
        let missing_original = if !original_path.exists() { 1 } else { 0 };
        let missing_custom = if !custom_path.exists() { 1 } else { 0 };
        let mut unreadable = 0;
        if original_path.exists() && std::fs::metadata(&detour.original).is_err() { unreadable += 1; }
        if custom_path.exists() && std::fs::metadata(&detour.custom).is_err() { unreadable += 1; }
        let phase1_time = phase1_start.elapsed();
        results.push(format!(
            "Phase 1: Basic Validation ({:.2}ms)\n  ✓ Checked 1 detour\n  {} missing original path\n  {} missing custom path\n  {} unreadable file",
            phase1_time.as_secs_f64() * 1000.0,
            missing_original,
            missing_custom,
            unreadable
        ));

        // Phase 2: State Validation (mount status)
        let phase2_start = Instant::now();
        let is_mounted = self.detour_manager.is_active(&detour.original);
        let phase2_time = phase2_start.elapsed();
        results.push(format!(
            "Phase 2: State Validation ({:.2}ms)\n  {} mounted for {}",
            phase2_time.as_secs_f64() * 1000.0,
            if is_mounted { "✓" } else { "○ Not" },
            detour.original
        ));

        // Phase 3: Comprehensive Validation (conflicts/overlaps)
        let phase3_start = Instant::now();
        let mut conflicts = 0;
        // Simple overlap check against other detours
        for (i, other) in self.detours.iter().enumerate() {
            if i == index { continue; }
            if other.original == detour.original { conflicts += 1; }
        }
        let phase3_time = phase3_start.elapsed();
        results.push(format!(
            "Phase 3: Comprehensive Validation ({:.2}ms)\n  {} overlapping detour(s) detected",
            phase3_time.as_secs_f64() * 1000.0,
            conflicts
        ));

        let total_time = start_time.elapsed();
        let has_issues = missing_original > 0 || missing_custom > 0 || unreadable > 0 || conflicts > 0;
        let summary = format!(
            "Validation Report (single detour) - {:.2}ms total\n\nTarget: {}\nCustom: {}\n\n{}\n\nSummary:\n  {} issues found",
            total_time.as_secs_f64() * 1000.0,
            detour.original,
            detour.custom,
            results.join("\n\n"),
            if has_issues { "Some" } else { "No" }
        );

        self.validation_report = Some(ValidationReport {
            content: summary,
            has_issues,
        });

        self.add_log("INFO", &format!(
            "Single detour validation completed in {:.2}ms - {} issues found",
            total_time.as_secs_f64() * 1000.0,
            if has_issues { "some" } else { "no" }
        ));
    }

    pub fn validate_includes_all(&mut self) {
        use std::path::Path;
        use std::time::Instant;
        let mut results = Vec::new();
        let start_time = Instant::now();

        let phase1_start = Instant::now();
        let mut missing_target = 0;
        let mut missing_include = 0;
        let mut unreadable = 0;
        for inc in &self.includes {
            let target_path = Path::new(&inc.target);
            let include_path = Path::new(&inc.include_file);
            if !target_path.exists() { missing_target += 1; }
            if !include_path.exists() { missing_include += 1; }
            if target_path.exists() && std::fs::metadata(&inc.target).is_err() { unreadable += 1; }
            if include_path.exists() && std::fs::metadata(&inc.include_file).is_err() { unreadable += 1; }
        }
        let phase1_time = phase1_start.elapsed();
        results.push(format!(
            "Phase 1: Basic Validation ({:.2}ms)\n  ✓ Checked {} includes\n  {} missing targets\n  {} missing include files\n  {} unreadable files",
            phase1_time.as_secs_f64()*1000.0,
            self.includes.len(),
            missing_target,
            missing_include,
            unreadable
        ));

        let phase2_start = Instant::now();
        let active_count = self.includes.iter().filter(|i| i.active).count();
        let phase2_time = phase2_start.elapsed();
        results.push(format!(
            "Phase 2: State Validation ({:.2}ms)\n  {} active includes",
            phase2_time.as_secs_f64()*1000.0,
            active_count
        ));

        let phase3_start = Instant::now();
        let mut conflicts = 0;
        for i in 0..self.includes.len() {
            for j in (i+1)..self.includes.len() {
                if self.includes[i].target == self.includes[j].target { conflicts += 1; }
            }
        }
        let phase3_time = phase3_start.elapsed();
        results.push(format!(
            "Phase 3: Comprehensive Validation ({:.2}ms)\n  {} conflicting target(s)",
            phase3_time.as_secs_f64()*1000.0,
            conflicts
        ));

        let total_time = start_time.elapsed();
        let has_issues = missing_target>0 || missing_include>0 || unreadable>0 || conflicts>0;
        let summary = format!(
            "Includes Validation Report - {:.2}ms total\n\n{}\n\nSummary:\n  {} issues found",
            total_time.as_secs_f64()*1000.0,
            results.join("\n\n"),
            if has_issues { "Some" } else { "No" }
        );
        self.validation_report = Some(ValidationReport { content: summary, has_issues });
        self.add_log("INFO", &format!(
            "Includes validation completed in {:.2}ms - {} issues found",
            total_time.as_secs_f64()*1000.0,
            if has_issues { "some" } else { "no" }
        ));
    }

    pub fn validate_single_include(&mut self, index: usize) {
        use std::path::Path;
        use std::time::Instant;
        if index >= self.includes.len() { return; }
        let inc = &self.includes[index];
        let mut results = Vec::new();
        let start_time = Instant::now();

        let phase1_start = Instant::now();
        let target_path = Path::new(&inc.target);
        let include_path = Path::new(&inc.include_file);
        let missing_target = if !target_path.exists() { 1 } else { 0 };
        let missing_include = if !include_path.exists() { 1 } else { 0 };
        let mut unreadable = 0;
        if target_path.exists() && std::fs::metadata(&inc.target).is_err() { unreadable += 1; }
        if include_path.exists() && std::fs::metadata(&inc.include_file).is_err() { unreadable += 1; }
        let phase1_time = phase1_start.elapsed();
        results.push(format!(
            "Phase 1: Basic Validation ({:.2}ms)\n  ✓ Checked 1 include\n  {} missing target\n  {} missing include file\n  {} unreadable file",
            phase1_time.as_secs_f64()*1000.0,
            missing_target,
            missing_include,
            unreadable
        ));

        let phase2_start = Instant::now();
        let active_text = if inc.active { "✓ Active" } else { "○ Inactive" };
        let phase2_time = phase2_start.elapsed();
        results.push(format!(
            "Phase 2: State Validation ({:.2}ms)\n  {}",
            phase2_time.as_secs_f64()*1000.0,
            active_text
        ));

        let phase3_start = Instant::now();
        let mut conflicts = 0;
        for (i, other) in self.includes.iter().enumerate() {
            if i == index { continue; }
            if other.target == inc.target { conflicts += 1; }
        }
        let phase3_time = phase3_start.elapsed();
        results.push(format!(
            "Phase 3: Comprehensive Validation ({:.2}ms)\n  {} conflicting target(s)",
            phase3_time.as_secs_f64()*1000.0,
            conflicts
        ));

        let total_time = start_time.elapsed();
        let has_issues = missing_target>0 || missing_include>0 || unreadable>0 || conflicts>0;
        let summary = format!(
            "Include Validation Report - {:.2}ms total\n\nTarget: {}\nInclude: {}\n\n{}\n\nSummary:\n  {} issues found",
            total_time.as_secs_f64()*1000.0,
            inc.target,
            inc.include_file,
            results.join("\n\n"),
            if has_issues { "Some" } else { "No" }
        );
        self.validation_report = Some(ValidationReport { content: summary, has_issues });
        self.add_log("INFO", &format!(
            "Single include validation completed in {:.2}ms - {} issues found",
            total_time.as_secs_f64()*1000.0,
            if has_issues { "some" } else { "no" }
        ));
    }

    pub fn delete_selected_include(&mut self) {
        if let Some(include) = self.includes.get(self.selected_include) {
            let target = include.target.clone();
            self.popup = Some(Popup::Confirm {
                title: "Confirm Delete".to_string(),
                message: format!("Delete this include?\n\n{}", target),
                selected: 1,
            });
            self.pending_action = Some(PendingAction::DeleteInclude(self.selected_include));
        }
    }

    pub fn confirm_delete_include(&mut self, index: usize) {
        // Load config
        let mut config = crate::config::DetourConfig::parse(&self.config_path).unwrap_or_else(|_| crate::config::DetourConfig{
            detours: vec![],
            includes: vec![],
            services: vec![],
        });
        if index < config.includes.len() {
            let removed = config.includes.remove(index);
            if let Ok(yaml) = serde_yaml::to_string(&config) {
                if let Err(e) = std::fs::write(&self.config_path, yaml) {
                    self.show_error("Save Error", format!("Failed to write config: {}", e));
                    return;
                }
                self.add_log("SUCCESS", &format!("Deleted include: {}", removed.target));
                self.add_toast("Include deleted successfully!", ToastType::Success);
                self.reload_config();
                if self.selected_include >= self.includes.len() && self.selected_include > 0 {
                    self.selected_include -= 1;
                    self.include_state.select(Some(self.selected_include));
                }
            } else {
                self.show_error("Serialization Error", "Failed to create YAML".to_string());
            }
        }
    }
    
    // Start editing the currently selected include
    pub fn edit_selected_include(&mut self) {
        if let Some(include) = self.includes.get(self.selected_include) {
            // Load config to get description
            let description = if let Ok(config) = crate::config::DetourConfig::parse(&self.config_path) {
                config.includes.get(self.selected_include)
                    .and_then(|e| e.description.clone())
                    .unwrap_or_default()
            } else {
                String::new()
            };
            
            // Populate form with current include data
            self.include_form = AddIncludeForm {
                target_path: include.target.clone(),
                include_path: include.include_file.clone(),
                description,
                active_field: 0,
                cursor_pos: 0,
                editing_index: Some(self.selected_include),
            };
            
            // Switch to add view (reuse for editing)
            self.view_mode = ViewMode::IncludesAdd;
            self.active_column = ActiveColumn::Content;
            
            self.add_log("INFO", &format!("Editing include: {}", include.target));
        }
    }
    
    // Start editing the currently selected detour
    pub fn edit_selected_detour(&mut self) {
        if let Some(detour) = self.detours.get(self.selected_detour) {
            // Load config to get description
            let description = if let Ok(config) = crate::config::DetourConfig::parse(&self.config_path) {
                config.detours.get(self.selected_detour)
                    .and_then(|e| e.description.clone())
                    .unwrap_or_default()
            } else {
                String::new()
            };
            
            // Populate form with current detour data
            self.add_form = AddDetourForm {
                original_path: detour.original.clone(),
                custom_path: detour.custom.clone(),
                description,
                active_field: 0,
                cursor_pos: 0,
                editing_index: Some(self.selected_detour),
            };
            
            // Switch to edit view
            self.view_mode = ViewMode::DetoursEdit;
            self.active_column = ActiveColumn::Content;
            
            self.add_log("INFO", &format!("Editing detour: {}", detour.original));
        }
    }
    
    // Delete the currently selected detour (with confirmation)
    pub fn delete_selected_detour(&mut self) {
        if let Some(detour) = self.detours.get(self.selected_detour) {
            // Show confirmation popup
            self.pending_action = Some(PendingAction::DeleteDetour(self.selected_detour));
            self.popup = Some(crate::popup::Popup::Confirm {
                title: "Confirm Delete".to_string(),
                message: format!("Delete this detour?\n\n{}\n→ {}", detour.original, detour.custom),
                selected: 1, // Default to "No" for safety
            });
        }
    }
    
    // Actually delete the detour from config
    pub fn confirm_delete_detour(&mut self, index: usize) {
        use crate::config::DetourConfig;
        
        // Load existing config
        let mut config = DetourConfig::parse(&self.config_path).unwrap_or_else(|_| DetourConfig {
            detours: vec![],
            includes: vec![],
            services: vec![],
        });
        
        // Remove the detour
        if index < config.detours.len() {
            let removed = config.detours.remove(index);
            
            // Save to file
            match serde_yaml::to_string(&config) {
                Ok(yaml) => {
                    if let Err(e) = std::fs::write(&self.config_path, yaml) {
                        self.show_error("Save Error", format!("Failed to write config: {}", e));
                        return;
                    }
                    
                    self.add_log("SUCCESS", &format!("Deleted detour: {}", removed.original));
                    self.add_toast("Detour deleted successfully!", ToastType::Success);
                    
                    // Reload config
                    self.reload_config();
                    
                    // Adjust selection if needed
                    if self.selected_detour >= self.detours.len() && self.selected_detour > 0 {
                        self.selected_detour -= 1;
                        self.detour_state.select(Some(self.selected_detour));
                    }
                }
                Err(e) => {
                    self.show_error("Serialization Error", format!("Failed to create YAML: {}", e));
                }
            }
        }
    }
    
    // Clipboard paste
    pub fn form_paste_clipboard(&mut self) {
        use arboard::Clipboard;
        
        if let Ok(mut clipboard) = Clipboard::new() {
            if let Ok(text) = clipboard.get_text() {
                // Insert clipboard text at cursor position
                for c in text.chars() {
                    self.form_handle_char(c);
                }
            }
        }
    }
    
    // File browser
    pub fn form_open_file_browser(&mut self) {
        use crate::filebrowser::FileBrowser;
        
        // Start from current field's path or home directory
        let start_path = match self.add_form.active_field {
            0 => {
                if !self.add_form.original_path.is_empty() {
                    std::path::Path::new(&self.add_form.original_path)
                        .parent()
                        .and_then(|p| p.to_str())
                        .unwrap_or("/home/pi")
                } else {
                    "/home/pi"
                }
            }
            1 => {
                if !self.add_form.custom_path.is_empty() {
                    std::path::Path::new(&self.add_form.custom_path)
                        .parent()
                        .and_then(|p| p.to_str())
                        .unwrap_or("/home/pi/_playground")
                } else {
                    "/home/pi/_playground"
                }
            }
            _ => "/home/pi",
        };
        
        self.file_browser = Some(FileBrowser::new(start_path));
    }
    
    pub fn form_close_file_browser(&mut self, selected_path: Option<String>) {
        if let Some(path) = selected_path {
            // Set the selected path to the active field
            match self.add_form.active_field {
                0 => {
                    self.add_form.original_path = path.clone();
                    self.add_form.cursor_pos = path.len();
                }
                1 => {
                    self.add_form.custom_path = path.clone();
                    self.add_form.cursor_pos = path.len();
                }
                2 => {
                    self.add_form.description = path.clone();
                    self.add_form.cursor_pos = path.len();
                }
                _ => {}
            }
        }
        
        self.file_browser = None;
    }
    
    // Path completion with Tab
    pub fn form_complete_path(&mut self) {
        use crate::filebrowser::{complete_path, expand_path_shorthand};
        
        let current_text = match self.add_form.active_field {
            0 => &self.add_form.original_path,
            1 => &self.add_form.custom_path,
            _ => return, // Don't complete description field
        };
        
        // Try zsh-style expansion first (p/t/f -> path/to/file)
        if let Some(expansions) = expand_path_shorthand(current_text) {
            if !expansions.is_empty() {
                // Use first match
                let expanded = expansions[0].clone();
                match self.add_form.active_field {
                    0 => {
                        self.add_form.original_path = expanded.clone();
                        self.add_form.cursor_pos = expanded.len();
                    }
                    1 => {
                        self.add_form.custom_path = expanded.clone();
                        self.add_form.cursor_pos = expanded.len();
                    }
                    _ => {}
                }
                
                if expansions.len() > 1 {
                    self.add_toast(
                        format!("Found {} matches. Showing first one.", expansions.len()),
                        ToastType::Info);
                }
                return;
            }
        }
        
        // Fall back to standard tab completion
        let completions = complete_path(current_text);
        if !completions.is_empty() {
            let completed = completions[0].clone();
            match self.add_form.active_field {
                0 => {
                    self.add_form.original_path = completed.clone();
                    self.add_form.cursor_pos = completed.len();
                }
                1 => {
                    self.add_form.custom_path = completed.clone();
                    self.add_form.cursor_pos = completed.len();
                }
                _ => {}
            }
            
            if completions.len() > 1 {
                self.add_toast(
                    format!("Found {} matches. Showing first one.", completions.len()),
                    ToastType::Info);
            }
        }
    }
}

impl Default for App {
    fn default() -> Self {
        Self::new()
    }
}

