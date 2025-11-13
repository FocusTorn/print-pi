# Universal Rust TUI Project Structure

## Purpose

This document defines the standard project structure and module organization for Rust TUI applications, ensuring consistency and proper setup from the start.

## Module Structure

### Required Modules

```
src/
├── main.rs          # Entry point (TUI launcher)
├── lib.rs           # Library root (module declarations)
├── app.rs           # Application state management
├── events.rs        # Event handling
├── ui.rs            # Main UI rendering
├── popup.rs         # Popup/dialog rendering
└── components/      # Reusable UI components
    ├── mod.rs       # Component module exports
    ├── list_panel.rs    # Universal list panel component
    ├── form_panel.rs    # Universal form panel component
    ├── file_browser.rs  # File browser component (optional)
    └── toast.rs         # Toast notification component
```

## Module Declarations (lib.rs)

### Standard Module Exports

```rust
// hasync library
// Core functionality for [package description]

// TUI modules
pub mod app;
pub mod events;
pub mod ui;
pub mod popup;

// Core functionality modules
pub mod sync;        // Package-specific modules
pub mod config;
pub mod validation;

// Component modules
pub mod components;
```

## Component Module Structure (components/mod.rs)

### Required Exports

```rust
// Reusable UI components

pub mod list_panel;
pub mod form_panel;
pub mod file_browser;
pub mod toast;

// Re-export commonly used types
pub use list_panel::{ItemRow, ListPanelTheme};
pub use form_panel::{FormField, FormState};
pub use file_browser::FileBrowser;
pub use toast::{Toast, ToastType};
```

## Main UI Function (ui.rs)

### Function Name and Signature

**CRITICAL**: The main UI rendering function MUST be named `ui()` (not `draw()`):

```rust
pub fn ui(f: &mut Frame, app: &mut App) {
    // UI rendering code
}
```

### Why `ui()`?

- Consistent with Detour reference implementation
- Matches the calling pattern: `terminal.draw(|f| hasync::ui::ui(f, app))?`
- Clear and concise naming

## App Structure Requirements

### Required Fields

The `App` struct MUST include these fields:

```rust
pub struct App {
    // Navigation state
    pub active_column: ActiveColumn,
    pub view_mode: ViewMode,
    pub view_state: ListState,
    pub action_state: ListState,
    pub content_state: ListState,
    
    // Views and selections
    pub views: Vec<String>,           // REQUIRED: List of view names
    pub selected_view: usize,          // REQUIRED: Current view selection index
    pub selected_action: usize,        // REQUIRED: Current action selection index
    
    // Modal/overlay state
    pub popup: Option<Popup>,
    pub file_browser: Option<FileBrowser>,
    
    // Package-specific data
    pub data: Vec<DataItem>,
    pub config: Config,
    
    // UI state
    pub toasts: Vec<Toast>,
    pub should_quit: bool,
    pub logs: Vec<LogEntry>,
}
```

### Required Methods

The `App` impl MUST include these methods:

```rust
impl App {
    /// Get current actions based on view mode
    pub fn get_current_actions(&self) -> Vec<String> {
        match self.view_mode {
            ViewMode::List => vec!["List".to_string(), "New".to_string()],
            ViewMode::Add => vec!["Add".to_string()],
            // ... view-specific actions
            _ => vec![],
        }
    }
    
    /// Get current description based on view mode
    pub fn get_current_description(&self) -> String {
        match self.view_mode {
            ViewMode::List => "Manage items".to_string(),
            ViewMode::Add => "Add a new item".to_string(),
            // ... view-specific descriptions
        }
    }
    
    /// Convert view index to ViewMode
    pub fn view_mode_from_index(index: usize) -> ViewMode {
        match index {
            0 => ViewMode::List,
            1 => ViewMode::Add,
            _ => ViewMode::List,
        }
    }
}
```

## Popup Module Structure (popup.rs)

### Required Function

The popup module MUST export a `draw_popup()` function:

```rust
pub fn draw_popup(f: &mut Frame, area: Rect, popup: &Popup) {
    match popup {
        Popup::Confirm { title, message, selected } => {
            draw_confirm(f, area, title, message, *selected);
        }
        Popup::Input { title, prompt, input, cursor_pos } => {
            draw_input(f, area, title, prompt, input, *cursor_pos);
        }
        Popup::Error { title, message } => {
            draw_error(f, area, title, message);
        }
        Popup::Info { title, message, .. } => {
            draw_info(f, area, title, message);
        }
    }
}
```

## Toast Structure

### Important: Use SystemTime

**CRITICAL**: Toasts MUST use `SystemTime` for `shown_at`, NOT `Instant`:

```rust
use std::time::SystemTime;

#[derive(Debug, Clone)]
pub struct Toast {
    pub message: String,
    pub toast_type: ToastType,
    pub shown_at: SystemTime,  // NOT Instant
}
```

### Why SystemTime?

- Consistent with Detour reference implementation
- Works correctly with auto-dismiss logic in event handlers
- Compatible with duration calculations

## Component Implementation

### List Panel Component

**MUST** be implemented in `components/list_panel.rs` with the exact signature from `04-component-patterns.md`.

### Form Panel Component

**MUST** be implemented in `components/form_panel.rs` with the exact signature from `04-component-patterns.md`.

## Initialization Pattern

### App::new() Structure

```rust
impl App {
    pub fn new() -> Self {
        // Load configuration
        let config = Config::load().unwrap_or_default();
        
        // Load data
        let data = load_data(&config);
        
        // Initialize views
        let views = vec![
            "List".to_string(),
            "Add".to_string(),
            // ... other views
        ];
        
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
            data,
            config,
            toasts: vec![],
            should_quit: false,
            logs: vec![],
        }
    }
}
```

## Main Function Pattern

### Standard Main Function

```rust
fn main() -> Result<()> {
    // Setup terminal
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    // Create application
    let mut app = App::new();

    // Run application
    let result = run(&mut terminal, &mut app);

    // Restore terminal
    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;
    terminal.show_cursor()?;

    result
}

fn run(terminal: &mut Terminal<CrosstermBackend<io::Stdout>>, app: &mut App) -> Result<()> {
    loop {
        terminal.draw(|f| hasync::ui::ui(f, app))?;  // Note: ui::ui()

        if app.should_quit {
            break;
        }

        // Handle events
        if event::poll(std::time::Duration::from_millis(100))? {
            if let Event::Key(key) = event::read()? {
                if key.code == KeyCode::Char('q') || key.code == KeyCode::Char('Q') {
                    app.should_quit = true;
                } else {
                    hasync::events::handle_key_event(key, app);
                }
            }
        }
    }

    Ok(())
}
```

## Implementation Checklist

When setting up a new TUI project:

- [ ] Create `components/list_panel.rs` with universal list panel implementation
- [ ] Create `components/form_panel.rs` with universal form panel implementation
- [ ] Create `components/mod.rs` with proper exports
- [ ] Add `views: Vec<String>` field to App struct
- [ ] Add `selected_view: usize` and `selected_action: usize` fields
- [ ] Implement `get_current_actions()` method
- [ ] Implement `get_current_description()` method
- [ ] Implement `view_mode_from_index()` helper
- [ ] Name main UI function `ui()` (not `draw()`)
- [ ] Export `draw_popup()` function from popup module
- [ ] Use `SystemTime` for toast `shown_at` field
- [ ] Initialize views in `App::new()`
- [ ] Use `ui::ui()` in main run loop

## Common Mistakes to Avoid

1. **❌ Naming UI function `draw()`** → ✅ Must be `ui()`
2. **❌ Missing `views` field** → ✅ Must include `views: Vec<String>`
3. **❌ Missing `get_current_actions()`** → ✅ Must implement this method
4. **❌ Using `Instant` for toasts** → ✅ Must use `SystemTime`
5. **❌ Not exporting components** → ✅ Must export in `components/mod.rs`
6. **❌ Missing `draw_popup()` export** → ✅ Must export from popup module

## Reference

- **Component Patterns**: See `04-component-patterns.md` for component implementations
- **State Management**: See `06-state-management.md` for state patterns
- **Layout Patterns**: See `03-layout-patterns.md` for layout structure
- **Implementation**: See Detour package for reference implementation

