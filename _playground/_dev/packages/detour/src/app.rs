// Application state management

use ratatui::widgets::ListState;
use crate::manager::DetourManager;
use crate::include::IncludeManager;
use crate::popup::Popup;
use crate::diff::DiffViewer;
use std::time::{SystemTime, UNIX_EPOCH};

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

#[derive(Debug, Clone)]
pub struct Include {
    pub target: String,
    pub include_file: String,
    pub active: bool,
    pub size: u64,
    pub modified: String,
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
pub enum ToastType {
    Success,
    Error,
    Info,
}

#[derive(Debug, Clone)]
pub struct Toast {
    pub message: String,
    pub toast_type: ToastType,
    pub shown_at: SystemTime,
}

#[derive(Debug, Clone)]
pub struct AddDetourForm {
    pub original_path: String,
    pub custom_path: String,
    pub description: String,
    pub active_field: usize,
    pub cursor_pos: usize,
    pub editing_index: Option<usize>,
}

#[derive(Debug, Clone)]
pub struct AddIncludeForm {
    pub target_path: String,
    pub include_path: String,
    pub description: String,
    pub active_field: usize,
    pub cursor_pos: usize,
    pub editing_index: Option<usize>,
}

#[derive(Debug, Clone)]
pub enum PendingAction {
    CreateFileAndSaveDetour,
    DeleteDetour(usize),
    DeleteDetourAndFile(usize, String),
    DeleteInclude(usize),
    DeleteIncludeAndFile(usize, String),
    CreateIncludeFileAndSave,
}

#[derive(Debug, Clone)]
pub enum InputContext {
    AddIncludeTarget,
    AddIncludeFile(String),
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

pub struct App {
    pub should_quit: bool,
    pub active_column: ActiveColumn,
    pub view_mode: ViewMode,
    
    pub selected_view: usize,
    pub selected_action: usize,
    pub selected_detour: usize,
    pub selected_include: usize,
    pub selected_service: usize,
    
    pub view_state: ListState,
    pub action_state: ListState,
    pub detour_state: ListState,
    pub include_state: ListState,
    pub service_state: ListState,
    
    pub views: Vec<String>,
    pub detours: Vec<Detour>,
    pub includes: Vec<Include>,
    pub services: Vec<Service>,
    pub logs: Vec<LogEntry>,
    pub profile: String,
    pub toasts: Vec<Toast>,
    pub popup: Option<Popup>,
    pub diff_viewer: Option<DiffViewer>,
    pub validation_report: Option<ValidationReport>,
    
    pub detour_manager: DetourManager,
    pub include_manager: IncludeManager,
    pub config_path: String,
    
    pub add_form: AddDetourForm,
    pub include_form: AddIncludeForm,
    pub pending_action: Option<PendingAction>,
    pub file_browser: Option<crate::filebrowser::FileBrowser>,
    pub input_context: Option<InputContext>,
}

impl App {
    pub fn new() -> Self {
        let config_path = "/home/pi/.detour.yaml".to_string();
        let detour_manager = DetourManager::new();
        let include_manager = IncludeManager::new();
        
        let (detours, includes, services) = Self::load_initial_config(&config_path, &detour_manager);
        
        Self {
            should_quit: false,
            active_column: ActiveColumn::Views,
            view_mode: ViewMode::DetoursList,
            
            selected_view: 0,
            selected_action: 0,
            selected_detour: 0,
            selected_include: 0,
            selected_service: 0,
            
            view_state: ListState::default(),
            action_state: ListState::default(),
            detour_state: ListState::default(),
            include_state: ListState::default(),
            service_state: ListState::default(),
            
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
            profile: "dev".to_string(),
            toasts: vec![],
            popup: None,
            diff_viewer: None,
            validation_report: None,
            
            detour_manager,
            include_manager,
            config_path,
            
            add_form: AddDetourForm::default(),
            include_form: AddIncludeForm::default(),
            pending_action: None,
            file_browser: None,
            input_context: None,
        }
    }
    
    fn load_initial_config(config_path: &str, detour_manager: &DetourManager) -> (Vec<Detour>, Vec<Include>, Vec<Service>) {
        use crate::operations::config_ops;
        let config = config_ops::load_config(config_path);
        
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
        
        let includes = config.includes.iter().map(|entry| {
            let file_info = detour_manager.get_file_info(&entry.include_file);
            Include {
                target: entry.target.clone(),
                include_file: entry.include_file.clone(),
                active: entry.enabled,
                size: file_info.as_ref().map(|f| f.size).unwrap_or(0),
                modified: Self::time_ago(file_info.as_ref().map(|f| f.modified_secs).unwrap_or(0)),
            }
        }).collect();
        
        let services = config.services.iter().map(|entry| Service {
            name: entry.name.clone(),
            action: entry.action.clone(),
            status: "Unknown".to_string(),
        }).collect();
        
        (detours, includes, services)
    }
    
    pub fn time_ago(secs: u64) -> String {
        let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();
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
        use crate::operations::config_ops;
        let config = config_ops::load_config(&self.config_path);
        
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
        self.includes = config.includes.iter().map(|entry| {
            let file_info = self.detour_manager.get_file_info(&entry.include_file);
            Include {
                target: entry.target.clone(),
                include_file: entry.include_file.clone(),
                active: entry.enabled,
                size: file_info.as_ref().map(|f| f.size).unwrap_or(0),
                modified: Self::time_ago(file_info.as_ref().map(|f| f.modified_secs).unwrap_or(0)),
            }
            }).collect();
            
            // Reload services
            self.services = config.services.iter().map(|entry| Service {
                name: entry.name.clone(),
                action: entry.action.clone(),
                status: "Unknown".to_string(),
            }).collect();
            
            self.add_toast("Config reloaded".to_string(), ToastType::Success);
    }
    
    pub fn apply_all_detours(&mut self) {
        match self.detour_manager.apply_all() {
            Ok(_) => {
                self.reload_config();
            }
            Err(e) => {
                self.show_error("Apply Error".to_string(), format!("Failed to apply detours: {}", e));
            }
        }
    }
    
    pub fn is_modal_visible(&self) -> bool {
        self.popup.is_some() || 
        self.file_browser.is_some() || 
        self.validation_report.is_some() || 
        self.diff_viewer.is_some()
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
    
    pub fn add_toast(&mut self, message: String, toast_type: ToastType) {
        self.toasts.push(Toast {
            message,
            toast_type,
            shown_at: SystemTime::now(),
        });
    }
    
    pub fn show_error(&mut self, title: String, message: String) {
        self.popup = Some(Popup::Error { title, message });
    }
    
    pub fn close_popup(&mut self) {
        self.popup = None;
        self.pending_action = None;
    }
    
    pub fn show_diff(&mut self, left: &str, right: &str) {
        match DiffViewer::new(left.to_string(), right.to_string()) {
            Ok(viewer) => {
                self.diff_viewer = Some(viewer);
            }
            Err(e) => {
                self.show_error("Diff Error".to_string(), format!("Failed to open diff: {}", e));
            }
        }
    }
    
    pub fn close_diff(&mut self) {
        self.diff_viewer = None;
    }
    
    pub fn scroll_diff_up(&mut self) {
        if let Some(ref mut diff) = self.diff_viewer {
            if diff.scroll_offset > 0 {
                diff.scroll_offset -= 1;
            }
        }
    }
    
    pub fn scroll_diff_down(&mut self) {
        if let Some(ref mut diff) = self.diff_viewer {
            diff.scroll_offset += 1;
        }
    }
    
    pub fn scroll_diff_page_up(&mut self) {
        if let Some(ref mut diff) = self.diff_viewer {
            diff.scroll_offset = diff.scroll_offset.saturating_sub(10);
        }
    }
    
    pub fn scroll_diff_page_down(&mut self) {
        if let Some(ref mut diff) = self.diff_viewer {
            diff.scroll_offset += 10;
        }
    }
    
    pub fn handle_popup_left(&mut self) {
        if let Some(Popup::Confirm { selected, .. }) = &mut self.popup {
            if *selected > 0 {
                *selected -= 1;
            }
        }
    }
    
    pub fn handle_popup_right(&mut self) {
        if let Some(Popup::Confirm { selected, .. }) = &mut self.popup {
            if *selected < 1 {
                *selected += 1;
            }
        }
    }
    
    pub fn handle_popup_input(&mut self, c: char) {
        if let Some(Popup::Input { input, cursor_pos, .. }) = &mut self.popup {
            input.insert(*cursor_pos.min(&mut input.len()), c);
            *cursor_pos += 1;
        }
    }
    
    pub fn handle_popup_backspace(&mut self) {
        if let Some(Popup::Input { input, cursor_pos, .. }) = &mut self.popup {
            if *cursor_pos > 0 && *cursor_pos <= input.len() {
                input.remove(*cursor_pos - 1);
                *cursor_pos -= 1;
            }
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
                if self.selected_action > 0 {
                    self.selected_action -= 1;
                    self.action_state.select(Some(self.selected_action));
                }
            }
            ActiveColumn::Content => {
                match self.view_mode {
                    ViewMode::DetoursList => {
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
                if self.selected_view < self.views.len().saturating_sub(1) {
                    self.selected_view += 1;
                    self.view_state.select(Some(self.selected_view));
                }
            }
            ActiveColumn::Actions => {
                let actions = self.get_current_actions();
                if self.selected_action < actions.len().saturating_sub(1) {
                    self.selected_action += 1;
                    self.action_state.select(Some(self.selected_action));
                }
            }
            ActiveColumn::Content => {
                match self.view_mode {
                    ViewMode::DetoursList => {
                        if self.selected_detour < self.detours.len().saturating_sub(1) {
                            self.selected_detour += 1;
                            self.detour_state.select(Some(self.selected_detour));
                        }
                    }
                    ViewMode::IncludesList => {
                        if self.selected_include < self.includes.len().saturating_sub(1) {
                            self.selected_include += 1;
                            self.include_state.select(Some(self.selected_include));
                        }
                    }
                    ViewMode::ServicesList => {
                        if self.selected_service < self.services.len().saturating_sub(1) {
                            self.selected_service += 1;
                            self.service_state.select(Some(self.selected_service));
                        }
                    }
                    _ => {}
                }
            }
        }
    }
    
    pub fn navigate_prev_column(&mut self) {
        match self.active_column {
            ActiveColumn::Views => {}
            ActiveColumn::Actions => {
                self.active_column = ActiveColumn::Views;
            }
            ActiveColumn::Content => {
                self.active_column = ActiveColumn::Actions;
            }
        }
    }
    
    pub fn navigate_next_column(&mut self) {
        match self.active_column {
            ActiveColumn::Views => {
                self.active_column = ActiveColumn::Actions;
            }
            ActiveColumn::Actions => {
                self.active_column = ActiveColumn::Content;
            }
            ActiveColumn::Content => {}
        }
    }
    
    pub fn handle_enter(&mut self) {
        match self.active_column {
            ActiveColumn::Views => {
                self.select_view();
            }
            ActiveColumn::Actions => {
                self.handle_action_select();
            }
            ActiveColumn::Content => {
                // Content-specific enter handling
            }
        }
    }
    
    pub fn select_view(&mut self) {
        match self.selected_view {
            0 => self.view_mode = ViewMode::DetoursList,
            1 => self.view_mode = ViewMode::IncludesList,
            2 => self.view_mode = ViewMode::ServicesList,
            3 => self.view_mode = ViewMode::StatusOverview,
            4 => self.view_mode = ViewMode::LogsLive,
            5 => self.view_mode = ViewMode::ConfigEdit,
            _ => {}
        }
        self.active_column = ActiveColumn::Actions;
        self.selected_action = 0;
        self.action_state.select(Some(0));
    }
    
    pub fn get_current_actions(&self) -> Vec<String> {
        match self.view_mode {
            ViewMode::DetoursList => vec!["List".to_string(), "Add".to_string(), "Validate".to_string(), "Apply All".to_string()],
            ViewMode::IncludesList => vec!["List".to_string(), "Add".to_string()],
            ViewMode::ServicesList => vec!["List".to_string()],
            ViewMode::StatusOverview => vec!["Overview".to_string()],
            ViewMode::LogsLive => vec!["Logs".to_string()],
            ViewMode::ConfigEdit => vec!["Edit".to_string()],
            _ => vec![],
        }
    }
    
    pub fn handle_action_select(&mut self) {
        if self.active_column == ActiveColumn::Actions {
            let action = self.get_current_actions()[self.selected_action].clone();
            match action.as_str() {
                "Add" => {
                    if self.view_mode == ViewMode::DetoursList {
                    self.view_mode = ViewMode::DetoursAdd;
                        self.add_form = AddDetourForm::default();
                    self.active_column = ActiveColumn::Content;
                    } else if self.view_mode == ViewMode::IncludesList {
                    self.view_mode = ViewMode::IncludesAdd;
                        self.include_form = AddIncludeForm {
                            target_path: "/boot/firmware/config.txt".to_string(),
                            include_path: "/home/pi/_playground/root/boot/firmware-config.txt".to_string(),
                            description: String::new(),
                            active_field: 0,
                            cursor_pos: 0,
                            editing_index: None,
                    };
                    self.active_column = ActiveColumn::Content;
                    }
                }
                "Validate" => {
                        self.validate_detours_all();
                }
                "Apply All" => {
                    self.apply_all_detours();
                }
                _ => {}
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
                        
                        let result = if new_state {
                            self.detour_manager.apply_detour(&original, &custom)
                        } else {
                            self.detour_manager.remove_detour(&original)
                        };
                        
                        match result {
                            Ok(msg) => {
                                detour.active = new_state;
                                
                                use crate::operations::config_ops;
                                let _ = config_ops::with_config_mut(&self.config_path, |config| {
                                    if let Some(entry) = config.detours.iter_mut().find(|e| e.original == original) {
                                        entry.enabled = new_state;
                                    }
                                    Ok(())
                                });
                                
                                let action = if new_state { "Activated" } else { "Deactivated" };
                                self.add_log("INFO", &msg);
                                self.add_toast(format!("{} detour", action), ToastType::Success);
                            }
                            Err(err) => {
                                self.show_error("Mount Error".to_string(), format!("Failed to toggle detour: {}", err));
                            }
                        }
                    }
                }
                ViewMode::IncludesList => {
                    if let Some(include) = self.includes.get_mut(self.selected_include) {
                        let new_state = !include.active;
                        let target = include.target.clone();
                        let include_file = include.include_file.clone();
                        
                        let result = if new_state {
                            self.include_manager.apply(
                                std::path::Path::new(&target),
                                std::path::Path::new(&include_file)
                            )
                        } else {
                            self.include_manager.remove(
                                std::path::Path::new(&target),
                                std::path::Path::new(&include_file)
                            )
                        };
                        
                        match result {
                            Ok(_) => {
                                include.active = new_state;
                                
                                use crate::operations::config_ops;
                                let _ = config_ops::with_config_mut(&self.config_path, |config| {
                                    if let Some(entry) = config.includes.iter_mut().find(|e| e.target == target) {
                                        entry.enabled = new_state;
                                    }
                                    Ok(())
                                });
                                
                                let action = if new_state { "Activated" } else { "Deactivated" };
                                self.add_log("INFO", &format!("{} include: {}", action, target));
                                self.add_toast(format!("{} include", action), ToastType::Success);
                            }
                            Err(err) => {
                                self.show_error("Include Error".to_string(), format!("Failed to toggle include: {}", err));
                            }
                        }
                    }
                }
                _ => {}
            }
        }
    }

    // Includes add form methods
    pub fn includes_form_handle_char(&mut self, c: char) {
        let field = match self.include_form.active_field { 
            0 => &mut self.include_form.target_path, 
            1 => &mut self.include_form.include_path, 
            2 => &mut self.include_form.description, 
            _ => return 
        };
        crate::forms::base::handle_char(field, &mut self.include_form.cursor_pos, c);
    }
    pub fn includes_form_backspace(&mut self) {
        let field = match self.include_form.active_field { 
            0 => &mut self.include_form.target_path, 
            1 => &mut self.include_form.include_path, 
            2 => &mut self.include_form.description, 
            _ => return 
        };
        crate::forms::base::handle_backspace(field, &mut self.include_form.cursor_pos);
    }
    pub fn includes_form_move_cursor_left(&mut self) {
        crate::forms::base::move_cursor_left(&mut self.include_form.cursor_pos);
    }
    pub fn includes_form_move_cursor_right(&mut self) {
        let len = match self.include_form.active_field { 
            0 => self.include_form.target_path.len(), 
            1 => self.include_form.include_path.len(), 
            2 => self.include_form.description.len(), 
            _ => 0 
        };
        crate::forms::base::move_cursor_right(len, &mut self.include_form.cursor_pos);
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
        use crate::validation;
        if let Err(e) = validation::validate_fields_not_empty(&[
            (&target, "Target path"),
            (&include, "Include path"),
        ]) {
            self.show_error("Validation Error".to_string(), e);
            return;
        }
        // If include file doesn't exist, prompt to create it
        use crate::operations::file_ops;
        if !file_ops::file_exists(std::path::Path::new(&include)) {
            self.popup = Some(crate::popup::Popup::Confirm {
                title: "Create Include File?".to_string(),
                message: format!("The include file does not exist.\n\n{}\n\nCreate it now? (It will be populated with the contents of the target file)", include),
                selected: 0,
            });
            self.pending_action = Some(PendingAction::CreateIncludeFileAndSave);
            return;
        }
        use crate::operations::config_ops;
        
        let target_clone = target.clone();
        let include_clone = include.clone();
        let description_clone = description.clone();
        let edit_idx = self.include_form.editing_index;
        
        match config_ops::with_config_mut(&self.config_path, |config| {
            // Check if we're editing or adding
            if let Some(edit_idx) = edit_idx {
                // Edit existing include
                if let Some(entry) = config.includes.get_mut(edit_idx) {
                    entry.target = target_clone.clone();
                    entry.include_file = include_clone.clone();
                    entry.description = if description_clone.is_empty() { None } else { Some(description_clone.clone()) };
                }
            } else {
                // Add new include (active by default)
                config.includes.push(crate::config::IncludeEntry { target: target_clone.clone(), include_file: include_clone.clone(), description: if description_clone.is_empty() { None } else { Some(description_clone.clone()) }, enabled: true });
            }
            Ok(())
        }) {
            Ok(_) => {
            let action = if self.include_form.editing_index.is_some() {
                "Include updated"
            } else {
                "Include added"
            };
            
            // Reload config to refresh the list with the new include
            self.reload_config();
            
            // After reloading, activate the include if it was newly created and enabled
            if !self.include_form.editing_index.is_some() {
                // Only for new includes - find it in the list and activate it (since enabled: true by default)
                let include_file_str = include.clone();
                if let Some(include_item) = self.includes.iter_mut().find(|i| i.target == target && i.include_file == include_file_str) {
                    if !include_item.active {
                        // Activate it using the same logic as space key toggle
                        use std::path::Path;
                        let target_path = Path::new(&target);
                        let include_path = Path::new(&include);
                        if let Err(e) = self.include_manager.apply(target_path, include_path) {
                            self.add_log("WARN", &format!("Failed to apply include to target: {}", e));
                        } else {
                            include_item.active = true;
                            self.add_log("INFO", &format!("Applied include to target: {}", target));
                        }
                    }
                }
            }
            
                self.add_toast(action.to_string(), ToastType::Success);
            self.view_mode = ViewMode::IncludesList;
            self.active_column = ActiveColumn::Content;
            }
            Err(e) => {
                self.show_error("Save Error".to_string(), e);
            }
        }
    }

    pub fn create_include_file_and_save(&mut self) {
        use std::path::Path;
        use crate::operations::file_ops;
        
        let target = self.include_form.target_path.trim().to_string();
        let include = self.include_form.include_path.trim().to_string();
        
        let target_path = Path::new(&target);
        let include_path = Path::new(&include);
        
        // Duplicate file (happens BEFORE adding include directive)
        match file_ops::duplicate_file(target_path, include_path) {
            Ok(contents) => {
                if !contents.is_empty() {
                    self.add_log("INFO", &format!("Copied contents from target to include file: {}", target));
                }
                self.add_log("INFO", &format!("Created include file: {}", include));
                
                // Now save to config (which will apply the include directive AFTER duplication is complete)
                self.save_include_to_config();
            }
            Err(e) => {
                self.show_error("Create File Error".to_string(), e);
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
        let current_text = match self.include_form.active_field { 
            0 => &self.include_form.target_path, 
            1 => &self.include_form.include_path, 
            2 => { self.includes_form_next_field(); return; }, 
            _ => return 
        };
        
        if let Some(completed) = crate::forms::base::complete_path_tab(current_text) {
                match self.include_form.active_field {
                0 => { 
                    self.include_form.target_path = completed.clone(); 
                    self.include_form.cursor_pos = completed.len(); 
                }
                1 => { 
                    self.include_form.include_path = completed.clone(); 
                    self.include_form.cursor_pos = completed.len(); 
                }
                _ => {}
            }
        } else {
            self.includes_form_next_field();
        }
    }
    pub fn includes_form_paste_clipboard(&mut self) {
        if let Some(text) = crate::forms::base::paste_clipboard() {
                match self.include_form.active_field {
                0 => { 
                    self.include_form.target_path.push_str(&text); 
                    self.include_form.cursor_pos = self.include_form.target_path.len(); 
                }
                1 => { 
                    self.include_form.include_path.push_str(&text); 
                    self.include_form.cursor_pos = self.include_form.include_path.len(); 
                }
                _ => {}
            }
        }
    }

    pub fn handle_input_submit(&mut self, value: String) {
        if let Some(ctx) = self.input_context.clone() {
            match ctx {
                InputContext::AddIncludeTarget => {
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
                    use crate::operations::config_ops;
                    if let Err(e) = config_ops::with_config_mut(&self.config_path, |config| {
                    config.includes.push(crate::config::IncludeEntry {
                        target: target.clone(),
                        include_file: include_file.clone(),
                        description: None,
                        enabled: false,
                    });
                        Ok(())
                    }) {
                        self.show_error("Save Error".to_string(), e);
                        } else {
                            self.add_log("SUCCESS", &format!("Added include: {} -> {}", target, include_file));
                            self.add_toast("Include added".to_string(), ToastType::Success);
                            self.reload_config();
                    }
                    self.input_context = None;
                }
            }
        }
    }
    
    pub fn delete_selected_include(&mut self) {
        if let Some(_include) = self.includes.get(self.selected_include) {
            self.pending_action = Some(PendingAction::DeleteInclude(self.selected_include));
            self.popup = Some(crate::popup::Popup::Confirm {
                title: "Confirm Delete".to_string(),
                message: format!("Delete this include?\n\n{} ← {}", self.includes[self.selected_include].target, self.includes[self.selected_include].include_file),
                selected: 1,
            });
        }
    }

    pub fn confirm_delete_include(&mut self, index: usize) {
        use std::path::Path;
        
        // Check if include is active in app state before removing from config
        let was_active = self.includes.get(index).map(|i| i.active).unwrap_or(false);
        let target_path_str = if index < self.includes.len() {
            self.includes[index].target.clone()
                        } else {
            return;
        };
        let include_file_path_str = if index < self.includes.len() {
            self.includes[index].include_file.clone()
        } else {
            return;
        };
        
        // Load config
        let mut config = crate::operations::config_ops::load_config(&self.config_path);
        if index < config.includes.len() {
            // Remove from config
            let _removed = config.includes.remove(index);
            
            // If include was active, disable it first (remove include directive)
            if was_active {
                let target_path = Path::new(&target_path_str);
                let include_path = Path::new(&include_file_path_str);
                if let Err(e) = self.include_manager.remove(target_path, include_path) {
                    self.add_log("WARN", &format!("Failed to remove include directive: {}", e));
                } else {
                    self.add_log("INFO", &format!("Disabled include before deletion: {}", target_path_str));
                }
            }
            
            // Save config first (include already removed from config)
            let include_file_path = include_file_path_str.clone();
            
            use crate::operations::config_ops;
            if let Err(e) = config_ops::save_config(&self.config_path, &config) {
                self.show_error("Save Error".to_string(), e);
                return;
            }
            
                // Check if include file exists and prompt to remove it
                use crate::operations::file_ops;
                if file_ops::file_exists(Path::new(&include_file_path)) {
                    // Prompt to delete include file
                    self.pending_action = Some(PendingAction::DeleteIncludeAndFile(index, include_file_path.clone()));
                    self.popup = Some(crate::popup::Popup::Confirm {
                        title: "Delete Include File?".to_string(),
                        message: format!("The include file still exists:\n\n{}\n\nDelete it as well?", include_file_path),
                        selected: 1, // Default to "No" for safety
                    });
                    // Log that include was deleted, file deletion pending
                    self.add_log("SUCCESS", &format!("Deleted include: {}", target_path_str));
                    return;
                }
                
                // No include file, complete deletion
                self.add_log("SUCCESS", &format!("Deleted include: {}", target_path_str));
                self.add_toast("Include deleted successfully!".to_string(), ToastType::Success);
                self.reload_config();
                self.adjust_selection_after_delete_include();
        }
    }
    
    // Delete include and optionally the include file
    pub fn delete_include_and_file(&mut self, _index: usize, include_file_path: String, delete_file: bool) {
        use std::path::Path;
        use crate::operations::file_ops;
        
        // Delete the include file if requested
        if delete_file {
            let file_path = Path::new(&include_file_path);
            match file_ops::delete_file(file_path) {
                Ok(_) => {
                    self.add_log("INFO", &format!("Deleted include file: {}", include_file_path));
                    self.add_toast("Include file deleted".to_string(), ToastType::Success);
                }
                Err(e) => {
                    self.show_error("File Deletion Error".to_string(), e);
                }
            }
        }
        
        // Reload config to reflect changes
        self.reload_config();
        
        // Adjust selection if needed
        self.adjust_selection_after_delete_include();
    }
    
    pub fn edit_selected_include(&mut self) {
        if let Some(include) = self.includes.get(self.selected_include) {
            // Load config to get description
            use crate::operations::config_ops;
            let config = config_ops::load_config(&self.config_path);
            let description = config.includes.get(self.selected_include)
                .and_then(|e| e.description.clone())
                .unwrap_or_default();
            
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
    
    pub fn edit_selected_detour(&mut self) {
        if let Some(detour) = self.detours.get(self.selected_detour) {
            // Load config to get description
            use crate::operations::config_ops;
            let config = config_ops::load_config(&self.config_path);
            let description = config.detours.get(self.selected_detour)
                .and_then(|e| e.description.clone())
                .unwrap_or_default();
            
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
    
    pub fn delete_selected_detour(&mut self) {
        if let Some(_detour) = self.detours.get(self.selected_detour) {
            // Show confirmation popup
            self.pending_action = Some(PendingAction::DeleteDetour(self.selected_detour));
        }
    }

    pub fn confirm_delete_detour(&mut self, index: usize) {
        use std::path::Path;
        
        // Check if detour is active in app state before removing from config
        let was_active = self.detours.get(index).map(|d| d.active).unwrap_or(false);
        let original_path_str = if index < self.detours.len() {
            self.detours[index].original.clone()
        } else {
            return;
        };
        
        // If detour was active, disable it first (unmount)
        if was_active {
            if let Err(e) = self.detour_manager.remove_detour(&original_path_str) {
                self.add_log("WARN", &format!("Failed to unmount detour: {}", e));
            } else {
                self.add_log("INFO", &format!("Disabled detour before deletion: {}", original_path_str));
            }
        }
        
        // Load config
        let mut config = crate::operations::config_ops::load_config(&self.config_path);
        
        // Remove the detour
        if index < config.detours.len() {
            let removed = config.detours.remove(index);
            
            // Save config first (detour already removed from config)
            let custom_path = removed.custom.clone();
            let original_path = removed.original.clone();
            
            use crate::operations::config_ops;
            match config_ops::save_config(&self.config_path, &config) {
                Ok(_) => {
                    // Check if custom file exists and prompt to remove it
                    use crate::operations::file_ops;
                    if file_ops::file_exists(Path::new(&custom_path)) {
                        // Prompt to delete custom file
                        self.pending_action = Some(PendingAction::DeleteDetourAndFile(index, custom_path.clone()));
                        self.popup = Some(crate::popup::Popup::Confirm {
                            title: "Delete Custom File?".to_string(),
                            message: format!("The custom file still exists:\n\n{}\n\nDelete it as well?", custom_path),
                            selected: 1, // Default to "No" for safety
                        });
                        // Log that detour was deleted, file deletion pending
                        self.add_log("SUCCESS", &format!("Deleted detour: {}", original_path));
                        return;
                    }
                    
                    // No custom file, complete deletion
                    self.add_log("SUCCESS", &format!("Deleted detour: {}", original_path));
                    self.add_toast("Detour deleted successfully!".to_string(), ToastType::Success);
                    
                    // Reload config
                    self.reload_config();
                    
                    self.adjust_selection_after_delete_detour();
                }
            Err(e) => {
                self.show_error("Save Error".to_string(), e);
                return;
            }
            }
        }
    }
    
    pub fn delete_detour_and_file(&mut self, _index: usize, custom_path: String, delete_file: bool) {
        use std::path::Path;
        use crate::operations::file_ops;
        
        // Delete the custom file if requested
        if delete_file {
            let file_path = Path::new(&custom_path);
            match file_ops::delete_file(file_path) {
                Ok(_) => {
                    self.add_log("INFO", &format!("Deleted custom file: {}", custom_path));
                    self.add_toast("Custom file deleted".to_string(), ToastType::Success);
                }
                Err(e) => {
                    self.show_error("File Deletion Error".to_string(), e);
                }
            }
        }
        
        // Reload config to reflect changes
        self.reload_config();
        
        self.adjust_selection_after_delete_detour();
    }
    
    pub fn form_handle_char(&mut self, c: char) {
        let field = match self.add_form.active_field {
            0 => &mut self.add_form.original_path,
            1 => &mut self.add_form.custom_path,
            2 => &mut self.add_form.description,
            _ => return,
        };
        crate::forms::base::handle_char(field, &mut self.add_form.cursor_pos, c);
    }
    
    pub fn form_handle_backspace(&mut self) {
        let field = match self.add_form.active_field {
            0 => &mut self.add_form.original_path,
            1 => &mut self.add_form.custom_path,
            2 => &mut self.add_form.description,
            _ => return,
        };
        crate::forms::base::handle_backspace(field, &mut self.add_form.cursor_pos);
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
        use crate::validation;
        if let Err(e) = validation::validate_fields_not_empty(&[
            (&self.add_form.original_path, "Original path"),
            (&self.add_form.custom_path, "Custom path"),
        ]) {
            self.show_error("Validation Error".to_string(), e);
            return;
        }
        
        // Check if custom file exists
        use crate::operations::file_ops;
        let custom_path = Path::new(&self.add_form.custom_path);
        if !file_ops::file_exists(custom_path) {
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
        use crate::config::DetourEntry;
        use crate::operations::config_ops;
        
        match config_ops::with_config_mut(&self.config_path, |config| {
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
            Ok(())
        }) {
            Ok(_) => {
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
                self.show_error("Save Error".to_string(), e);
            }
        }
    }
    
    pub fn create_custom_file_and_save(&mut self) {
        use std::path::Path;
        use crate::operations::file_ops;
        
        let original_path = Path::new(&self.add_form.original_path);
        let custom_path = Path::new(&self.add_form.custom_path);
        
        match file_ops::duplicate_file(original_path, custom_path) {
            Ok(contents) => {
                if !contents.is_empty() {
                    self.add_log("INFO", &format!("Copied contents from: {}", self.add_form.original_path));
                }
        self.add_log("INFO", &format!("Created file: {}", self.add_form.custom_path));
        
        // Now save the detour
        self.save_detour_to_config();
            }
            Err(e) => {
                self.show_error("File Creation Error".to_string(), e);
            }
        }
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
    
    pub fn validate_detours_all(&mut self) {
        use std::time::Instant;
        use std::path::Path;
        
        let start = Instant::now();
        let mut results = vec![];
        
        let phase1_start = Instant::now();
        let mut missing_original = 0;
        let mut missing_custom = 0;
        let mut unreadable = 0;
        
        for detour in &self.detours {
            let original_path = Path::new(&detour.original);
            let custom_path = Path::new(&detour.custom);
            
            if !original_path.exists() { missing_original += 1; }
            if !custom_path.exists() { missing_custom += 1; }
            
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
            "Phase 1: File Existence Check ({:.2}ms)\n  {} missing original files\n  {} missing custom files\n  {} unreadable files",
            phase1_time.as_secs_f64()*1000.0,
            missing_original,
            missing_custom,
            unreadable
        ));
        
        let phase2_start = Instant::now();
        let active_count = self.detours.iter().filter(|d| d.active).count();
        let phase2_time = phase2_start.elapsed();
        results.push(format!(
            "Phase 2: State Validation ({:.2}ms)\n  {} active detours",
            phase2_time.as_secs_f64()*1000.0,
            active_count
        ));
        
        let phase3_start = Instant::now();
        let mut conflicts = 0;
        for i in 0..self.detours.len() {
            for j in (i+1)..self.detours.len() {
                if self.detours[i].original == self.detours[j].original {
                    conflicts += 1;
                }
            }
        }
        let phase3_time = phase3_start.elapsed();
        results.push(format!(
            "Phase 3: Conflict Detection ({:.2}ms)\n  {} conflicting detours",
            phase3_time.as_secs_f64()*1000.0,
            conflicts
        ));
        
        let total_time = start.elapsed();
        let has_issues = missing_original > 0 || missing_custom > 0 || unreadable > 0 || conflicts > 0;
        
        self.validation_report = Some(ValidationReport {
            content: results.join("\n\n"),
            has_issues,
        });
        
        if has_issues {
            self.add_log("WARN", &format!("Validation found issues ({}ms)", total_time.as_secs_f64()*1000.0));
        } else {
            self.add_log("SUCCESS", &format!("All detours validated successfully ({}ms)", total_time.as_secs_f64()*1000.0));
        }
    }
    
    pub fn validate_single_detour(&self, index: usize) -> String {
        use std::path::Path;

        if let Some(detour) = self.detours.get(index) {
        let original_path = Path::new(&detour.original);
        let custom_path = Path::new(&detour.custom);
            
            let missing_original = if !original_path.exists() { 1 } else { 0 };
            let missing_custom = if !custom_path.exists() { 1 } else { 0 };
        let mut unreadable = 0;
        if original_path.exists() && std::fs::metadata(&detour.original).is_err() { unreadable += 1; }
        if custom_path.exists() && std::fs::metadata(&detour.custom).is_err() { unreadable += 1; }
            let phase1_time = std::time::Instant::now().elapsed();
            format!(
                "Validation ({:.2}ms)\n  {} missing original\n  {} missing custom\n  {} unreadable",
                phase1_time.as_secs_f64()*1000.0,
            missing_original,
            missing_custom,
            unreadable
            )
            } else {
            "Invalid index".to_string()
        }
    }
    
    pub fn form_complete_path(&mut self) {
        let current_text = match self.add_form.active_field {
            0 => &self.add_form.original_path,
            1 => &self.add_form.custom_path,
            _ => return, // Don't complete description field
        };
        
        if let Some(completed) = crate::forms::base::complete_path_tab(current_text) {
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
        }
    }
    
    pub fn form_paste_clipboard(&mut self) {
        if let Some(text) = crate::forms::base::paste_clipboard() {
                // Insert clipboard text at cursor position
                for c in text.chars() {
                    self.form_handle_char(c);
            }
        }
    }
    
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
    
    // Helper: Adjust selection after deleting an include
    fn adjust_selection_after_delete_include(&mut self) {
        if self.selected_include >= self.includes.len() && self.selected_include > 0 {
            self.selected_include -= 1;
            self.include_state.select(Some(self.selected_include));
        }
    }
    
    // Helper: Adjust selection after deleting a detour
    fn adjust_selection_after_delete_detour(&mut self) {
        if self.selected_detour >= self.detours.len() && self.selected_detour > 0 {
            self.selected_detour -= 1;
            self.detour_state.select(Some(self.selected_detour));
        }
    }
    
    pub fn status_icon(&self) -> &str {
        // Simple status - could be enhanced later
        "✓"
    }
    
    pub fn active_detours_count(&self) -> usize {
        self.detours.iter().filter(|d| d.active).count()
    }
    
    pub fn get_current_description(&self) -> String {
        match self.view_mode {
            ViewMode::DetoursList => "Manage file overlays (detours)".to_string(),
            ViewMode::DetoursAdd => "Add a new detour".to_string(),
            ViewMode::DetoursEdit => "Edit detour".to_string(),
            ViewMode::IncludesList => "Manage file includes".to_string(),
            ViewMode::IncludesAdd => "Add a new include".to_string(),
            ViewMode::ServicesList => "Manage services".to_string(),
            ViewMode::StatusOverview => "System status overview".to_string(),
            ViewMode::LogsLive => "Live log output".to_string(),
            ViewMode::ConfigEdit => "Edit configuration".to_string(),
        }
    }
    
    pub fn close_validation_report(&mut self) {
        self.validation_report = None;
    }
    
    pub fn validate_single_include(&self, _index: usize) -> String {
        // Placeholder - could implement actual validation later
        "Validation not implemented".to_string()
    }
}

impl Default for App {
    fn default() -> Self {
        Self::new()
    }
}
