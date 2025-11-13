// Event handling

use crossterm::event::{KeyEvent, KeyCode, KeyModifiers};
use crate::app::App;

pub fn handle_key_event(key: KeyEvent, app: &mut App) {
    // Auto-dismiss toasts (2.5 seconds)
    use std::time::{SystemTime, UNIX_EPOCH};
    let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default();
    app.toasts.retain(|toast| {
        let toast_time = toast.shown_at.duration_since(UNIX_EPOCH).unwrap_or_default();
        let elapsed = now.saturating_sub(toast_time);
        elapsed.as_secs_f32() <= 2.5
    });
    
    // Priority 1: Overlays (highest priority)
    if app.file_browser.is_some() {
        handle_file_browser_keys(key, app);
        return;
    }
    
    if app.popup.is_some() {
        handle_popup_keys(key, app);
        return;
    }
    
    // Priority 2: Forms (if any)
    // TODO: Handle forms when implemented
    
    // Priority 3: Global navigation
    match key.code {
        KeyCode::Esc | KeyCode::Char('q') | KeyCode::Char('Q') => {
            app.should_quit = true;
        }
        KeyCode::Char('c') if key.modifiers.contains(KeyModifiers::CONTROL) => {
            app.should_quit = true;
        }
        KeyCode::Up | KeyCode::Char('k') => {
            app.navigate_up();
        }
        KeyCode::Down | KeyCode::Char('j') => {
            app.navigate_down();
        }
        KeyCode::Left | KeyCode::Char('h') => {
            app.navigate_prev_column();
        }
        KeyCode::Right | KeyCode::Char('l') => {
            app.navigate_next_column();
        }
        KeyCode::Enter => {
            app.handle_enter();
        }
        _ => {
            // View-specific handlers
            handle_view_keys(key, app);
        }
    }
}

fn handle_file_browser_keys(key: KeyEvent, app: &mut App) {
    // TODO: Implement file browser key handling
    match key.code {
        KeyCode::Esc => {
            app.file_browser = None;
        }
        _ => {}
    }
}

fn handle_popup_keys(key: KeyEvent, app: &mut App) {
    if let Some(popup) = &mut app.popup {
        match popup {
            crate::popup::Popup::Confirm { selected, .. } => {
                match key.code {
                    KeyCode::Left | KeyCode::Right | KeyCode::Tab => {
                        // Toggle between Yes/No
                        *selected = (*selected + 1) % 2;
                    }
                    KeyCode::Enter => {
                        // Confirm selection
                        let selected_yes = *selected == 0;
                        let view_mode = app.view_mode;
                        app.popup = None;
                        
                        if selected_yes {
                            // Execute sync based on view mode
                            match view_mode {
                                crate::app::ViewMode::DashboardList => {
                                    match app.sync_yaml_to_json_selected() {
                                        Ok(backup_path) => {
                                            if backup_path.exists() {
                                                app.add_toast(
                                                    format!("Synced! Backup: {}", backup_path.display()),
                                                    crate::components::ToastType::Success,
                                                );
                                            } else {
                                                app.add_toast(
                                                    "Synced successfully!".to_string(),
                                                    crate::components::ToastType::Success,
                                                );
                                            }
                                        }
                                        Err(e) => {
                                            app.add_toast(
                                                format!("Sync failed: {}", e),
                                                crate::components::ToastType::Error,
                                            );
                                        }
                                    }
                                }
                                crate::app::ViewMode::ScriptsList => {
                                    match app.sync_scripts_selected() {
                                        Ok(backups) => {
                                            if backups.is_empty() {
                                                app.add_toast(
                                                    "Synced successfully!".to_string(),
                                                    crate::components::ToastType::Success,
                                                );
                                            } else {
                                                app.add_toast(
                                                    format!("Synced! {} backup(s) created", backups.len()),
                                                    crate::components::ToastType::Success,
                                                );
                                            }
                                        }
                                        Err(e) => {
                                            app.add_toast(
                                                format!("Sync failed: {}", e),
                                                crate::components::ToastType::Error,
                                            );
                                        }
                                    }
                                }
                                _ => {}
                            }
                        }
                    }
                    KeyCode::Esc => {
                        // Cancel (defaults to No)
                        app.popup = None;
                    }
                    _ => {}
                }
            }
            crate::popup::Popup::Error { .. } | crate::popup::Popup::Info { .. } => {
                match key.code {
                    KeyCode::Enter | KeyCode::Esc => {
                        app.popup = None;
                    }
                    _ => {}
                }
            }
            _ => {
                // Other popup types
                match key.code {
                    KeyCode::Esc => {
                        app.popup = None;
                    }
                    _ => {}
                }
            }
        }
    }
}

fn handle_view_keys(_key: KeyEvent, _app: &mut App) {
    // TODO: Implement view-specific key handling
}

impl App {
    pub fn navigate_up(&mut self) {
        match self.active_column {
            crate::app::ActiveColumn::Views => {
                if let Some(selected) = self.view_state.selected() {
                    if selected > 0 {
                        self.view_state.select(Some(selected - 1));
                        self.update_view_mode();
                    }
                }
            }
            crate::app::ActiveColumn::Actions => {
                if self.view_mode == crate::app::ViewMode::ScriptsList {
                    // Navigating script files list in column 2
                    if let Some(selected) = self.action_state.selected() {
                        if selected > 0 {
                            self.action_state.select(Some(selected - 1));
                        }
                    }
                } else {
                    // Default: navigating actions
                    if let Some(selected) = self.action_state.selected() {
                        if selected > 0 {
                            self.action_state.select(Some(selected - 1));
                        }
                    }
                }
            }
            crate::app::ActiveColumn::Content => {
                match self.view_mode {
                    crate::app::ViewMode::DashboardList => {
                        if let Some(selected) = self.content_state.selected() {
                            if selected > 0 {
                                self.content_state.select(Some(selected - 1));
                                if selected - 1 < self.dashboards.len() {
                                    self.selected_dashboard = Some(selected - 1);
                                    self.update_dashboard_status(selected - 1);
                                }
                            }
                        }
                    }
                    crate::app::ViewMode::ScriptsList => {
                        // In ScriptsList, column 3 shows script details which can be scrolled
                        // Only scroll if content exceeds visible area
                        if self.script_details_needs_scrolling {
                            let current_scroll = self.script_details_scroll;
                            if current_scroll > 0 {
                                self.script_details_scroll = current_scroll - 1;
                                self.content_state.select(Some((current_scroll - 1) as usize));
                            }
                        }
                    }
                    _ => {}
                }
            }
        }
    }
    
    pub fn navigate_down(&mut self) {
        match self.active_column {
            crate::app::ActiveColumn::Views => {
                if let Some(selected) = self.view_state.selected() {
                    let max = match self.view_mode {
                        crate::app::ViewMode::DashboardList => self.dashboards.len(),
                        crate::app::ViewMode::ScriptsList => self.scripts.len(),
                        crate::app::ViewMode::SyncStatus => 0,
                        crate::app::ViewMode::SyncHistory => 0,
                    };
                    if selected < max.saturating_sub(1) {
                        self.view_state.select(Some(selected + 1));
                        self.update_view_mode();
                    }
                }
            }
            crate::app::ActiveColumn::Actions => {
                if self.view_mode == crate::app::ViewMode::ScriptsList {
                    // Navigating script files list in column 2
                    // Calculate total files across all scripts
                    let total_files: usize = self.scripts.iter().map(|s| s.files.len()).sum();
                    if let Some(selected) = self.action_state.selected() {
                        let max = total_files.saturating_sub(1);
                        if selected < max {
                            self.action_state.select(Some(selected + 1));
                        }
                    }
                } else {
                    // Default: navigating actions
                    if let Some(selected) = self.action_state.selected() {
                        // TODO: Calculate max actions
                        if selected < 10 {
                            self.action_state.select(Some(selected + 1));
                        }
                    }
                }
            }
            crate::app::ActiveColumn::Content => {
                match self.view_mode {
                    crate::app::ViewMode::DashboardList => {
                        if let Some(selected) = self.content_state.selected() {
                            let max = self.dashboards.len().saturating_sub(1);
                            if selected < max {
                                self.content_state.select(Some(selected + 1));
                                if selected + 1 < self.dashboards.len() {
                                    self.selected_dashboard = Some(selected + 1);
                                    self.update_dashboard_status(selected + 1);
                                }
                            }
                        }
                    }
                    crate::app::ViewMode::ScriptsList => {
                        // In ScriptsList, column 3 shows script details which can be scrolled
                        // Only scroll if content exceeds visible area
                        if self.script_details_needs_scrolling {
                            let current_scroll = self.script_details_scroll;
                            // Calculate max scroll based on content (7 lines: source 3 + blank 1 + dest 3)
                            // This is a conservative estimate - actual max is calculated in UI
                            let max_scroll = 10u16; // Reasonable max scroll
                            if current_scroll < max_scroll {
                                self.script_details_scroll = current_scroll + 1;
                                self.content_state.select(Some((current_scroll + 1) as usize)); // Keep content_state in sync for scrollbar
                            }
                        }
                    }
                    _ => {}
                }
            }
        }
    }
    
    pub fn navigate_prev_column(&mut self) {
        match self.active_column {
            crate::app::ActiveColumn::Views => {
                // Stay in views
            }
            crate::app::ActiveColumn::Actions => {
                self.active_column = crate::app::ActiveColumn::Views;
            }
            crate::app::ActiveColumn::Content => {
                self.active_column = crate::app::ActiveColumn::Actions;
            }
        }
    }
    
    pub fn navigate_next_column(&mut self) {
        match self.active_column {
            crate::app::ActiveColumn::Views => {
                self.active_column = crate::app::ActiveColumn::Actions;
            }
            crate::app::ActiveColumn::Actions => {
                self.active_column = crate::app::ActiveColumn::Content;
            }
            crate::app::ActiveColumn::Content => {
                // Stay in content
            }
        }
    }
    
    pub fn update_view_mode(&mut self) {
        if let Some(selected) = self.view_state.selected() {
            self.view_mode = match selected {
                0 => crate::app::ViewMode::DashboardList,
                1 => crate::app::ViewMode::ScriptsList,
                2 => crate::app::ViewMode::SyncStatus,
                3 => crate::app::ViewMode::SyncHistory,
                _ => crate::app::ViewMode::DashboardList,
            };
            self.action_state.select(Some(0));
        }
    }
    
    pub fn handle_enter(&mut self) {
        // TODO: Implement enter handling based on active column and view mode
        match self.active_column {
            crate::app::ActiveColumn::Views => {
                // Move to actions
                self.active_column = crate::app::ActiveColumn::Actions;
            }
            crate::app::ActiveColumn::Actions => {
                // Execute action based on selected action
                let actions = self.get_current_actions();
                if let Some(selected) = self.action_state.selected() {
                    if let Some(action) = actions.get(selected) {
                        match (action.as_str(), self.view_mode) {
                            ("Sync YAML→JSON", crate::app::ViewMode::DashboardList) => {
                                // Show confirmation dialog for dashboard sync
                                self.popup = Some(crate::popup::Popup::confirm(
                                    "Confirm Sync",
                                    "Sync YAML to JSON? This will overwrite the JSON file.",
                                ));
                            }
                            ("Sync Scripts", crate::app::ViewMode::ScriptsList) => {
                                // Show confirmation dialog for scripts sync
                                self.popup = Some(crate::popup::Popup::confirm(
                                    "Confirm Sync",
                                    "Sync scripts directory? This will overwrite existing files.",
                                ));
                            }
                            ("Check Status", crate::app::ViewMode::DashboardList) => {
                                // Update sync status for selected dashboard
                                if let Some(index) = self.selected_dashboard {
                                    self.update_dashboard_status(index);
                                    self.add_toast(
                                        "Status updated".to_string(),
                                        crate::components::ToastType::Info,
                                    );
                                }
                            }
                            ("Check Status", crate::app::ViewMode::ScriptsList) => {
                                // Update sync status for selected script
                                if let Some(index) = self.selected_script {
                                    self.update_script_status(index);
                                    self.add_toast(
                                        "Status updated".to_string(),
                                        crate::components::ToastType::Info,
                                    );
                                }
                            }
                            _ => {}
                        }
                    }
                }
            }
            crate::app::ActiveColumn::Content => {
                match self.view_mode {
                    crate::app::ViewMode::DashboardList => {
                        if let Some(selected) = self.content_state.selected() {
                            if selected < self.dashboards.len() {
                                self.selected_dashboard = Some(selected);
                                self.update_dashboard_status(selected);
                            }
                        }
                    }
                    crate::app::ViewMode::ScriptsList => {
                        // Files are already shown, Enter can trigger actions or just update selection
                        if let Some(selected) = self.content_state.selected() {
                            // Find which script this file belongs to
                            let mut file_count = 0;
                            for (script_idx, script) in self.scripts.iter().enumerate() {
                                if selected < file_count + script.files.len() {
                                    self.selected_script = Some(script_idx);
                                    self.update_script_status(script_idx);
                                    break;
                                }
                                file_count += script.files.len();
                            }
                        }
                    }
                    _ => {}
                }
            }
        }
    }
}

