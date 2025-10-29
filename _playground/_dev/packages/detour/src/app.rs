// Application state management

use ratatui::widgets::ListState;

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
    
    // List states for rendering
    pub view_state: ListState,
    pub action_state: ListState,
    pub detour_state: ListState,
    
    // Data
    pub views: Vec<String>,
    pub detours: Vec<Detour>,
    pub profile: String,
}

impl App {
    pub fn new() -> Self {
        let mut view_state = ListState::default();
        view_state.select(Some(0));
        
        let mut action_state = ListState::default();
        action_state.select(Some(0));
        
        let mut detour_state = ListState::default();
        detour_state.select(Some(0));
        
        Self {
            should_quit: false,
            active_column: ActiveColumn::Views,
            view_mode: ViewMode::DetoursList,
            
            selected_view: 0,
            selected_action: 0,
            selected_detour: 0,
            
            view_state,
            action_state,
            detour_state,
            
            views: vec![
                "Detours".to_string(),
                "Includes".to_string(),
                "Services".to_string(),
                "Status".to_string(),
                "Logs".to_string(),
                "Config".to_string(),
            ],
            
            detours: vec![
                Detour {
                    original: "/etc/nginx/nginx.conf".to_string(),
                    custom: "/home/pi/_playground/nginx/nginx.conf".to_string(),
                    active: true,
                    size: 12800,
                    modified: "2h ago".to_string(),
                },
                Detour {
                    original: "/home/pi/homeassistant/.vscode/settings.json".to_string(),
                    custom: "/home/pi/_playground/homeassistant/.vscode/settings.json".to_string(),
                    active: true,
                    size: 3277,
                    modified: "5m ago".to_string(),
                },
                Detour {
                    original: "/home/pi/klipper/printer.cfg".to_string(),
                    custom: "/home/pi/_playground/klipper/printer.cfg".to_string(),
                    active: false,
                    size: 15600,
                    modified: "3d ago".to_string(),
                },
            ],
            
            profile: "default".to_string(),
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
                if self.selected_detour > 0 {
                    self.selected_detour -= 1;
                    self.detour_state.select(Some(self.selected_detour));
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
                if self.selected_detour < self.detours.len() - 1 {
                    self.selected_detour += 1;
                    self.detour_state.select(Some(self.selected_detour));
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
            ActiveColumn::Views => ActiveColumn::Content,
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
            if let Some(detour) = self.detours.get_mut(self.selected_detour) {
                detour.active = !detour.active;
            }
        }
    }
}

impl Default for App {
    fn default() -> Self {
        Self::new()
    }
}

