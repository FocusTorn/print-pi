// Application state management

use ratatui::widgets::ListState;
use crate::config::AppConfig;
use crate::sync::FileStatus;
use std::path::{Path, PathBuf};
use std::time::SystemTime;

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ActiveColumn {
    Views,
    Actions,
    Content,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ViewMode {
    DashboardList,
    SyncStatus,
    SyncHistory,
    ScriptsList,
}

#[derive(Debug, Clone)]
pub struct SyncStatus {
    pub yaml_path: std::path::PathBuf,
    pub json_path: std::path::PathBuf,
    pub yaml_mtime: Option<std::time::SystemTime>,
    pub json_mtime: Option<std::time::SystemTime>,
    pub status: FileStatus,
}

pub struct DashboardInfo {
    pub name: String,
    pub yaml_path: std::path::PathBuf,
    pub json_path: std::path::PathBuf,
    pub sync_status: SyncStatus,
}

#[derive(Debug, Clone)]
pub struct ScriptsInfo {
    pub name: String,
    pub source: PathBuf,
    pub destination: PathBuf,
    pub recursive: bool,
    pub sync_status: SyncStatus,
    pub files: Vec<ScriptFileInfo>,
}

#[derive(Debug, Clone)]
pub struct ScriptFileInfo {
    pub name: String,
    pub relative_path: PathBuf,
    pub source_path: PathBuf,
    pub dest_path: PathBuf,
    pub source_mtime: Option<SystemTime>,
    pub dest_mtime: Option<SystemTime>,
    pub needs_sync: bool,
}

pub struct App {
    // Navigation (universal pattern)
    pub active_column: ActiveColumn,
    pub view_mode: ViewMode,
    pub view_state: ListState,
    pub action_state: ListState,
    pub content_state: ListState,
    
    // Views
    pub views: Vec<String>,
    pub selected_view: Option<usize>,
    pub selected_action: Option<usize>,
    
    // Modals (universal pattern)
    pub popup: Option<crate::popup::Popup>,
    pub file_browser: Option<crate::components::FileBrowser>,
    
    // hasync-specific data
    pub dashboards: Vec<DashboardInfo>,
    pub selected_dashboard: Option<usize>,
    pub scripts: Vec<ScriptsInfo>,
    pub selected_script: Option<usize>,
    pub sync_status: Option<SyncStatus>,
    pub config: AppConfig,
    
    // UI state (universal pattern)
    pub toasts: Vec<crate::components::Toast>,
    pub should_quit: bool,
    pub logs: Vec<String>,
    
    // Scrolling state for script details in column 3
    pub script_details_scroll: u16,
    // Track if script details content needs scrolling (calculated in UI, used in events)
    pub script_details_needs_scrolling: bool,
}

impl App {
    pub fn new() -> Self {
        // Load configuration
        let config = AppConfig::load().unwrap_or_default();
        
        // Load dashboards and calculate sync status
        let dashboards: Vec<DashboardInfo> = config.dashboards.iter().map(|d| {
            let yaml_mtime = crate::sync::get_file_mtime(&d.yaml_source);
            let json_mtime = crate::sync::get_file_mtime(&d.json_storage);
            let status = crate::sync::detect_newer_file(&d.yaml_source, &d.json_storage);
            
            DashboardInfo {
                name: d.name.clone(),
                yaml_path: d.yaml_source.clone(),
                json_path: d.json_storage.clone(),
                sync_status: SyncStatus {
                    yaml_path: d.yaml_source.clone(),
                    json_path: d.json_storage.clone(),
                    yaml_mtime,
                    json_mtime,
                    status,
                },
            }
        }).collect();
        
        // Load scripts and calculate sync status
        let scripts: Vec<ScriptsInfo> = config.scripts.as_ref()
            .map(|scripts_list| {
                scripts_list.iter().map(|s| {
                    let source_mtime = crate::sync::get_file_mtime(&s.source);
                    let dest_mtime = crate::sync::get_file_mtime(&s.destination);
                    let status = crate::sync::detect_scripts_sync_needed(&s.source, &s.destination);
                    
                    // Scan files in the source directory
                    let files = scan_scripts_directory(&s.source, &s.destination, s.recursive.unwrap_or(true));
                    
                    ScriptsInfo {
                        name: s.name.clone(),
                        source: s.source.clone(),
                        destination: s.destination.clone(),
                        recursive: s.recursive.unwrap_or(true),
                        sync_status: SyncStatus {
                            yaml_path: s.source.clone(),
                            json_path: s.destination.clone(),
                            yaml_mtime: source_mtime,
                            json_mtime: dest_mtime,
                            status,
                        },
                        files,
                    }
                }).collect()
            })
            .unwrap_or_default();
        
        App {
            active_column: ActiveColumn::Views,
            view_mode: ViewMode::DashboardList,
            view_state: ListState::default().with_selected(Some(0)),
            action_state: ListState::default().with_selected(Some(0)),  // Start with first item selected
            content_state: ListState::default(),
            views: vec![
                "Dashboards".to_string(),
                "Scripts".to_string(),
                "Sync Status".to_string(),
                "Sync History".to_string(),
            ],
            selected_view: Some(0),
            selected_action: Some(0),
            popup: None,
            file_browser: None,
            dashboards,
            selected_dashboard: None,
            scripts,
            selected_script: None,
            sync_status: None,
            config,
            toasts: vec![],
            should_quit: false,
            logs: vec![],
            script_details_scroll: 0,
            script_details_needs_scrolling: false,
        }
    }
    
    pub fn is_modal_visible(&self) -> bool {
        self.popup.is_some() || self.file_browser.is_some()
    }
    
    pub fn get_current_actions(&self) -> Vec<String> {
        match self.view_mode {
            ViewMode::DashboardList => vec!["List".to_string(), "Sync YAML→JSON".to_string(), "Sync JSON→YAML".to_string(), "Check Status".to_string(), "Show Diff".to_string()],
            ViewMode::ScriptsList => vec!["List".to_string(), "Sync Scripts".to_string(), "Check Status".to_string()],
            ViewMode::SyncStatus => vec!["Status".to_string()],
            ViewMode::SyncHistory => vec!["History".to_string()],
        }
    }
    
    pub fn get_current_description(&self) -> String {
        match self.view_mode {
            ViewMode::DashboardList => "Manage dashboard synchronization".to_string(),
            ViewMode::ScriptsList => "Manage scripts synchronization".to_string(),
            ViewMode::SyncStatus => "View sync status for dashboards".to_string(),
            ViewMode::SyncHistory => "View sync history".to_string(),
        }
    }
    
    pub fn view_mode_from_index(index: usize) -> ViewMode {
        match index {
            0 => ViewMode::DashboardList,
            1 => ViewMode::ScriptsList,
            2 => ViewMode::SyncStatus,
            3 => ViewMode::SyncHistory,
            _ => ViewMode::DashboardList,
        }
    }
    
    pub fn add_toast(&mut self, message: String, toast_type: crate::components::ToastType) {
        self.toasts.push(crate::components::Toast::new(message, toast_type));
    }
    
    /// Update sync status for a dashboard
    pub fn update_dashboard_status(&mut self, index: usize) {
        if let Some(dashboard) = self.dashboards.get(index) {
            let yaml_mtime = crate::sync::get_file_mtime(&dashboard.yaml_path);
            let json_mtime = crate::sync::get_file_mtime(&dashboard.json_path);
            let status = crate::sync::detect_newer_file(&dashboard.yaml_path, &dashboard.json_path);
            
            if let Some(dashboard_info) = self.dashboards.get_mut(index) {
                dashboard_info.sync_status.yaml_mtime = yaml_mtime;
                dashboard_info.sync_status.json_mtime = json_mtime;
                dashboard_info.sync_status.status = status;
            }
        }
    }
    
    /// Get selected dashboard config
    pub fn get_selected_dashboard_config(&self) -> Option<&crate::config::DashboardConfig> {
        if let Some(index) = self.selected_dashboard {
            self.config.dashboards.get(index)
        } else {
            None
        }
    }
    
    /// Sync YAML to JSON for selected dashboard
    pub fn sync_yaml_to_json_selected(&mut self) -> Result<PathBuf, crate::sync::SyncError> {
        if let Some(dashboard_config) = self.get_selected_dashboard_config() {
            let backup_path = crate::sync::sync_yaml_to_json(
                &dashboard_config.yaml_source,
                &dashboard_config.json_storage,
                &dashboard_config.dashboard_key,
                &dashboard_config.dashboard_title,
                &dashboard_config.dashboard_path,
            )?;
            
            // Update sync status
            if let Some(index) = self.selected_dashboard {
                self.update_dashboard_status(index);
            }
            
            Ok(backup_path)
        } else {
            Err(crate::sync::SyncError::ValidationFailed("No dashboard selected".to_string()))
        }
    }
    
    /// Update sync status for a script
    pub fn update_script_status(&mut self, index: usize) {
        if let Some(script) = self.scripts.get(index) {
            let source_mtime = crate::sync::get_file_mtime(&script.source);
            let dest_mtime = crate::sync::get_file_mtime(&script.destination);
            let status = crate::sync::detect_scripts_sync_needed(&script.source, &script.destination);
            
            if let Some(script_info) = self.scripts.get_mut(index) {
                script_info.sync_status.yaml_mtime = source_mtime;
                script_info.sync_status.json_mtime = dest_mtime;
                script_info.sync_status.status = status;
            }
        }
    }
    
    /// Get selected script config
    pub fn get_selected_script_config(&self) -> Option<&crate::config::ScriptsConfig> {
        if let Some(index) = self.selected_script {
            self.config.scripts.as_ref()?.get(index)
        } else {
            None
        }
    }
    
    /// Sync scripts for selected script entry
    pub fn sync_scripts_selected(&mut self) -> Result<Vec<PathBuf>, crate::sync::SyncError> {
        if let Some(script_config) = self.get_selected_script_config() {
            let backups = crate::sync::sync_scripts_directory(
                &script_config.source,
                &script_config.destination,
                script_config.recursive.unwrap_or(true),
            )?;
            
            // Update sync status
            if let Some(index) = self.selected_script {
                self.update_script_status(index);
            }
            
            Ok(backups)
        } else {
            Err(crate::sync::SyncError::ValidationFailed("No script selected".to_string()))
        }
    }
    
    /// Update files list for a script
    pub fn update_script_files(&mut self, index: usize) {
        if let Some(script) = self.scripts.get(index) {
            let files = scan_scripts_directory(&script.source, &script.destination, script.recursive);
            if let Some(script_info) = self.scripts.get_mut(index) {
                script_info.files = files;
            }
        }
    }
}

/// Scan scripts directory and return file information
fn scan_scripts_directory(source: &Path, destination: &Path, recursive: bool) -> Vec<ScriptFileInfo> {
    let mut files = Vec::new();
    
    if !source.exists() || !source.is_dir() {
        return files;
    }
    
    scan_scripts_directory_recursive(source, destination, source, &mut files, recursive);
    files.sort_by(|a, b| a.relative_path.cmp(&b.relative_path));
    files
}

fn scan_scripts_directory_recursive(
    source_root: &Path,
    dest_root: &Path,
    current_source: &Path,
    files: &mut Vec<ScriptFileInfo>,
    recursive: bool,
) {
    if let Ok(entries) = std::fs::read_dir(current_source) {
        for entry in entries.flatten() {
            let source_path = entry.path();
            
            if source_path.is_dir() {
                if recursive {
                    scan_scripts_directory_recursive(source_root, dest_root, &source_path, files, recursive);
                }
                continue;
            }
            
            // Calculate relative path
            let relative_path = source_path.strip_prefix(source_root)
                .unwrap_or(&source_path)
                .to_path_buf();
            
            // Calculate destination path
            let dest_path = dest_root.join(&relative_path);
            
            // Get file modification times
            let source_mtime = crate::sync::get_file_mtime(&source_path);
            let dest_mtime = crate::sync::get_file_mtime(&dest_path);
            
            // Determine if file needs sync
            let needs_sync = match (source_mtime, dest_mtime) {
                (Some(src_time), Some(dst_time)) => src_time > dst_time,
                (Some(_), None) => true,  // Source exists, dest doesn't
                (None, Some(_)) => false, // Source doesn't exist (shouldn't happen)
                (None, None) => false,
            };
            
            files.push(ScriptFileInfo {
                name: entry.file_name().to_string_lossy().to_string(),
                relative_path,
                source_path,
                dest_path,
                source_mtime,
                dest_mtime,
                needs_sync,
            });
        }
    }
}

