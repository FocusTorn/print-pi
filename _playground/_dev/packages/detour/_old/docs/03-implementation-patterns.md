# Detour Implementation Patterns for AI Agents

## Purpose

This document provides AI agents with concrete implementation patterns, code examples, and best practices for recreating Detour's functionality and extending it.

## State Management Patterns

### Application State Structure

```rust
pub struct App {
    // Navigation
    pub active_column: ActiveColumn,
    pub view_mode: ViewMode,
    pub view_state: ListState,
    pub action_state: ListState,
    pub content_state: ListState,
    
    // Modals/Overlays
    pub popup: Option<Popup>,
    pub file_browser: Option<FileBrowser>,
    pub validation_report: Option<ValidationReport>,
    pub diff_viewer: Option<DiffViewer>,
    
    // Forms
    pub add_detour_form: Option<AddDetourForm>,
    
    // Data
    pub detours: Vec<Detour>,
    pub config: Config,
    pub profile: String,
    pub config_path: PathBuf,
    
    // UI State
    pub toasts: Vec<Toast>,
    pub should_quit: bool,
    pub logs: Vec<LogEntry>,
}
```

### State Initialization Pattern

```rust
impl App {
    pub fn new() -> Self {
        let config_path = get_config_path();
        let config = config::load_config(&config_path).unwrap_or_default();
        let profile = config.current_profile.clone();
        let detours = manager::load_detours(&config);
        
        App {
            active_column: ActiveColumn::Views,
            view_mode: ViewMode::DetoursList,
            view_state: ListState::default().with_selected(Some(0)),
            action_state: ListState::default().with_selected(Some(0)),
            content_state: ListState::default(),
            popup: None,
            file_browser: None,
            validation_report: None,
            diff_viewer: None,
            add_detour_form: None,
            detours,
            config,
            profile,
            config_path,
            toasts: vec![],
            should_quit: false,
            logs: vec![],
        }
    }
}
```

### Modal State Check Pattern

```rust
impl App {
    pub fn is_modal_visible(&self) -> bool {
        self.popup.is_some()
            || self.file_browser.is_some()
            || self.validation_report.is_some()
            || self.diff_viewer.is_some()
    }
}
```

## Event Handling Patterns

### Event Routing Pattern

```rust
pub fn handle_events(app: &mut App) -> std::io::Result<()> {
    // Auto-dismiss toasts
    app.toasts.retain(|toast| {
        toast.shown_at.elapsed().map(|d| d.as_secs_f32() <= 2.5).unwrap_or(false)
    });
    
    if event::poll(Duration::from_millis(100))? {
        match event::read()? {
            Event::Key(key) => handle_key_event(key, app),
            Event::Mouse(mouse) => handle_mouse_event(mouse, app),
            _ => {}
        }
    }
    Ok(())
}
```

### Priority-Based Key Handling

```rust
fn handle_key_event(key: KeyEvent, app: &mut App) {
    // Priority 1: Overlays (highest priority)
    if app.file_browser.is_some() {
        handle_file_browser_keys(key, app);
        return;
    }
    
    if app.popup.is_some() {
        handle_popup_keys(key, app);
        return;
    }
    
    if app.validation_report.is_some() {
        handle_validation_report_keys(key, app);
        return;
    }
    
    if app.diff_viewer.is_some() {
        handle_diff_keys(key, app);
        return;
    }
    
    // Priority 2: Forms
    if matches!(app.view_mode, ViewMode::DetoursAdd | ViewMode::DetoursEdit)
        && app.active_column == ActiveColumn::Content {
        handle_unified_form_keys(key, app);
        return;
    }
    
    // Priority 3: Global navigation
    match key.code {
        KeyCode::Esc | KeyCode::Char('q') => app.should_quit = true,
        KeyCode::Up | KeyCode::Char('k') => app.navigate_up(),
        KeyCode::Down | KeyCode::Char('j') => app.navigate_down(),
        KeyCode::Left | KeyCode::Char('h') => app.navigate_prev_column(),
        KeyCode::Right | KeyCode::Char('l') => app.navigate_next_column(),
        KeyCode::Enter => app.handle_enter(),
        KeyCode::Char(' ') => app.handle_space(),
        _ => {}
    }
}
```

### Navigation Pattern

```rust
impl App {
    pub fn navigate_up(&mut self) {
        match self.active_column {
            ActiveColumn::Views => {
                if let Some(selected) = self.view_state.selected() {
                    if selected > 0 {
                        self.view_state.select(Some(selected - 1));
                        self.update_view_mode();
                    }
                }
            }
            ActiveColumn::Actions => {
                if let Some(selected) = self.action_state.selected() {
                    if selected > 0 {
                        self.action_state.select(Some(selected - 1));
                    }
                }
            }
            ActiveColumn::Content => {
                // Content-specific navigation
                self.navigate_content_up();
            }
        }
    }
    
    pub fn navigate_next_column(&mut self) {
        match self.active_column {
            ActiveColumn::Views => self.active_column = ActiveColumn::Actions,
            ActiveColumn::Actions => self.active_column = ActiveColumn::Content,
            ActiveColumn::Content => {} // Stay in content
        }
    }
}
```

## Form Handling Patterns

### Form State Management

```rust
pub struct AddDetourForm {
    pub original_path: String,
    pub custom_path: String,
    pub active_field: usize,
    pub cursor_pos: usize,
    pub editing_index: Option<usize>,  // None = new, Some(idx) = editing
}

impl AddDetourForm {
    pub fn new() -> Self {
        AddDetourForm {
            original_path: String::new(),
            custom_path: String::new(),
            active_field: 0,
            cursor_pos: 0,
            editing_index: None,
        }
    }
    
    pub fn from_detour(detour: &Detour, index: usize) -> Self {
        AddDetourForm {
            original_path: detour.original.clone(),
            custom_path: detour.custom.clone(),
            active_field: 0,
            cursor_pos: 0,
            editing_index: Some(index),
        }
    }
}
```

### Form Input Handling

```rust
fn handle_unified_form_keys(key: KeyEvent, app: &mut App) {
    if let Some(form) = &mut app.add_detour_form {
        match key.code {
            KeyCode::Up => {
                if form.active_field > 0 {
                    form.active_field -= 1;
                    form.cursor_pos = form.get_current_field_value().len();
                }
            }
            KeyCode::Down => {
                if form.active_field < 1 {
                    form.active_field += 1;
                    form.cursor_pos = form.get_current_field_value().len();
                }
            }
            KeyCode::Left => {
                if form.cursor_pos > 0 {
                    form.cursor_pos -= 1;
                }
            }
            KeyCode::Right => {
                let value = form.get_current_field_value();
                if form.cursor_pos < value.len() {
                    form.cursor_pos += 1;
                }
            }
            KeyCode::Char(c) => {
                let value = form.get_current_field_value_mut();
                value.insert(form.cursor_pos, c);
                form.cursor_pos += 1;
            }
            KeyCode::Backspace => {
                let value = form.get_current_field_value_mut();
                if form.cursor_pos > 0 {
                    value.remove(form.cursor_pos - 1);
                    form.cursor_pos -= 1;
                }
            }
            KeyCode::Tab => {
                // Path completion or next field
                if key.modifiers.contains(KeyModifiers::CONTROL) {
                    // Handle completion
                } else {
                    form.active_field = (form.active_field + 1) % 2;
                    form.cursor_pos = form.get_current_field_value().len();
                }
            }
            KeyCode::Enter => {
                app.submit_form();
            }
            KeyCode::Esc => {
                app.add_detour_form = None;
                app.active_column = ActiveColumn::Actions;
            }
            _ => {}
        }
    }
}
```

## Component Rendering Patterns

### List Panel Usage

```rust
use crate::components::list_panel;

fn draw_detours_list(f: &mut Frame, area: Rect, app: &mut App) {
    let modal_visible = app.is_modal_visible();
    let is_active = app.active_column == ActiveColumn::Content && !modal_visible;
    
    let items: Vec<list_panel::ItemRow> = app.detours.iter().map(|detour| {
        list_panel::ItemRow {
            line1: format!("{} → {}", detour.original, detour.custom),
            line2: Some(format!("   {} | {}", detour.status_text(), detour.size_display())),
            status_icon: Some(if detour.active { "✓" } else { "○" }.to_string()),
        }
    }).collect();
    
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

### Form Panel Usage

```rust
use crate::components::form_panel;

fn draw_add_detour_form(f: &mut Frame, area: Rect, app: &mut App) {
    let modal_visible = app.is_modal_visible();
    let is_active = app.active_column == ActiveColumn::Content && !modal_visible;
    
    if let Some(form) = &app.add_detour_form {
        let fields = vec![
            form_panel::FormField {
                label: "Original Path:".to_string(),
                value: form.original_path.clone(),
                placeholder: "/path/to/original/file".to_string(),
            },
            form_panel::FormField {
                label: "Custom Path:".to_string(),
                value: form.custom_path.clone(),
                placeholder: "/path/to/custom/file".to_string(),
            },
        ];
        
        let form_state = form_panel::FormState {
            active_field: form.active_field,
            cursor_pos: form.cursor_pos,
        };
        
        form_panel::draw_form_panel(
            f,
            area,
            if form.editing_index.is_some() { "Edit Detour" } else { "Add Detour" },
            &fields,
            &form_state,
            is_active,
            modal_visible,
        );
    }
}
```

## Popup Patterns

### Creating Popups

```rust
// Confirm popup
app.popup = Some(Popup::confirm(
    "Confirm Delete",
    format!("Delete this detour?\n\n{}\n→ {}", original, custom)
));

// Error popup
app.popup = Some(Popup::error(
    "Error",
    format!("Failed to apply detour: {}", error)
));

// Input popup
app.popup = Some(Popup::input(
    "Enter Name",
    "Profile name:"
));

// Info popup (auto-dismiss)
app.popup = Some(Popup::info(
    "Success",
    "Detour applied successfully"
));
```

### Popup Event Handling

```rust
fn handle_popup_keys(key: KeyEvent, app: &mut App) {
    if let Some(popup) = &mut app.popup {
        match key.code {
            KeyCode::Left | KeyCode::Right | KeyCode::Tab => {
                popup.handle_left();  // Toggle button selection
            }
            KeyCode::Enter => {
                if popup.is_yes_selected() {
                    // Handle yes action
                    app.popup = None;
                } else {
                    // Handle no action
                    app.popup = None;
                }
            }
            KeyCode::Esc => {
                app.popup = None;
            }
            _ => {
                // Handle input popup keys
                if let Popup::Input { .. } = popup {
                    match key.code {
                        KeyCode::Char(c) => popup.handle_char(c),
                        KeyCode::Backspace => popup.handle_backspace(),
                        KeyCode::Left => popup.move_cursor_left(),
                        KeyCode::Right => popup.move_cursor_right(),
                        _ => {}
                    }
                }
            }
        }
    }
}
```

## Toast Notification Patterns

### Adding Toasts

```rust
impl App {
    pub fn add_toast(&mut self, message: String, toast_type: ToastType) {
        self.toasts.push(Toast {
            message,
            toast_type,
            shown_at: std::time::Instant::now(),
        });
    }
}

// Usage
app.add_toast("Detour applied successfully".to_string(), ToastType::Success);
app.add_toast("Failed to apply detour".to_string(), ToastType::Error);
app.add_toast("Config reloaded".to_string(), ToastType::Info);
```

### Toast Rendering

```rust
fn draw_toasts(f: &mut Frame, area: Rect, app: &App) {
    if app.toasts.is_empty() {
        return;
    }
    
    // Calculate max width
    let max_width = app.toasts.iter()
        .map(|t| t.message.len() + 4)  // +4 for icon and padding
        .max()
        .unwrap_or(0);
    
    // Render from bottom-right, stacked upward
    let mut y_offset = 0;
    for toast in app.toasts.iter().rev() {
        let (icon, fg_color) = match toast.toast_type {
            ToastType::Success => ("✓", Color::Green),
            ToastType::Error => ("✗", Color::Red),
            ToastType::Info => ("ℹ", Color::Cyan),
        };
        
        let content = format!("{} {}", icon, toast.message);
        let padded = format!("  {}  ", content);
        
        // Left-pad to match max width
        let padding = max_width.saturating_sub(content.len());
        let padded_text = format!("{}{}", " ".repeat(padding), padded);
        
        let toast_area = Rect {
            x: area.width.saturating_sub(max_width as u16 + 2),
            y: area.height.saturating_sub(y_offset + 2),
            width: (max_width as u16 + 2).min(area.width),
            height: 1,
        };
        
        f.render_widget(Clear, toast_area);
        f.render_widget(
            Paragraph::new(padded_text)
                .style(Style::default().fg(fg_color).add_modifier(Modifier::BOLD)),
            toast_area
        );
        
        y_offset += 1;
    }
}
```

## File Operations Patterns

### Config Loading

```rust
pub fn load_config(path: &Path) -> Result<Config, ConfigError> {
    if !path.exists() {
        return Ok(Config::default());
    }
    
    let content = std::fs::read_to_string(path)
        .map_err(|e| ConfigError::ReadError(e.to_string()))?;
    
    let config: Config = serde_yaml::from_str(&content)
        .map_err(|e| ConfigError::ParseError(e.to_string()))?;
    
    Ok(config)
}
```

### Detour Operations

```rust
pub fn apply_detour(original: &Path, custom: &Path) -> Result<(), DetourError> {
    // Validate paths
    if !custom.exists() {
        return Err(DetourError::CustomNotFound);
    }
    
    // Create backup
    if original.exists() {
        let backup = original.with_extension("~");
        std::fs::copy(original, &backup)
            .map_err(|e| DetourError::BackupFailed(e.to_string()))?;
    }
    
    // Apply bind mount
    let output = std::process::Command::new("sudo")
        .arg("mount")
        .arg("--bind")
        .arg(custom)
        .arg(original)
        .output()
        .map_err(|e| DetourError::MountFailed(e.to_string()))?;
    
    if !output.status.success() {
        return Err(DetourError::MountFailed(
            String::from_utf8_lossy(&output.stderr).to_string()
        ));
    }
    
    Ok(())
}
```

## Error Handling Patterns

### Error Types

```rust
#[derive(Debug)]
pub enum DetourError {
    CustomNotFound,
    BackupFailed(String),
    MountFailed(String),
    UnmountFailed(String),
    PermissionDenied,
}

impl std::fmt::Display for DetourError {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        match self {
            DetourError::CustomNotFound => write!(f, "Custom file not found"),
            DetourError::BackupFailed(msg) => write!(f, "Backup failed: {}", msg),
            DetourError::MountFailed(msg) => write!(f, "Mount failed: {}", msg),
            DetourError::UnmountFailed(msg) => write!(f, "Unmount failed: {}", msg),
            DetourError::PermissionDenied => write!(f, "Permission denied"),
        }
    }
}

impl std::error::Error for DetourError {}
```

### Error Display Pattern

```rust
match apply_detour(&original, &custom) {
    Ok(()) => {
        app.add_toast("Detour applied successfully".to_string(), ToastType::Success);
        app.reload_detours();
    }
    Err(e) => {
        app.popup = Some(Popup::error("Error", &e.to_string()));
    }
}
```

## Validation Patterns

### Config Validation

```rust
pub fn validate_config(config: &Config) -> ValidationReport {
    let mut issues = Vec::new();
    
    for detour in &config.detours {
        // Check original path
        if !Path::new(&detour.original).exists() && !detour.original.starts_with('/') {
            issues.push(format!("Invalid original path: {}", detour.original));
        }
        
        // Check custom path
        if !Path::new(&detour.custom).exists() {
            issues.push(format!("Custom file not found: {}", detour.custom));
        }
        
        // Check paths are different
        if detour.original == detour.custom {
            issues.push(format!("Original and custom paths are the same: {}", detour.original));
        }
    }
    
    ValidationReport {
        content: if issues.is_empty() {
            "All detours are valid.".to_string()
        } else {
            format!("Found {} issue(s):\n\n{}", issues.len(), issues.join("\n"))
        },
        has_issues: !issues.is_empty(),
    }
}
```

## Best Practices

1. **State Updates**: Always update state immutably, don't mutate directly
2. **Error Handling**: Use Result types, show user-friendly errors
3. **Event Priority**: Handle overlays before forms, forms before navigation
4. **Component Reuse**: Use existing components when possible
5. **Clear Before Render**: Always clear modal/popup areas
6. **Empty States**: Always provide helpful empty state messages
7. **Validation**: Validate before applying operations
8. **User Feedback**: Show toasts for non-critical feedback, popups for critical errors

## Extension Patterns

### Adding New View

1. Add `ViewMode` variant
2. Add to `views` list in `App::new()`
3. Add content renderer in `ui.rs`
4. Add navigation logic in `events.rs`
5. Add view-specific actions

### Adding New Action

1. Add action to view's action list
2. Add handler in `app.rs`
3. Add UI feedback (toast/popup)
4. Update state if needed

### Adding New Form

1. Create form state structure
2. Create form renderer (use `form_panel` if possible)
3. Add form handlers in `events.rs`
4. Integrate with view mode

## Reference

- **Structure**: See `01-structure-guide.md`
- **Style**: See `02-style-guide.md`
- **Detailed Styling**: See `RUST-TUI-FORMATTING.md` in root
- **Code**: See `src/` directory for complete implementations

