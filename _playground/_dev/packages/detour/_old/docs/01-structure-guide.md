# Detour Structure Guide for AI Agents

## Purpose

This document provides a complete guide for AI agents to recreate the Detour TUI package structure, architecture, and implementation patterns. Use this when creating similar Rust TUI applications or extending Detour functionality.

## Package Structure

### Directory Layout

```
detour/
├── src/                    # Rust source code
│   ├── main.rs            # Entry point (TUI launcher)
│   ├── lib.rs             # Library root (module declarations)
│   ├── app.rs             # Application state management
│   ├── events.rs          # Event handling (keyboard, mouse)
│   ├── ui.rs              # Main UI rendering orchestration
│   ├── popup.rs           # Popup/dialog rendering
│   ├── filebrowser.rs     # File browser component
│   ├── diff.rs            # Diff viewer component
│   ├── config.rs          # Configuration parsing
│   ├── manager.rs         # Detour operations manager
│   ├── injection.rs       # Include injection logic
│   ├── mirror.rs          # Mirror operations
│   ├── validation.rs      # Validation logic
│   ├── components/        # Reusable UI components
│   │   ├── mod.rs
│   │   ├── list_panel.rs  # Generic list panel component
│   │   └── form_panel.rs  # Generic form panel component
│   ├── forms/             # Form-specific implementations
│   └── operations/        # Operation-specific logic
├── lib/                   # Shell script implementation (legacy)
│   └── detour-core.sh
├── bin/                   # Binary wrapper scripts
├── docs/                  # Documentation
├── examples/              # Example configurations
├── Cargo.toml            # Rust project configuration
├── install.sh            # Installation script
├── uninstall.sh          # Uninstallation script
├── run-tui.sh            # Development runner script
└── README.md             # User-facing documentation
```

## Module Organization

### Core Modules

#### `src/lib.rs`
- **Purpose**: Module declarations and public API
- **Pattern**: Declares all modules, re-exports public items
- **Structure**:
  ```rust
  // TUI modules
  pub mod app;
  pub mod events;
  pub mod ui;
  pub mod popup;
  pub mod diff;
  pub mod filebrowser;
  
  // Core functionality modules
  pub mod config;
  pub mod manager;
  pub mod injection;
  pub mod mirror;
  pub mod components;
  pub mod forms;
  pub mod operations;
  pub mod validation;
  ```

#### `src/main.rs`
- **Purpose**: CLI entry point and TUI launcher
- **Pattern**: Uses `clap` for CLI, launches TUI if no command
- **Key Responsibilities**:
  - Parse CLI arguments
  - Handle build commands (dev/release)
  - Initialize terminal (raw mode, alternate screen)
  - Create app state
  - Run main event loop
  - Cleanup terminal on exit

#### `src/app.rs`
- **Purpose**: Central application state management
- **Key Structures**:
  - `App` - Main application state
  - `ActiveColumn` - Enum for column focus (Views, Actions, Content)
  - `ViewMode` - Enum for current view (DetoursList, DetoursAdd, etc.)
  - `FormAction` - Enum for form input actions
  - `ValidationReport` - Validation results
  - `Toast` - Toast notification structure
- **Responsibilities**:
  - Maintain current view/action state
  - Manage column focus
  - Handle navigation between views
  - Manage modal/popup state
  - Store form data and state
  - Manage toast notifications
  - Coordinate with managers (config, detour, etc.)

#### `src/events.rs`
- **Purpose**: Handle all user input events
- **Pattern**: Centralized event handling with context-specific routing
- **Key Functions**:
  - `handle_events()` - Main event loop handler
  - `handle_key_event()` - Keyboard event routing
  - `handle_mouse_event()` - Mouse event routing
  - Context-specific handlers (forms, popups, file browser, etc.)
- **Navigation Pattern**:
  1. Check for modal/popup active → handle modal-specific keys
  2. Check for file browser → handle browser-specific keys
  3. Check for form active → handle form-specific keys
  4. Handle global navigation keys
  5. Route to view-specific handlers

#### `src/ui.rs`
- **Purpose**: Main UI rendering orchestration
- **Pattern**: Top-level rendering function that coordinates all widgets
- **Key Functions**:
  - `ui()` - Main rendering function
  - `draw_title()` - Title bar rendering
  - `draw_view_column()` - Column 1 (Views)
  - `draw_action_column()` - Column 2 (Actions)
  - `draw_content_column()` - Column 3 (Content)
  - `draw_bottom_status()` - Status bar rendering
  - `draw_toasts()` - Toast notification rendering
  - `centered_rect()` - Helper for centered popups
  - View-specific content renderers (detours list, forms, etc.)

### Component Modules

#### `src/components/list_panel.rs`
- **Purpose**: Reusable list panel component
- **Pattern**: Generic list rendering with selection, scrolling, modal dimming
- **Key Structures**:
  - `ItemRow` - List item data structure
  - `ListPanelTheme` - Theming configuration
- **Features**:
  - Multi-line list items (line1 + optional line2)
  - Status icons support
  - Empty state handling
  - Selection highlighting
  - Modal dimming support
  - Dynamic border styling

#### `src/components/form_panel.rs`
- **Purpose**: Reusable form panel component
- **Pattern**: Generic form rendering with fields, cursor, placeholders
- **Key Structures**:
  - `FormField` - Form field data structure
  - `FormState` - Form state (active field, cursor position)
- **Features**:
  - Compact and normal modes (based on available height)
  - Cursor rendering with split_at method
  - Placeholder text support
  - Active field highlighting
  - Modal dimming support

### Specialized Modules

#### `src/popup.rs`
- **Purpose**: Popup/dialog rendering and management
- **Pattern**: Enum-based popup types with specific renderers
- **Popup Types**:
  - `Confirm` - Yes/No confirmation dialog
  - `Input` - Text input dialog
  - `Error` - Error message dialog
  - `Info` - Information message dialog
- **Features**:
  - Content-based sizing (not fixed percentages)
  - Text wrapping
  - Button selection (for Confirm popup)
  - Cursor management (for Input popup)
  - Auto-dismiss (for Info popup)

#### `src/filebrowser.rs`
- **Purpose**: File browser component for path selection
- **Pattern**: Stateful component with directory navigation
- **Features**:
  - Directory listing with parent navigation
  - File/directory icons
  - Selection persistence when navigating
  - Scroll management
  - Mouse wheel support

#### `src/diff.rs`
- **Purpose**: Side-by-side diff viewer
- **Pattern**: Two-panel layout with line numbers
- **Features**:
  - Side-by-side file comparison
  - Line number display
  - Scroll synchronization
  - Keyboard navigation

## State Management Pattern

### Application State Flow

```
User Input → events.rs → app.rs → ui.rs → Terminal
                ↓
          State Updates
                ↓
          Re-render
```

### Key State Management Principles

1. **Single Source of Truth**: All state in `App` struct
2. **Immutable Updates**: Create new state, don't mutate directly
3. **Event-Driven**: All changes triggered by events
4. **Modal State**: Centralized modal/popup state management
5. **Focus Management**: Explicit column/view focus tracking

### State Structure Example

```rust
pub struct App {
    // Navigation state
    pub active_column: ActiveColumn,
    pub view_mode: ViewMode,
    pub view_state: ListState,
    pub action_state: ListState,
    
    // Modal/popup state
    pub popup: Option<Popup>,
    pub file_browser: Option<FileBrowser>,
    pub validation_report: Option<ValidationReport>,
    pub diff_viewer: Option<DiffViewer>,
    
    // Form state
    pub add_detour_form: Option<AddDetourForm>,
    
    // Data state
    pub detours: Vec<Detour>,
    pub config: Config,
    
    // UI state
    pub toasts: Vec<Toast>,
    pub should_quit: bool,
}
```

## Event Handling Pattern

### Event Routing Hierarchy

```
1. File Browser Active? → Handle browser keys
2. Popup Active? → Handle popup keys
3. Validation Report Active? → Handle report keys
4. Diff Viewer Active? → Handle diff keys
5. Form Active? → Handle form keys
6. Global Navigation → Handle navigation keys
7. View-Specific → Handle view-specific keys
```

### Key Event Handling Example

```rust
fn handle_key_event(key: KeyEvent, app: &mut App) {
    // Priority 1: Modal/overlay components
    if app.file_browser.is_some() {
        handle_file_browser_keys(key, app);
        return;
    }
    
    if app.popup.is_some() {
        handle_popup_keys(key, app);
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
        // ... more navigation
    }
}
```

## Rendering Pattern

### Rendering Order

```
1. Background (clear screen)
2. Title bar
3. Column 1 (Views)
4. Column 2 (Actions)
5. Column 3 (Content)
6. Bottom status area
7. Validation report (if active)
8. Diff viewer (if active)
9. Popup (if active)
10. File browser (if active)
11. Toasts (always last, overlay everything)
```

### Modal Dimming Pattern

**Important**: No global overlay! Dimming is conditional per widget.

```rust
let modal_visible = app.is_modal_visible();
let text_color = if modal_visible {
    hex_color(0x444444)  // Dimmed
} else if is_active {
    hex_color(0xFFFFFF)  // Active
} else {
    hex_color(0x777777)  // Inactive
};
```

## Component Reusability

### When to Create Reusable Components

1. **List Panel**: Use `components/list_panel.rs` for any list rendering
2. **Form Panel**: Use `components/form_panel.rs` for any form rendering
3. **Custom Components**: Create new components for domain-specific UI

### Component Usage Pattern

```rust
// In ui.rs or view-specific renderer
use crate::components::{list_panel, form_panel};

// Render list
list_panel::draw_list_panel(
    f,
    area,
    "Title",
    &items,
    &mut app.list_state,
    is_active,
    modal_visible,
    &theme,
);

// Render form
form_panel::draw_form_panel(
    f,
    area,
    "Form Title",
    &fields,
    &form_state,
    is_active,
    modal_visible,
);
```

## Configuration Management

### Config Structure

- **Location**: `~/.detour.yaml` (YAML format)
- **Parsing**: `src/config.rs` handles YAML parsing
- **Validation**: `src/validation.rs` validates config
- **Manager**: `src/manager.rs` coordinates operations

### Config Loading Pattern

```rust
// Load config on app startup
let config = config::load_config(&config_path)?;

// Validate config
let validation = validation::validate_config(&config)?;

// Apply detours
manager::apply_detours(&config)?;
```

## Error Handling Pattern

### Error Propagation

```rust
// Use Result types for fallible operations
fn load_config(path: &Path) -> Result<Config, ConfigError> {
    // ... load and parse
}

// Handle errors in UI
match load_config(&path) {
    Ok(config) => app.config = config,
    Err(e) => {
        app.popup = Some(Popup::error("Config Error", &e.to_string()));
    }
}
```

### User-Facing Errors

- **Critical Errors**: Show error popup (blocks interaction)
- **Non-Critical Errors**: Show error toast (auto-dismiss)
- **Validation Errors**: Show validation report panel

## Testing Strategy

### Unit Tests

- Test individual functions in isolation
- Mock file system operations
- Test state transitions

### Integration Tests

- Test full workflows
- Test error scenarios
- Test UI state management

### Manual Testing Checklist

See `RUST-TUI-FORMATTING.md` testing checklist for UI component verification.

## Extension Points

### Adding New Views

1. Add `ViewMode` variant in `app.rs`
2. Add view to `views` list in `App::new()`
3. Add content renderer in `ui.rs`
4. Add navigation logic in `events.rs`
5. Add view-specific actions in `app.rs`

### Adding New Popup Types

1. Add variant to `Popup` enum in `popup.rs`
2. Add renderer function
3. Add event handlers in `events.rs`
4. Add popup creation logic in `app.rs`

### Adding New Form Types

1. Create form state structure
2. Create form renderer (or use `form_panel`)
3. Add form handlers in `events.rs`
4. Integrate with view mode

## Best Practices

1. **Consistent State Checks**: Always check `modal_visible` and `is_active`
2. **Use Helper Functions**: Prefer `get_selection_style()`, `accent_color()`, etc.
3. **Clear Before Render**: Always clear modal/popup areas
4. **Empty State Handling**: Always provide helpful empty states
5. **Scroll Management**: Update visible height on every render
6. **Component Reusability**: Use existing components when possible
7. **Error Handling**: Use Result types, show user-friendly errors
8. **Code Organization**: Keep modules focused and cohesive

## Reference Implementation

For complete reference, see:
- `src/ui.rs` - Main UI rendering
- `src/components/` - Reusable components
- `src/app.rs` - State management
- `src/events.rs` - Event handling
- `RUST-TUI-FORMATTING.md` - Visual styling guide

## Next Steps

1. Review `02-style-guide.md` for visual design patterns
2. Review `03-implementation-patterns.md` for code patterns
3. Reference `RUST-TUI-FORMATTING.md` for detailed styling
4. Study existing code for concrete examples

