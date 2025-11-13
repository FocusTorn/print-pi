# Universal Rust TUI State Management Patterns

## Purpose

This document defines universal state management patterns for Rust TUI applications, ensuring consistent and predictable state handling across all TUI projects.

## Application State Structure

### Standard State Structure

```rust
pub struct App {
    // Navigation state
    pub active_column: ActiveColumn,
    pub view_mode: ViewMode,
    pub view_state: ListState,
    pub action_state: ListState,
    pub content_state: ListState,
    
    // Views and selections (REQUIRED)
    pub views: Vec<String>,           // List of view names
    pub selected_view: usize,          // Current view selection index
    pub selected_action: usize,        // Current action selection index
    
    // Modal/overlay state
    pub popup: Option<Popup>,
    pub file_browser: Option<FileBrowser>,
    pub validation_report: Option<ValidationReport>,
    pub diff_viewer: Option<DiffViewer>,
    
    // Form state
    pub form: Option<FormState>,
    
    // Data state
    pub data: Vec<DataItem>,
    pub config: Config,
    
    // Hierarchical state (for parent-child relationships)
    pub parents: Vec<ParentItem>,           // Parent items (e.g., scripts)
    pub selected_parent: Option<usize>,      // Selected parent index
    // Note: Children are stored within ParentItem, content_state tracks child selection
    
    // UI state
    pub toasts: Vec<Toast>,
    pub should_quit: bool,
    pub logs: Vec<LogEntry>,
}
```

### Navigation State Enums

```rust
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ActiveColumn {
    Views,
    Actions,
    Content,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ViewMode {
    List,
    Add,
    Edit,
    // ... view-specific modes
}
```

## State Initialization Pattern

### Standard Initialization

```rust
impl App {
    pub fn new() -> Self {
        // Load configuration
        let config_path = get_config_path();
        let config = config::load_config(&config_path).unwrap_or_default();
        
        // Load data
        let data = load_data(&config);
        
        // Initialize views
        let views = vec![
            "List".to_string(),
            "Add".to_string(),
            // ... other views
        ];
        
        // Initialize state
        App {
            active_column: ActiveColumn::Views,
            view_mode: ViewMode::List,
            view_state: ListState::default().with_selected(Some(0)),
            action_state: ListState::default().with_selected(Some(0)),
            content_state: ListState::default(),
            views,
            selected_view: 0,
            selected_action: 0,
            popup: None,
            file_browser: None,
            validation_report: None,
            diff_viewer: None,
            form: None,
            data,
            config,
            toasts: vec![],
            should_quit: false,
            logs: vec![],
        }
    }
}
```

## Modal State Management

### Modal State Check

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

### Opening Modals

```rust
// Open confirm popup
app.popup = Some(Popup::Confirm {
    title: "Confirm Delete".to_string(),
    message: "Delete this item?".to_string(),
    selected: 1,  // Default to "No" for safety
});

// Open file browser
app.file_browser = Some(FileBrowser::new("/home/pi"));

// Open validation report
app.validation_report = Some(ValidationReport {
    content: "Validation results...".to_string(),
    has_issues: false,
});
```

### Closing Modals

```rust
// Close popup
app.popup = None;

// Close file browser
app.file_browser = None;

// Close validation report
app.validation_report = None;
```

## State Update Patterns

### Immutable Updates

Prefer creating new state over mutating existing state:

```rust
// Good: Create new state
app.data = app.data.iter().map(|item| {
    if item.id == updated_id {
        updated_item.clone()
    } else {
        item.clone()
    }
}).collect();

// Also acceptable: Mutate in place for performance
if let Some(item) = app.data.iter_mut().find(|i| i.id == updated_id) {
    *item = updated_item.clone();
}
```

### Navigation State Updates

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
                self.navigate_content_up();
            }
        }
    }
    
    pub fn update_view_mode(&mut self) {
        if let Some(selected) = self.view_state.selected() {
            self.view_mode = match selected {
                0 => ViewMode::List,
                1 => ViewMode::Add,
                _ => ViewMode::List,
            };
            // Reset action state
            self.action_state.select(Some(0));
        }
    }
}
```

## Toast Notification Management

### Adding Toasts

**IMPORTANT**: Toasts MUST use `SystemTime` for `shown_at`, NOT `Instant`:

```rust
use std::time::SystemTime;

impl App {
    pub fn add_toast(&mut self, message: String, toast_type: ToastType) {
        self.toasts.push(Toast {
            message,
            toast_type,
            shown_at: SystemTime::now(),  // NOT Instant::now()
        });
    }
}
```

### Auto-Dismiss Logic

**IMPORTANT**: Toast auto-dismiss MUST be handled in the event handler, not in UI rendering:

```rust
// In event handler (events.rs)
use std::time::{SystemTime, UNIX_EPOCH};

pub fn handle_key_event(key: KeyEvent, app: &mut App) {
    // Auto-dismiss toasts (2.5 seconds)
    let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default();
    app.toasts.retain(|toast| {
        let toast_time = toast.shown_at.duration_since(UNIX_EPOCH).unwrap_or_default();
        let elapsed = now.saturating_sub(toast_time);
        elapsed.as_secs_f32() <= 2.5
    });
    
    // ... rest of event handling
}
```

## Form State Management

### Form State Structure

```rust
pub struct FormState {
    pub fields: Vec<FormField>,
    pub active_field: usize,
    pub cursor_pos: usize,
    pub editing_index: Option<usize>,  // None = new, Some(idx) = editing
}
```

### Creating Form State

```rust
// New form
let form = FormState {
    fields: vec![
        FormField { label: "Field 1".to_string(), value: String::new(), placeholder: "Enter value".to_string() },
        FormField { label: "Field 2".to_string(), value: String::new(), placeholder: "Enter value".to_string() },
    ],
    active_field: 0,
    cursor_pos: 0,
    editing_index: None,
};

// Edit form (pre-populated)
let form = FormState {
    fields: vec![
        FormField { label: "Field 1".to_string(), value: existing_item.field1.clone(), placeholder: "Enter value".to_string() },
        FormField { label: "Field 2".to_string(), value: existing_item.field2.clone(), placeholder: "Enter value".to_string() },
    ],
    active_field: 0,
    cursor_pos: 0,
    editing_index: Some(item_index),
};
```

### Submitting Form

```rust
impl App {
    pub fn submit_form(&mut self) {
        if let Some(form) = &self.form {
            // Validate form
            if let Err(e) = self.validate_form(form) {
                self.popup = Some(Popup::error("Validation Error", &e));
                return;
            }
            
            // Save data
            if let Some(index) = form.editing_index {
                // Update existing
                self.update_item(index, form);
                self.add_toast("Item updated successfully".to_string(), ToastType::Success);
            } else {
                // Create new
                self.add_item(form);
                self.add_toast("Item created successfully".to_string(), ToastType::Success);
            }
            
            // Close form
            self.form = None;
            self.active_column = ActiveColumn::Actions;
            
            // Reload data
            self.reload_data();
        }
    }
}
```

## Error Handling in State

### Error State Pattern

```rust
// Show error popup for critical errors
match operation() {
    Ok(result) => {
        app.data = result;
        app.add_toast("Operation successful".to_string(), ToastType::Success);
    }
    Err(e) => {
        app.popup = Some(Popup::error("Error", &e.to_string()));
    }
}

// Show error toast for non-critical errors
match operation() {
    Ok(_) => {
        app.add_toast("Operation successful".to_string(), ToastType::Success);
    }
    Err(e) => {
        app.add_toast(format!("Operation failed: {}", e), ToastType::Error);
    }
}
```

## Data Reloading Pattern

### Reload Data

```rust
impl App {
    pub fn reload_data(&mut self) {
        // Reload from source
        self.data = load_data(&self.config);
        
        // Reset selection if current selection is invalid
        if let Some(selected) = self.content_state.selected() {
            if selected >= self.data.len() {
                if self.data.is_empty() {
                    self.content_state.select(None);
                } else {
                    self.content_state.select(Some(self.data.len() - 1));
                }
            }
        }
    }
}
```

## State Persistence

### Save State (if needed)

```rust
impl App {
    pub fn save_state(&self) -> Result<(), Error> {
        // Save configuration
        config::save_config(&self.config_path, &self.config)?;
        Ok(())
    }
}
```

## Required App Methods

### get_current_actions()

**REQUIRED**: Must implement this method to return actions for current view mode:

```rust
impl App {
    pub fn get_current_actions(&self) -> Vec<String> {
        match self.view_mode {
            ViewMode::List => vec!["List".to_string(), "New".to_string()],
            ViewMode::Add => vec!["Add".to_string()],
            // ... view-specific actions
            _ => vec![],
        }
    }
}
```

### get_current_description()

**REQUIRED**: Must implement this method to return description for current view mode:

```rust
impl App {
    pub fn get_current_description(&self) -> String {
        match self.view_mode {
            ViewMode::List => "Manage items".to_string(),
            ViewMode::Add => "Add a new item".to_string(),
            // ... view-specific descriptions
        }
    }
}
```

### view_mode_from_index()

**REQUIRED**: Must implement this helper to convert view index to ViewMode:

```rust
impl App {
    pub fn view_mode_from_index(index: usize) -> ViewMode {
        match index {
            0 => ViewMode::List,
            1 => ViewMode::Add,
            _ => ViewMode::List,
        }
    }
}
```

## Hierarchical State Management

### Two-Level Navigation Pattern

For hierarchical views (e.g., scripts → files), use additional state fields:

```rust
pub struct ParentItem {
    pub name: String,
    pub children: Vec<ChildItem>,
    // ... other parent fields
}

pub struct ChildItem {
    pub name: String,
    pub relative_path: PathBuf,
    pub source_path: PathBuf,
    pub dest_path: PathBuf,
    pub source_mtime: Option<SystemTime>,
    pub dest_mtime: Option<SystemTime>,
    pub needs_sync: bool,
    // ... other child fields
}

pub struct App {
    // ... other fields ...
    pub parents: Vec<ParentItem>,
    pub selected_parent: Option<usize>,  // None = showing parent list, Some(idx) = showing children
    // content_state tracks selection within current level (parent list or child list)
}
```

### Hierarchical Navigation State

```rust
impl App {
    pub fn navigate_hierarchical_up(&mut self) {
        match self.active_column {
            ActiveColumn::Content => {
                if self.selected_parent.is_none() {
                    // Navigating parent list
                    if let Some(selected) = self.content_state.selected() {
                        if selected > 0 {
                            self.content_state.select(Some(selected - 1));
                        }
                    }
                } else {
                    // Navigating child list
                    if let Some(selected) = self.content_state.selected() {
                        if selected > 0 {
                            self.content_state.select(Some(selected - 1));
                        }
                    }
                }
            }
            // ... other columns
        }
    }
    
    pub fn navigate_hierarchical_down(&mut self) {
        match self.active_column {
            ActiveColumn::Content => {
                if self.selected_parent.is_none() {
                    // Navigating parent list
                    if let Some(selected) = self.content_state.selected() {
                        let max = self.parents.len().saturating_sub(1);
                        if selected < max {
                            self.content_state.select(Some(selected + 1));
                        }
                    }
                } else {
                    // Navigating child list
                    if let Some(parent_index) = self.selected_parent {
                        if let Some(parent) = self.parents.get(parent_index) {
                            if let Some(selected) = self.content_state.selected() {
                                let max = parent.children.len().saturating_sub(1);
                                if selected < max {
                                    self.content_state.select(Some(selected + 1));
                                }
                            }
                        }
                    }
                }
            }
            // ... other columns
        }
    }
    
    pub fn select_parent(&mut self, index: usize) {
        if index < self.parents.len() {
            self.selected_parent = Some(index);
            self.update_parent_status(index);
            // Reset to start of child list
            self.content_state.select(Some(0));
        }
    }
    
    pub fn deselect_parent(&mut self) {
        self.selected_parent = None;
        self.content_state.select(Some(0));
    }
}
```

### Scanning Hierarchical Data

For directory/file synchronization, scan and populate hierarchical data:

```rust
fn scan_parent_directory(source: &Path, destination: &Path, recursive: bool) -> Vec<ChildItem> {
    let mut children = Vec::new();
    
    if !source.exists() || !source.is_dir() {
        return children;
    }
    
    scan_directory_recursive(source, destination, source, &mut children, recursive);
    children.sort_by(|a, b| a.relative_path.cmp(&b.relative_path));
    children
}

fn scan_directory_recursive(
    source_root: &Path,
    dest_root: &Path,
    current_source: &Path,
    children: &mut Vec<ChildItem>,
    recursive: bool,
) {
    if let Ok(entries) = std::fs::read_dir(current_source) {
        for entry in entries.flatten() {
            let source_path = entry.path();
            
            if source_path.is_dir() {
                if recursive {
                    scan_directory_recursive(source_root, dest_root, &source_path, children, recursive);
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
            let source_mtime = get_file_mtime(&source_path);
            let dest_mtime = get_file_mtime(&dest_path);
            
            // Determine if file needs sync
            let needs_sync = match (source_mtime, dest_mtime) {
                (Some(src_time), Some(dst_time)) => src_time > dst_time,
                (Some(_), None) => true,  // Source exists, dest doesn't
                (None, Some(_)) => false, // Source doesn't exist (shouldn't happen)
                (None, None) => false,
            };
            
            children.push(ChildItem {
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
```

## Best Practices

1. **Single Source of Truth**: All state in `App` struct
2. **Immutable Updates**: Prefer creating new state when possible
3. **Modal State Centralization**: Centralized modal state management
4. **State Validation**: Validate state before applying operations
5. **Error Handling**: Handle errors gracefully with user feedback
6. **State Reloading**: Reload data after operations
7. **Selection Management**: Maintain valid selections after data changes
8. **Required Methods**: Always implement `get_current_actions()`, `get_current_description()`, and `view_mode_from_index()`
9. **Hierarchical State**: Use `selected_parent: Option<usize>` for two-level navigation
10. **Content State Reuse**: Use `content_state` for both parent and child list navigation

## Implementation Checklist

When implementing state management:

- [ ] Define clear state structure
- [ ] Initialize state properly
- [ ] Implement modal state checks
- [ ] Handle state updates correctly
- [ ] Manage form state
- [ ] Handle toast notifications
- [ ] Implement error handling
- [ ] Reload data after operations
- [ ] Maintain valid selections
- [ ] Test state transitions
- [ ] For hierarchical views: Add `selected_parent: Option<usize>` field
- [ ] For hierarchical views: Implement parent selection/deselection methods
- [ ] For hierarchical views: Handle navigation at both parent and child levels

## Reference

- **Event Handling**: See `05-event-handling.md` for state update triggers
- **Component Patterns**: See `04-component-patterns.md` for component state
- **Layout Patterns**: See `03-layout-patterns.md` for layout state
- **Implementation**: See Detour package for reference implementation

