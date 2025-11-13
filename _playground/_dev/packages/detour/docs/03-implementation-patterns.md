# Detour Implementation Patterns for AI Agents

## Purpose

This document provides Detour-specific implementation patterns and code examples. For universal implementation patterns, see `_dev/_docs/rust/05-event-handling.md` and `_dev/_docs/rust/06-state-management.md`.

## Universal Patterns Reference

**Universal implementation patterns are documented in:**
- **Event Handling**: `_dev/_docs/rust/05-event-handling.md`
- **State Management**: `_dev/_docs/rust/06-state-management.md`
- **Component Patterns**: `_dev/_docs/rust/04-component-patterns.md`

This guide focuses on **Detour-specific** implementation patterns and extensions.

## Detour-Specific State Management

### Detour Application State

```rust
pub struct App {
    // Navigation (universal pattern)
    pub active_column: ActiveColumn,
    pub view_mode: ViewMode,
    pub view_state: ListState,
    pub action_state: ListState,
    pub content_state: ListState,
    
    // Modals (universal pattern)
    pub popup: Option<Popup>,
    pub file_browser: Option<FileBrowser>,
    pub validation_report: Option<ValidationReport>,
    pub diff_viewer: Option<DiffViewer>,
    
    // Detour-specific forms
    pub add_detour_form: Option<AddDetourForm>,
    pub add_injection_form: Option<AddInjectionForm>,
    pub add_mirror_form: Option<AddMirrorForm>,
    
    // Detour-specific data
    pub detours: Vec<Detour>,
    pub injections: Vec<Injection>,
    pub mirrors: Vec<Mirror>,
    pub config: Config,
    pub profile: String,
    pub config_path: PathBuf,
    
    // UI state (universal pattern)
    pub toasts: Vec<Toast>,
    pub should_quit: bool,
    pub logs: Vec<LogEntry>,
}
```

### Detour Data Structures

```rust
pub struct Detour {
    pub original: String,
    pub custom: String,
    pub active: bool,
    pub size: u64,
    pub modified: String,
}

pub struct Injection {
    pub target: String,
    pub include_file: String,
    pub active: bool,
}

pub struct Mirror {
    pub source: String,
    pub destination: String,
    pub active: bool,
}
```

## Detour-Specific Event Handling

### Detour List Specific Keys

```rust
fn handle_detours_list_keys(key: KeyEvent, app: &mut App) {
    match key.code {
        KeyCode::Char(' ') => {
            // Toggle detour active state
            if let Some(selected) = app.content_state.selected() {
                if let Some(detour) = app.detours.get_mut(selected) {
                    app.toggle_detour(detour);
                }
            }
        }
        KeyCode::Char('e') => {
            // Edit selected detour
            if let Some(selected) = app.content_state.selected() {
                app.edit_detour(selected);
            }
        }
        KeyCode::Char('d') => {
            // Show diff viewer
            if let Some(selected) = app.content_state.selected() {
                if let Some(detour) = app.detours.get(selected) {
                    app.show_diff_viewer(&detour.original, &detour.custom);
                }
            }
        }
        KeyCode::Char('v') => {
            // Validate selected detour
            if let Some(selected) = app.content_state.selected() {
                if let Some(detour) = app.detours.get(selected) {
                    app.validate_detour(detour);
                }
            }
        }
        KeyCode::Delete => {
            // Delete selected detour (with confirmation)
            if let Some(selected) = app.content_state.selected() {
                if let Some(detour) = app.detours.get(selected) {
                    app.popup = Some(Popup::confirm(
                        "Confirm Delete",
                        format!("Delete this detour?\n\n{}\n→ {}", detour.original, detour.custom)
                    ));
                    app.pending_delete_index = Some(selected);
                }
            }
        }
        _ => {}
    }
}
```

### Detour Form Specific Keys

```rust
fn handle_detour_form_keys(key: KeyEvent, app: &mut App) {
    if let Some(form) = &mut app.add_detour_form {
        match key.code {
            KeyCode::Char('f') if key.modifiers.contains(KeyModifiers::CONTROL) => {
                // Open file browser for current field
                let start_path = if form.active_field == 0 {
                    form.original_path.clone()
                } else {
                    form.custom_path.clone()
                };
                app.file_browser = Some(FileBrowser::new(&start_path));
            }
            KeyCode::Tab => {
                // Path completion or next field
                if form.active_field == 0 && !form.original_path.is_empty() {
                    // Try path completion
                } else {
                    form.active_field = (form.active_field + 1) % 2;
                    form.cursor_pos = form.get_current_field_value().len();
                }
            }
            _ => {
                // Use universal form key handling
                handle_unified_form_keys(key, app);
            }
        }
    }
}
```

## Detour-Specific Operations

### Apply Detour

```rust
impl App {
    pub fn apply_detour(&mut self, detour: &Detour) -> Result<(), DetourError> {
        // Validate paths
        if !Path::new(&detour.custom).exists() {
            return Err(DetourError::CustomNotFound);
        }
        
        // Apply bind mount via shell script
        let output = std::process::Command::new("sudo")
            .arg("bash")
            .arg("/home/pi/_playground/_dev/packages/detour/lib/detour-core.sh")
            .arg("apply")
            .arg(&detour.original)
            .arg(&detour.custom)
            .output()?;
        
        if output.status.success() {
            // Update state
            if let Some(d) = self.detours.iter_mut().find(|d| d.original == detour.original) {
                d.active = true;
            }
            
            // Log operation
            self.add_log("SUCCESS", format!("Applied detour: {}", detour.original));
            self.add_toast("Detour applied successfully".to_string(), ToastType::Success);
            Ok(())
        } else {
            let error = String::from_utf8_lossy(&output.stderr);
            self.add_log("ERROR", format!("Failed to apply detour: {}", error));
            Err(DetourError::MountFailed(error.to_string()))
        }
    }
}
```

### Toggle Detour

```rust
impl App {
    pub fn toggle_detour(&mut self, detour: &mut Detour) {
        if detour.active {
            // Deactivate
            match self.remove_detour(detour) {
                Ok(()) => {
                    detour.active = false;
                    self.add_toast(format!("Deactivated {}", detour.original), ToastType::Success);
                }
                Err(e) => {
                    self.popup = Some(Popup::error("Error", &e.to_string()));
                }
            }
        } else {
            // Activate
            match self.apply_detour(detour) {
                Ok(()) => {
                    detour.active = true;
                    self.add_toast(format!("Activated {}", detour.original), ToastType::Success);
                }
                Err(e) => {
                    self.popup = Some(Popup::error("Error", &e.to_string()));
                }
            }
        }
        
        // Update config
        self.save_config();
    }
}
```

### Validate Detour

```rust
impl App {
    pub fn validate_detour(&mut self, detour: &Detour) {
        let mut issues = Vec::new();
        
        // Check original path
        if !Path::new(&detour.original).exists() && !detour.original.starts_with('/') {
            issues.push(format!("Invalid original path: {}", detour.original));
        }
        
        // Check custom path
        if !Path::new(&detour.custom).exists() {
            issues.push(format!("Custom file not found: {}", detour.custom));
        }
        
        // Check if paths are different
        if detour.original == detour.custom {
            issues.push("Original and custom paths are the same".to_string());
        }
        
        // Check mount status
        if detour.active {
            if !self.check_mount_status(&Path::new(&detour.original)) {
                issues.push("Detour is marked active but mount not found".to_string());
            }
        }
        
        // Show validation report
        let report = ValidationReport {
            content: if issues.is_empty() {
                format!("Detour is valid:\n\n{}\n→ {}", detour.original, detour.custom)
            } else {
                format!("Found {} issue(s):\n\n{}", issues.len(), issues.join("\n"))
            },
            has_issues: !issues.is_empty(),
        };
        
        self.validation_report = Some(report);
    }
}
```

## Detour-Specific UI Rendering

### Detours List Rendering

```rust
fn draw_detours_list(f: &mut Frame, area: Rect, app: &mut App) {
    let modal_visible = app.is_modal_visible();
    let is_active = app.active_column == ActiveColumn::Content && !modal_visible;
    
    // Convert detours to list items
    let items: Vec<list_panel::ItemRow> = app.detours.iter().map(|detour| {
        list_panel::ItemRow {
            line1: format!("{} → {}", detour.original, detour.custom),
            line2: Some(format!(
                "   {} | {} | {}",
                detour.status_text(),
                detour.size_display(),
                detour.modified_ago()
            )),
            status_icon: Some(if detour.active { "✓" } else { "○" }.to_string()),
        }
    }).collect();
    
    // Use universal list panel component
    list_panel::draw_list_panel(
        f,
        area,
        "Detours",
        &items,
        &mut app.content_state,
        is_active,
        modal_visible,
        &list_panel::ListPanelTheme::default(),
    );
}
```

### Status Overview Rendering

```rust
fn draw_status_overview(f: &mut Frame, area: Rect, app: &App) {
    let modal_visible = app.is_modal_visible();
    
    // Calculate statistics
    let active_count = app.detours.iter().filter(|d| d.active).count();
    let total_count = app.detours.len();
    let error_count = app.detours.iter().filter(|d| {
        d.active && !app.check_mount_status(&Path::new(&d.original))
    }).count();
    
    // Render status information
    let lines = vec![
        Line::from(vec![
            Span::styled("Overall: ", Style::default().fg(hex_color(0x888888))),
            Span::styled(
                if error_count == 0 { "✓ Healthy" } else { "⚠️ Issues" },
                Style::default().fg(if error_count == 0 { Color::Green } else { Color::Yellow })
            ),
        ]),
        Line::from(vec![
            Span::styled("Detours:  ", Style::default().fg(hex_color(0x888888))),
            Span::styled(format!("{}/{} active", active_count, total_count), Style::default().fg(Color::White)),
        ]),
        // ... more status lines
    ];
    
    // Render with universal styling
    let paragraph = Paragraph::new(lines);
    f.render_widget(paragraph, content_area);
}
```

## Detour-Specific Error Handling

### Detour Error Types

```rust
#[derive(Debug)]
pub enum DetourError {
    CustomNotFound,
    BackupFailed(String),
    MountFailed(String),
    UnmountFailed(String),
    PermissionDenied,
    ConfigParseError(String),
    ValidationError(String),
}

impl std::fmt::Display for DetourError {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        match self {
            DetourError::CustomNotFound => write!(f, "Custom file not found"),
            DetourError::BackupFailed(msg) => write!(f, "Backup failed: {}", msg),
            DetourError::MountFailed(msg) => write!(f, "Mount failed: {}", msg),
            DetourError::UnmountFailed(msg) => write!(f, "Unmount failed: {}", msg),
            DetourError::PermissionDenied => write!(f, "Permission denied (need sudo)"),
            DetourError::ConfigParseError(msg) => write!(f, "Config parse error: {}", msg),
            DetourError::ValidationError(msg) => write!(f, "Validation error: {}", msg),
        }
    }
}
```

### Error Handling Pattern

```rust
match self.apply_detour(&detour) {
    Ok(()) => {
        self.add_toast("Detour applied successfully".to_string(), ToastType::Success);
        self.reload_detours();
    }
    Err(DetourError::PermissionDenied) => {
        self.popup = Some(Popup::error(
            "Permission Denied",
            "This operation requires sudo privileges. Please run with sudo."
        ));
    }
    Err(e) => {
        self.popup = Some(Popup::error("Error", &e.to_string()));
    }
}
```

## Detour-Specific Config Management

### Load Config

```rust
pub fn load_config(path: &Path) -> Result<Config, DetourError> {
    if !path.exists() {
        return Ok(Config::default());
    }
    
    let content = std::fs::read_to_string(path)
        .map_err(|e| DetourError::ConfigParseError(e.to_string()))?;
    
    let config: Config = serde_yaml::from_str(&content)
        .map_err(|e| DetourError::ConfigParseError(e.to_string()))?;
    
    Ok(config)
}
```

### Save Config

```rust
pub fn save_config(path: &Path, config: &Config) -> Result<(), DetourError> {
    let content = serde_yaml::to_string(config)
        .map_err(|e| DetourError::ConfigParseError(e.to_string()))?;
    
    std::fs::write(path, content)
        .map_err(|e| DetourError::ConfigParseError(e.to_string()))?;
    
    Ok(())
}
```

## Best Practices

1. **Follow Universal Patterns**: Use universal patterns from `_dev/_docs/rust/`
2. **Extend for Detour**: Add Detour-specific logic on top of universal patterns
3. **Shell Script Integration**: Use shell script for actual file operations
4. **Error Handling**: Handle mount/unmount errors gracefully
5. **State Synchronization**: Keep TUI state in sync with system state
6. **User Feedback**: Show toasts for operations, popups for errors

## Reference

- **Universal Event Handling**: See `_dev/_docs/rust/05-event-handling.md`
- **Universal State Management**: See `_dev/_docs/rust/06-state-management.md`
- **Universal Components**: See `_dev/_docs/rust/04-component-patterns.md`
- **Structure Guide**: See `01-structure-guide.md` for Detour structure
- **Style Guide**: See `02-style-guide.md` for Detour styling
