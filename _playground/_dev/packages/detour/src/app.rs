// Application state management

use ratatui::widgets::ListState;
use crate::manager::DetourManager;
use crate::injection::InjectionManager;
use crate::mirror::MirrorManager;
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

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ViewMode {
    DetoursList,
    DetoursAdd,
    DetoursEdit,
    InjectionsAdd,
    InjectionsList,
    MirrorsList,
    MirrorsAdd,
    MirrorsEdit,
    ServicesList,
    StatusOverview,
    LogsLive,
    ConfigEdit,
}

/// Actions for unified form handling
#[derive(Debug, Clone, Copy)]
pub enum FormAction {
    Char(char),
    Backspace,
    CursorLeft,
    CursorRight,
    NextField,
    PrevField,
    CompletePath,
    PasteClipboard,
    Cancel,
    Submit,
    OpenFileBrowser,
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
pub struct Injection {
    pub target: String,
    pub include_file: String,
    pub active: bool,
    pub size: u64,
    pub modified: String,
}

#[derive(Debug, Clone)]
pub struct Mirror {
    pub source: String,
    pub target: String,
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
pub struct AddInjectionForm {
    pub target_path: String,
    pub include_path: String,
    pub description: String,
    pub active_field: usize,
    pub cursor_pos: usize,
    pub editing_index: Option<usize>,
}

#[derive(Debug, Clone)]
pub struct AddMirrorForm {
    pub source_path: String,
    pub target_path: String,
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
    DeleteInjection(usize),
    DeleteInjectionAndFile(usize, String),
    CreateInjectionFileAndSave,
    DeleteMirror(usize),
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

impl Default for AddInjectionForm {
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
    pub selected_injection: usize,
    pub selected_mirror: usize,
    pub selected_service: usize,
    
    pub view_state: ListState,
    pub action_state: ListState,
    pub detour_state: ListState,
    pub injection_state: ListState,
    pub mirror_state: ListState,
    pub service_state: ListState,
    
    pub views: Vec<String>,
    pub detours: Vec<Detour>,
    pub injections: Vec<Injection>,
    pub mirrors: Vec<Mirror>,
    pub services: Vec<Service>,
    pub logs: Vec<LogEntry>,
    pub profile: String,
    pub toasts: Vec<Toast>,
    pub popup: Option<Popup>,
    pub diff_viewer: Option<DiffViewer>,
    pub validation_report: Option<ValidationReport>,
    
    pub detour_manager: DetourManager,
    pub injection_manager: InjectionManager,
    pub mirror_manager: MirrorManager,
    pub config_path: String,
    
    pub add_form: AddDetourForm,
    pub injection_form: AddInjectionForm,
    pub mirror_form: AddMirrorForm,
    pub pending_action: Option<PendingAction>,
    pub file_browser: Option<crate::filebrowser::FileBrowser>,
}

impl App {
    pub fn new() -> Self {
        let config_path = "/home/pi/.detour.yaml".to_string();
        let detour_manager = DetourManager::new();
        let injection_manager = InjectionManager::new();
        let mirror_manager = MirrorManager::new();
        
        let (detours, injections, mirrors, services) = Self::load_initial_config(&config_path, &detour_manager, &mirror_manager);
        
        Self {
            should_quit: false,
            active_column: ActiveColumn::Views,
            view_mode: ViewMode::DetoursList,
            
            selected_view: 0,
            selected_action: 0,
            selected_detour: 0,
            selected_injection: 0,
            selected_mirror: 0,
            selected_service: 0,
            
            view_state: {
                let mut state = ListState::default();
                state.select(Some(0));
                state
            },
            action_state: {
                let mut state = ListState::default();
                state.select(Some(0));
                state
            },
            detour_state: {
                let mut state = ListState::default();
                state.select(Some(0));
                state
            },
            injection_state: {
                let mut state = ListState::default();
                state.select(Some(0));
                state
            },
            mirror_state: {
                let mut state = ListState::default();
                state.select(Some(0));
                state
            },
            service_state: {
                let mut state = ListState::default();
                state.select(Some(0));
                state
            },
            
            views: vec![
                "Detours".to_string(),
                "Injections".to_string(),
                "Mirrors".to_string(),
                "Services".to_string(),
                "Status".to_string(),
                "Logs".to_string(),
            ],
            detours,
            injections,
            mirrors,
            services,
            logs: vec![],
            profile: "dev".to_string(),
            toasts: vec![],
            popup: None,
            diff_viewer: None,
            validation_report: None,
            
            detour_manager,
            injection_manager,
            mirror_manager,
            config_path,
            
            add_form: AddDetourForm::default(),
            injection_form: AddInjectionForm::default(),
            mirror_form: AddMirrorForm::default(),
            pending_action: None,
            file_browser: None,
        }
    }
    
    fn load_initial_config(config_path: &str, detour_manager: &DetourManager, mirror_manager: &MirrorManager) -> (Vec<Detour>, Vec<Injection>, Vec<Mirror>, Vec<Service>) {
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
        
        let injections = config.injections.iter().map(|entry| {
            let file_info = detour_manager.get_file_info(&entry.include_file);
            Injection {
                target: entry.target.clone(),
                include_file: entry.include_file.clone(),
                active: entry.enabled,
                size: file_info.as_ref().map(|f| f.size).unwrap_or(0),
                modified: Self::time_ago(file_info.as_ref().map(|f| f.modified_secs).unwrap_or(0)),
            }
        }).collect();
        
        let mirrors = config.mirrors.iter().map(|entry| {
            let file_info = mirror_manager.get_file_info(&entry.source);
            let is_active = mirror_manager.is_active(&entry.source, &entry.target);
            
            Mirror {
                source: entry.source.clone(),
                target: entry.target.clone(),
                active: is_active,
                size: file_info.as_ref().map(|f| f.size).unwrap_or(0),
                modified: Self::time_ago(file_info.as_ref().map(|f| f.modified_secs).unwrap_or(0)),
            }
        }).collect();
        
        let services = config.services.iter().map(|entry| Service {
            name: entry.name.clone(),
            action: entry.action.clone(),
            status: "Unknown".to_string(),
        }).collect();
        
        (detours, injections, mirrors, services)
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
        self.injections = config.injections.iter().map(|entry| {
            let file_info = self.detour_manager.get_file_info(&entry.include_file);
            Injection {
                target: entry.target.clone(),
                include_file: entry.include_file.clone(),
                active: entry.enabled,
                size: file_info.as_ref().map(|f| f.size).unwrap_or(0),
                modified: Self::time_ago(file_info.as_ref().map(|f| f.modified_secs).unwrap_or(0)),
            }
            }).collect();
            
            // Reload mirrors
            self.mirrors = config.mirrors.iter().map(|entry| {
                let file_info = self.mirror_manager.get_file_info(&entry.source);
                let is_active = self.mirror_manager.is_active(&entry.source, &entry.target);
                
                Mirror {
                    source: entry.source.clone(),
                    target: entry.target.clone(),
                    active: is_active,
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
            
            // Validate and sync all selections
            self.validate_all_selections();
            
            // Sync mirror list state
            if !self.mirrors.is_empty() {
                self.mirror_state.select(Some(self.selected_mirror));
            } else {
                self.mirror_state.select(None);
            }
            
            self.add_toast("Config reloaded".to_string(), ToastType::Success);
    }
    
    
    pub fn activate_all_detours(&mut self) {
        // Activate all inactive detours individually
        let mut activated_count = 0;
        let mut errors = Vec::new();
        
        for (idx, detour) in self.detours.iter_mut().enumerate() {
            if !detour.active {
                match self.detour_manager.apply_detour(&detour.original, &detour.custom) {
                    Ok(_) => {
                        detour.active = true;
                        activated_count += 1;
                        
                        // Update config to reflect enabled state
                        use crate::operations::config_ops;
                        let _ = config_ops::with_config_mut(&self.config_path, |config| {
                            if let Some(entry) = config.detours.get_mut(idx) {
                                entry.enabled = true;
                            }
                            Ok(())
                        });
                    }
                    Err(e) => {
                        errors.push(format!("{}: {}", detour.original, e));
                    }
                }
            }
        }
        
        if activated_count > 0 {
            self.add_log("INFO", &format!("Activated {} detour(s)", activated_count));
            self.add_toast(format!("Activated {} detour(s)", activated_count), ToastType::Success);
        }
        
        if !errors.is_empty() {
            let error_msg = format!("Failed to activate {} detour(s):\n{}", errors.len(), errors.join("\n"));
            self.show_error("Activation Error".to_string(), error_msg);
        }
        
        // Reload config to ensure UI is up to date
        self.reload_config();
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
                    // Sync view_mode when selection changes in Views column
                    self.sync_view_mode();
                }
            }
            ActiveColumn::Actions => {
                if self.selected_action > 0 {
                    self.selected_action -= 1;
                    self.action_state.select(Some(self.selected_action));
                }
            }
            ActiveColumn::Content => {
                self.navigate_content_up();
            }
        }
    }
    
    pub fn navigate_down(&mut self) {
        match self.active_column {
            ActiveColumn::Views => {
                if self.selected_view < self.views.len().saturating_sub(1) {
                    self.selected_view += 1;
                    self.view_state.select(Some(self.selected_view));
                    // Sync view_mode when selection changes in Views column
                    self.sync_view_mode();
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
                self.navigate_content_down();
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
                // Sync view_mode when entering Actions column
                self.sync_view_mode();
            }
            ActiveColumn::Actions => {
                self.active_column = ActiveColumn::Content;
                // view_mode already synced when we entered Actions
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
    
    /// Helper to convert selected_view index to ViewMode
    pub fn view_mode_from_index(index: usize) -> ViewMode {
        match index {
            0 => ViewMode::DetoursList,
            1 => ViewMode::InjectionsList,
            2 => ViewMode::MirrorsList,
            3 => ViewMode::ServicesList,
            4 => ViewMode::StatusOverview,
            5 => ViewMode::LogsLive,
            _ => ViewMode::DetoursList, // Default fallback
        }
    }
    
    /// Update view_mode to match selected_view - call this whenever selected_view changes
    fn sync_view_mode(&mut self) {
        self.view_mode = Self::view_mode_from_index(self.selected_view);
    }
    
    /// Sync selection state for detours
    fn sync_detour_selection(&mut self) {
        if !self.detours.is_empty() {
            self.selected_detour = self.selected_detour.min(self.detours.len() - 1);
            self.detour_state.select(Some(self.selected_detour));
        } else {
            self.selected_detour = 0;
            self.detour_state.select(None);
        }
    }
    
    /// Sync selection state for injections
    fn sync_injection_selection(&mut self) {
        if !self.injections.is_empty() {
            self.selected_injection = self.selected_injection.min(self.injections.len() - 1);
            self.injection_state.select(Some(self.selected_injection));
        } else {
            self.selected_injection = 0;
            self.injection_state.select(None);
        }
    }
    
    /// Sync selection state for mirrors
    fn sync_mirror_selection(&mut self) {
        if !self.mirrors.is_empty() {
            self.selected_mirror = self.selected_mirror.min(self.mirrors.len() - 1);
            self.mirror_state.select(Some(self.selected_mirror));
        } else {
            self.selected_mirror = 0;
            self.mirror_state.select(None);
        }
    }
    
    /// Sync selection state for services
    fn sync_service_selection(&mut self) {
        if !self.services.is_empty() {
            self.selected_service = self.selected_service.min(self.services.len() - 1);
            self.service_state.select(Some(self.selected_service));
        } else {
            self.selected_service = 0;
            self.service_state.select(None);
        }
    }
    
    /// Validate and sync all selection bounds
    fn validate_all_selections(&mut self) {
        self.sync_detour_selection();
        self.sync_injection_selection();
        self.sync_mirror_selection();
        self.sync_service_selection();
    }
    
    /// Navigate up in Content column based on current view mode
    fn navigate_content_up(&mut self) {
        match self.view_mode {
            ViewMode::DetoursList => {
                if self.selected_detour > 0 {
                    self.selected_detour -= 1;
                    self.detour_state.select(Some(self.selected_detour));
                }
            }
            ViewMode::InjectionsList => {
                if self.selected_injection > 0 {
                    self.selected_injection -= 1;
                    self.injection_state.select(Some(self.selected_injection));
                }
            }
            ViewMode::MirrorsList => {
                if self.selected_mirror > 0 {
                    self.selected_mirror -= 1;
                    self.mirror_state.select(Some(self.selected_mirror));
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
    
    /// Navigate down in Content column based on current view mode
    fn navigate_content_down(&mut self) {
        match self.view_mode {
            ViewMode::DetoursList => {
                if self.selected_detour < self.detours.len().saturating_sub(1) {
                    self.selected_detour += 1;
                    self.detour_state.select(Some(self.selected_detour));
                }
            }
            ViewMode::InjectionsList => {
                if self.selected_injection < self.injections.len().saturating_sub(1) {
                    self.selected_injection += 1;
                    self.injection_state.select(Some(self.selected_injection));
                }
            }
            ViewMode::MirrorsList => {
                if self.selected_mirror < self.mirrors.len().saturating_sub(1) {
                    self.selected_mirror += 1;
                    self.mirror_state.select(Some(self.selected_mirror));
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
    
    pub fn select_view(&mut self) {
        self.sync_view_mode();
        self.active_column = ActiveColumn::Actions;
        self.selected_action = 0;
        self.action_state.select(Some(0));
    }
    
    /// Helper to convert optional description string to Option<String>
    fn description_from_str(desc: &str) -> Option<String> {
        if desc.is_empty() {
            None
        } else {
            Some(desc.to_string())
        }
    }
    
    pub fn get_current_actions(&self) -> Vec<String> {
        match self.view_mode {
            ViewMode::DetoursList => vec!["List".to_string(), "Verify All".to_string(), "Activate All".to_string()],
            ViewMode::InjectionsList => vec!["List".to_string()],
            ViewMode::MirrorsList => vec!["List".to_string(), "Add".to_string()],
            ViewMode::ServicesList => vec!["List".to_string()],
            ViewMode::StatusOverview => vec!["Overview".to_string()],
            ViewMode::LogsLive => vec!["Logs".to_string()],
            ViewMode::ConfigEdit => vec!["Edit".to_string()],
            _ => vec![],
        }
    }
    
    /// Handle edit action based on current view mode and column
    pub fn handle_edit_action(&mut self) {
        if self.active_column == ActiveColumn::Content {
            match self.view_mode {
                ViewMode::DetoursList => self.edit_selected_detour(),
                ViewMode::InjectionsList => self.edit_selected_injection(),
                ViewMode::MirrorsList => self.edit_selected_mirror(),
                _ => {}
            }
        }
    }
    
    /// Handle delete action based on current view mode and column
    pub fn handle_delete_action(&mut self) {
        if self.active_column == ActiveColumn::Content {
            match self.view_mode {
                ViewMode::DetoursList => self.delete_selected_detour(),
                ViewMode::InjectionsList => self.delete_selected_injection(),
                ViewMode::MirrorsList => self.delete_selected_mirror(),
                _ => {}
            }
        }
    }
    
    pub fn handle_action_select(&mut self) {
        if self.active_column == ActiveColumn::Actions {
            let action = self.get_current_actions()[self.selected_action].clone();
            match action.as_str() {
                "Verify All" => {
                        self.validate_detours_all();
                }
                "Activate All" => {
                    self.activate_all_detours();
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
                ViewMode::InjectionsList => {
                    if let Some(injection) = self.injections.get_mut(self.selected_injection) {
                        let new_state = !injection.active;
                        let target = injection.target.clone();
                        let include_file = injection.include_file.clone();
                        
                        let result = if new_state {
                            self.injection_manager.apply(
                                std::path::Path::new(&target),
                                std::path::Path::new(&include_file)
                            )
                        } else {
                            self.injection_manager.remove(
                                std::path::Path::new(&target),
                                std::path::Path::new(&include_file)
                            )
                        };
                        
                        match result {
                            Ok(_) => {
                                injection.active = new_state;
                                
                                use crate::operations::config_ops;
                                let _ = config_ops::with_config_mut(&self.config_path, |config| {
                                    if let Some(entry) = config.injections.iter_mut().find(|e| e.target == target) {
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
                ViewMode::MirrorsList => {
                    if let Some(mirror) = self.mirrors.get_mut(self.selected_mirror) {
                        let new_state = !mirror.active;
                        let source = mirror.source.clone();
                        let target = mirror.target.clone();
                        
                        let result = if new_state {
                            self.mirror_manager.apply_mirror(&source, &target)
                        } else {
                            self.mirror_manager.remove_mirror(&target)
                        };
                        
                        match result {
                            Ok(msg) => {
                                mirror.active = new_state;
                                
                                use crate::operations::config_ops;
                                let _ = config_ops::with_config_mut(&self.config_path, |config| {
                                    if let Some(entry) = config.mirrors.iter_mut().find(|e| e.source == source && e.target == target) {
                                        entry.enabled = new_state;
                                    }
                                    Ok(())
                                });
                                
                                let action = if new_state { "Activated" } else { "Deactivated" };
                                self.add_log("INFO", &msg);
                                self.add_toast(format!("{} mirror", action), ToastType::Success);
                            }
                            Err(err) => {
                                self.show_error("Mirror Error".to_string(), format!("Failed to toggle mirror: {}", err));
                            }
                        }
                    }
                }
                _ => {}
            }
        }
    }

    // Injections add form methods
    pub fn injection_form_handle_char(&mut self, c: char) {
        crate::forms::injection_form::handle_char(&mut self.injection_form, c);
    }
    pub fn injection_form_backspace(&mut self) {
        crate::forms::injection_form::handle_backspace(&mut self.injection_form);
    }
    pub fn injection_form_move_cursor_left(&mut self) {
        crate::forms::injection_form::move_cursor_left(&mut self.injection_form);
    }
    pub fn injection_form_move_cursor_right(&mut self) {
        crate::forms::injection_form::move_cursor_right(&mut self.injection_form);
    }
    pub fn injection_form_next_field(&mut self) {
        if crate::forms::injection_form::next_field(&mut self.injection_form) {
            self.injection_form_submit();
        }
    }
    pub fn injection_form_prev_field(&mut self) {
        crate::forms::injection_form::prev_field(&mut self.injection_form);
    }
    pub fn injection_form_cancel(&mut self) {
        self.view_mode = ViewMode::InjectionsList;
        self.active_column = ActiveColumn::Actions;
        self.selected_action = 0;
        self.action_state.select(Some(0));
    }
    pub fn injection_form_submit(&mut self) { self.save_injection_to_config(); }
    pub fn save_injection_to_config(&mut self) {
        let target = self.injection_form.target_path.trim().to_string();
        let include = self.injection_form.include_path.trim().to_string();
        let description = self.injection_form.description.trim().to_string();
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
            self.pending_action = Some(PendingAction::CreateInjectionFileAndSave);
            return;
        }
        use crate::operations::config_ops;
        
        let target_clone = target.clone();
        let include_clone = include.clone();
        let description_clone = description.clone();
        let edit_idx = self.injection_form.editing_index;
        
        match config_ops::with_config_mut(&self.config_path, |config| {
            // Check if we're editing or adding
            if let Some(edit_idx) = edit_idx {
                // Edit existing include
                if let Some(entry) = config.injections.get_mut(edit_idx) {
                    entry.target = target_clone.clone();
                    entry.include_file = include_clone.clone();
                    entry.description = Self::description_from_str(&description_clone);
                }
            } else {
                // Add new include (active by default)
                config.injections.push(crate::config::InjectionEntry { 
                    target: target_clone.clone(), 
                    include_file: include_clone.clone(), 
                    description: Self::description_from_str(&description_clone), 
                    enabled: true 
                });
            }
            Ok(())
        }) {
            Ok(_) => {
            let action = if self.injection_form.editing_index.is_some() {
                "Include updated"
            } else {
                "Include added"
            };
            
            // Reload config to refresh the list with the new include
            self.reload_config();
            
            // After reloading, activate the include if it was newly created and enabled
            if !self.injection_form.editing_index.is_some() {
                // Only for new includes - find it in the list and activate it (since enabled: true by default)
                let include_file_str = include.clone();
                if let Some(injection_item) = self.injections.iter_mut().find(|i| i.target == target && i.include_file == include_file_str) {
                    if !injection_item.active {
                        // Activate it using the same logic as space key toggle
                        use std::path::Path;
                        let target_path = Path::new(&target);
                        let include_path = Path::new(&include);
                        if let Err(e) = self.injection_manager.apply(target_path, include_path) {
                            self.add_log("WARN", &format!("Failed to apply injection to target: {}", e));
        } else {
                            injection_item.active = true;
                            self.add_log("INFO", &format!("Applied injection to target: {}", target));
                        }
                    }
                }
            }
            
                self.add_toast(action.to_string(), ToastType::Success);
            self.view_mode = ViewMode::InjectionsList;
            self.active_column = ActiveColumn::Content;
            }
            Err(e) => {
                self.show_error("Save Error".to_string(), e);
            }
        }
    }

    pub fn create_injection_file_and_save(&mut self) {
        use std::path::Path;
        use crate::operations::file_ops;
        
        let target = self.injection_form.target_path.trim().to_string();
        let include = self.injection_form.include_path.trim().to_string();
        
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
                self.save_injection_to_config();
            }
            Err(e) => {
                self.show_error("Create File Error".to_string(), e);
            }
        }
    }

    pub fn injection_form_open_file_browser(&mut self) {
        use crate::filebrowser::FileBrowser;
        let start_path = match self.injection_form.active_field {
            0 => {
                if !self.injection_form.target_path.is_empty() {
                    std::path::Path::new(&self.injection_form.target_path)
                        .parent()
                        .and_then(|p| p.to_str())
                        .unwrap_or("/home/pi")
                } else {
                    "/home/pi"
                }
            }
            1 => {
                if !self.injection_form.include_path.is_empty() {
                    std::path::Path::new(&self.injection_form.include_path)
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
    pub fn injection_form_close_file_browser(&mut self, selected_path: Option<String>) {
        if let Some(path) = selected_path {
            match self.injection_form.active_field {
                0 => { self.injection_form.target_path = path.clone(); self.injection_form.cursor_pos = path.len(); }
                1 => { self.injection_form.include_path = path.clone(); self.injection_form.cursor_pos = path.len(); }
                _ => {}
            }
        }
        self.file_browser = None;
    }
    pub fn injection_form_complete_path(&mut self) {
        if crate::forms::injection_form::complete_path(&mut self.injection_form) {
            self.injection_form_next_field();
        }
    }
    pub fn injection_form_paste_clipboard(&mut self) {
        crate::forms::injection_form::paste_clipboard(&mut self.injection_form);
    }

    pub fn delete_selected_injection(&mut self) {
        if let Some(_include) = self.injections.get(self.selected_injection) {
            self.pending_action = Some(PendingAction::DeleteInjection(self.selected_injection));
            self.popup = Some(crate::popup::Popup::Confirm {
                title: "Confirm Delete".to_string(),
                message: format!("Delete this include?\n\n{} ← {}", self.injections[self.selected_injection].target, self.injections[self.selected_injection].include_file),
                selected: 1,
            });
        }
    }

    pub fn confirm_delete_injection(&mut self, index: usize) {
        use std::path::Path;
        
        // Check if include is active in app state before removing from config
        let was_active = self.injections.get(index).map(|i| i.active).unwrap_or(false);
        let target_path_str = if index < self.injections.len() {
            self.injections[index].target.clone()
                        } else {
            return;
        };
        let include_file_path_str = if index < self.injections.len() {
            self.injections[index].include_file.clone()
        } else {
            return;
        };
        
        // Load config
        let mut config = crate::operations::config_ops::load_config(&self.config_path);
        if index < config.injections.len() {
            // Remove from config
            let _removed = config.injections.remove(index);
            
            // If include was active, disable it first (remove include directive)
            if was_active {
                let target_path = Path::new(&target_path_str);
                let include_path = Path::new(&include_file_path_str);
                if let Err(e) = self.injection_manager.remove(target_path, include_path) {
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
                    self.pending_action = Some(PendingAction::DeleteInjectionAndFile(index, include_file_path.clone()));
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
                self.adjust_selection_after_delete_injection();
        }
    }
    
    // Delete include and optionally the include file
    pub fn delete_injection_and_file(&mut self, _index: usize, include_file_path: String, delete_file: bool) {
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
                self.adjust_selection_after_delete_injection();
    }
    
    pub fn edit_selected_injection(&mut self) {
        if let Some(injection) = self.injections.get(self.selected_injection) {
            // Load config to get description
            use crate::operations::config_ops;
            let config = config_ops::load_config(&self.config_path);
            let description = config.injections.get(self.selected_injection)
                .and_then(|e| e.description.clone())
                .unwrap_or_default();
            
            // Populate form with current injection data
            self.injection_form = AddInjectionForm {
                target_path: injection.target.clone(),
                include_path: injection.include_file.clone(),
                description,
                active_field: 0,
                cursor_pos: 0,
                editing_index: Some(self.selected_injection),
            };
            
            // Switch to add view (reuse for editing)
            self.view_mode = ViewMode::InjectionsAdd;
            self.active_column = ActiveColumn::Content;
            
            self.add_log("INFO", &format!("Editing injection: {}", injection.target));
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
            self.popup = Some(crate::popup::Popup::Confirm {
                title: "Confirm Delete".to_string(),
                message: format!("Delete this detour?\n\n{} ← {}", self.detours[self.selected_detour].original, self.detours[self.selected_detour].custom),
                selected: 1,
            });
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
        crate::forms::detour_form::handle_char(&mut self.add_form, c);
    }
    
    pub fn form_handle_backspace(&mut self) {
        crate::forms::detour_form::handle_backspace(&mut self.add_form);
    }
    
    pub fn form_move_cursor_left(&mut self) {
        crate::forms::detour_form::move_cursor_left(&mut self.add_form);
    }
    
    pub fn form_move_cursor_right(&mut self) {
        crate::forms::detour_form::move_cursor_right(&mut self.add_form);
    }
    
    pub fn form_next_field(&mut self) {
        crate::forms::detour_form::next_field(&mut self.add_form);
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
                entry.description = Self::description_from_str(&self.add_form.description);
            }
        } else {
            // Add new detour
            config.detours.push(DetourEntry {
                original: self.add_form.original_path.clone(),
                custom: self.add_form.custom_path.clone(),
                description: Self::description_from_str(&self.add_form.description),
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

    pub fn validate_single_detour(&mut self, index: usize) {
        use std::path::Path;

        if let Some(detour) = self.detours.get(index) {
        let original_path = Path::new(&detour.original);
        let custom_path = Path::new(&detour.custom);
            
            let missing_original = if !original_path.exists() { 1 } else { 0 };
            let missing_custom = if !custom_path.exists() { 1 } else { 0 };
        let mut unreadable = 0;
        if original_path.exists() && std::fs::metadata(&detour.original).is_err() { unreadable += 1; }
        if custom_path.exists() && std::fs::metadata(&detour.custom).is_err() { unreadable += 1; }
            
            let result = format!(
                "Detour: {} ← {}\n  {} missing original\n  {} missing custom\n  {} unreadable",
                detour.original, detour.custom, missing_original, missing_custom, unreadable
            );
            
            // Show validation result in a popup
            self.popup = Some(crate::popup::Popup::info("Validation Result", result));
            } else {
            self.show_error("Validation Error".to_string(), "Invalid index".to_string());
        }
    }
    
    pub fn form_complete_path(&mut self) {
        crate::forms::detour_form::complete_path(&mut self.add_form);
    }
    
    pub fn form_paste_clipboard(&mut self) {
        crate::forms::detour_form::paste_clipboard(&mut self.add_form);
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
    fn adjust_selection_after_delete_injection(&mut self) {
        self.sync_injection_selection();
    }
    
    // Helper: Adjust selection after deleting a detour
    fn adjust_selection_after_delete_detour(&mut self) {
        self.sync_detour_selection();
    }
    
    pub fn delete_selected_mirror(&mut self) {
        if let Some(_mirror) = self.mirrors.get(self.selected_mirror) {
            self.pending_action = Some(PendingAction::DeleteMirror(self.selected_mirror));
            self.popup = Some(crate::popup::Popup::Confirm {
                title: "Confirm Delete".to_string(),
                message: format!("Delete this mirror?\n\n{} → {}", self.mirrors[self.selected_mirror].source, self.mirrors[self.selected_mirror].target),
                selected: 1,
            });
        }
    }
    
    pub fn confirm_delete_mirror(&mut self, index: usize) {
        // Check if mirror is active before removing
        let was_active = self.mirrors.get(index).map(|m| m.active).unwrap_or(false);
        let source_str = if index < self.mirrors.len() {
            self.mirrors[index].source.clone()
        } else {
            return;
        };
        let target_str = if index < self.mirrors.len() {
            self.mirrors[index].target.clone()
        } else {
            return;
        };
        
        // If mirror was active, remove symlink first
        if was_active {
            if let Err(e) = self.mirror_manager.remove_mirror(&target_str) {
                self.add_log("WARN", &format!("Failed to remove symlink: {}", e));
            } else {
                self.add_log("INFO", &format!("Removed symlink before deletion: {}", target_str));
            }
        }
        
        // Load config
        let mut config = crate::operations::config_ops::load_config(&self.config_path);
        
        // Remove the mirror
        if index < config.mirrors.len() {
            config.mirrors.remove(index);
            
            // Save config
            use crate::operations::config_ops;
            if let Err(e) = config_ops::save_config(&self.config_path, &config) {
                self.show_error("Save Error".to_string(), e);
                return;
            }
            
            self.add_log("SUCCESS", &format!("Deleted mirror: {} → {}", source_str, target_str));
            self.add_toast("Mirror deleted successfully!".to_string(), ToastType::Success);
            
            // Reload config
            self.reload_config();
            
            self.sync_mirror_selection();
        }
    }
    
    pub fn edit_selected_mirror(&mut self) {
        // For now, just show a message - mirror form will be implemented later
        if let Some(mirror) = self.mirrors.get(self.selected_mirror) {
            self.show_error("Not Implemented".to_string(), 
                format!("Mirror editing not yet implemented.\n\nCurrent mirror:\n{} → {}", mirror.source, mirror.target));
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
            ViewMode::InjectionsList => "Manage file injections".to_string(),
            ViewMode::InjectionsAdd => "Add a new injection".to_string(),
            ViewMode::MirrorsList => "Manage symlink mirrors".to_string(),
            ViewMode::ServicesList => "Manage services".to_string(),
            ViewMode::StatusOverview => "System status overview".to_string(),
            ViewMode::LogsLive => "Live log output".to_string(),
            ViewMode::ConfigEdit => "Edit configuration".to_string(),
        }
    }
    
    pub fn close_validation_report(&mut self) {
        self.validation_report = None;
    }
    
    pub fn validate_single_injection(&mut self, index: usize) {
        use std::path::Path;
        
        if let Some(injection) = self.injections.get(index) {
            let target_path = Path::new(&injection.target);
            let include_path = Path::new(&injection.include_file);
            
            let missing_target = if !target_path.exists() { 1 } else { 0 };
            let missing_include = if !include_path.exists() { 1 } else { 0 };
            let mut unreadable = 0;
            if target_path.exists() && std::fs::metadata(&injection.target).is_err() { unreadable += 1; }
            if include_path.exists() && std::fs::metadata(&injection.include_file).is_err() { unreadable += 1; }
            
            let result = format!(
                "Injection: {} ← {}\n  {} missing target\n  {} missing injection file\n  {} unreadable\n  Active: {}",
                injection.target, injection.include_file, missing_target, missing_include, unreadable,
                if injection.active { "Yes" } else { "No" }
            );
            
            // Show validation result in a popup
            self.popup = Some(crate::popup::Popup::info("Validation Result", result));
        } else {
            self.show_error("Validation Error".to_string(), "Invalid index".to_string());
        }
    }
}

