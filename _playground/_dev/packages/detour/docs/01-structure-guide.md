# Detour Structure Guide for AI Agents

## Purpose

This document provides a complete guide for AI agents to understand Detour's package structure and Detour-specific implementation patterns. For universal Rust TUI patterns, see `_dev/_docs/rust/`.

## Universal Patterns Reference

**Before reading this guide, familiarize yourself with universal patterns:**
- **Structure & Architecture**: `_dev/_docs/rust/README.md`
- **Color Palette**: `_dev/_docs/rust/01-color-palette.md`
- **Styling Helpers**: `_dev/_docs/rust/02-styling-helpers.md`
- **Layout Patterns**: `_dev/_docs/rust/03-layout-patterns.md`
- **Component Patterns**: `_dev/_docs/rust/04-component-patterns.md`
- **Event Handling**: `_dev/_docs/rust/05-event-handling.md`
- **State Management**: `_dev/_docs/rust/06-state-management.md`

This guide focuses on **Detour-specific** implementation details and extensions.

## Package Structure

### Directory Layout

```
detour/
├── src/                    # Rust source code
│   ├── main.rs            # Entry point (TUI launcher)
│   ├── lib.rs             # Library root (module declarations)
│   ├── app.rs             # Application state management (Detour-specific)
│   ├── events.rs          # Event handling (extends universal patterns)
│   ├── ui.rs              # Main UI rendering (Detour-specific views)
│   ├── popup.rs           # Popup/dialog rendering (extends universal)
│   ├── filebrowser.rs     # File browser component (extends universal)
│   ├── diff.rs            # Diff viewer component (Detour-specific)
│   ├── config.rs          # Detour configuration parsing
│   ├── manager.rs         # Detour operations manager
│   ├── injection.rs       # Include injection logic (Detour-specific)
│   ├── mirror.rs          # Mirror operations (Detour-specific)
│   ├── validation.rs      # Detour validation logic
│   ├── components/        # Reusable UI components (universal patterns)
│   │   ├── mod.rs
│   │   ├── list_panel.rs  # Universal list panel
│   │   └── form_panel.rs  # Universal form panel
│   ├── forms/             # Detour-specific form implementations
│   └── operations/        # Detour operation-specific logic
├── lib/                   # Shell script implementation (legacy)
│   └── detour-core.sh
├── bin/                   # Binary wrapper scripts
├── docs/                  # Detour-specific documentation
├── examples/              # Example configurations
├── Cargo.toml            # Rust project configuration
├── install.sh            # Installation script
├── uninstall.sh          # Uninstallation script
├── run-tui.sh            # Development runner script
└── README.md             # User-facing documentation
```

## Detour-Specific Modules

### `src/config.rs`

**Purpose**: Detour configuration parsing and management

**Detour-Specific Features**:
- YAML configuration parsing (`~/.detour.yaml`)
- Detour directive parsing: `detour <original> = <custom>`
- Include directive parsing: `include <target> : <include_file>`
- Service directive parsing: `service <name> : <action>`
- Profile management (multiple config sets)
- Runtime config vs TUI build config separation

**Key Structures**:
```rust
pub struct Config {
    pub detours: Vec<DetourConfig>,
    pub includes: Vec<IncludeConfig>,
    pub services: Vec<ServiceConfig>,
    pub profile: String,
}

pub struct DetourConfig {
    pub original: String,
    pub custom: String,
    pub enabled: bool,
    pub description: Option<String>,
}
```

### `src/manager.rs`

**Purpose**: Detour operations management

**Detour-Specific Operations**:
- Apply detour (bind mount): `sudo mount --bind <custom> <original>`
- Remove detour (unmount): `sudo umount <original>`
- Toggle detour (mount/unmount)
- Check mount status: `mount | grep <path>`
- Backup original file before detour
- Service management integration

**Key Functions**:
```rust
pub fn apply_detour(original: &Path, custom: &Path) -> Result<(), DetourError>
pub fn remove_detour(original: &Path) -> Result<(), DetourError>
pub fn toggle_detour(original: &Path, custom: &Path, enabled: bool) -> Result<(), DetourError>
pub fn check_mount_status(original: &Path) -> bool
```

### `src/injection.rs`

**Purpose**: Include injection logic (Detour-specific feature)

**Detour-Specific Features**:
- Inject content into target files
- Marker comment insertion: `# DETOUR_INJECT_START` / `# DETOUR_INJECT_END`
- Content injection between markers
- Preserve original file structure
- Validation of injection points

### `src/mirror.rs`

**Purpose**: Mirror operations (Detour-specific feature)

**Detour-Specific Features**:
- Mirror directories
- Sync files between locations
- Validate mirror completeness

### `src/validation.rs`

**Purpose**: Detour validation logic

**Detour-Specific Validation**:
- Validate detour paths exist
- Check permissions
- Verify custom files exist
- Check for conflicts
- Validate include markers
- Validate service names

## Detour-Specific View Modes

### View Mode Enum

```rust
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ViewMode {
    DetoursList,      // List all detours
    DetoursAdd,       // Add new detour form
    DetoursEdit,      // Edit existing detour form
    InjectionsList,   // List all injections
    InjectionsAdd,    // Add new injection form
    MirrorsList,      // List all mirrors
    MirrorsAdd,       // Add new mirror form
    MirrorsEdit,      // Edit existing mirror form
    ServicesList,     // List all services
    StatusOverview,   // System status dashboard
    LogsLive,         // Live log viewer
    ConfigEdit,       // Config file editor
}
```

## Detour-Specific Actions

### Detours View Actions

- **List**: Show all detours with status
- **Add**: Open add detour form
- **Edit**: Edit selected detour (key: `e`)
- **Toggle**: Toggle detour active state (key: `Space`)
- **Validate**: Validate all detours
- **Remove**: Delete detour (key: `Delete`, with confirmation)
- **Diff**: Show diff between original and custom (key: `d`)

### Injections View Actions

- **List**: Show all injections
- **Add Include**: Add new injection
- **Remove**: Remove injection
- **Test Injection**: Test injection logic

### Mirrors View Actions

- **List**: Show all mirrors
- **Add**: Add new mirror
- **Edit**: Edit existing mirror
- **Validate**: Validate mirror completeness

## Detour-Specific Forms

### Add Detour Form

**Fields**:
- Original Path (with file browser: `Ctrl+F`)
- Custom Path (with file browser: `Ctrl+F`)
- Options:
  - Create backup (checkbox)
  - Restart services (checkbox)
  - Add to profile (checkbox)

**Special Features**:
- Path completion (Tab)
- File browser integration
- Preview of detour operation
- Validation before submission

### Edit Detour Form

Same as Add Detour Form, but:
- Pre-populated with existing values
- Updates existing detour instead of creating new
- Tracked via `editing_index: Option<usize>`

## Detour-Specific Operations

### Apply Detour Operation

```rust
pub fn apply_detour(original: &Path, custom: &Path) -> Result<(), DetourError> {
    // 1. Validate paths
    if !custom.exists() {
        return Err(DetourError::CustomNotFound);
    }
    
    // 2. Create backup
    if original.exists() {
        let backup = original.with_extension("~");
        std::fs::copy(original, &backup)?;
    }
    
    // 3. Apply bind mount
    std::process::Command::new("sudo")
        .arg("mount")
        .arg("--bind")
        .arg(custom)
        .arg(original)
        .output()?;
    
    Ok(())
}
```

### Toggle Detour Operation

```rust
pub fn toggle_detour(original: &Path, custom: &Path, enabled: bool) -> Result<(), DetourError> {
    if enabled {
        apply_detour(original, custom)
    } else {
        remove_detour(original)
    }
}
```

### Check Mount Status

```rust
pub fn check_mount_status(original: &Path) -> bool {
    let output = std::process::Command::new("mount")
        .output()
        .ok()?;
    
    let mount_info = String::from_utf8_lossy(&output.stdout);
    mount_info.contains(original.to_string_lossy().as_ref())
}
```

## Detour-Specific UI Components

### Detours List View

**Displays**:
- Detour original path
- Detour custom path
- Status (✓ Active / ○ Inactive)
- File size
- Modification time
- Service restart needed indicator

**Features**:
- Toggle active state (Space key)
- Edit detour (e key)
- Delete detour (Delete key)
- Show diff (d key)
- Validate single detour (v key)

### Status Overview View

**Displays**:
- Overall system health
- Detour counts (active/inactive/total)
- Injection counts
- Service counts
- Profile information
- Config file location
- Disk impact

### Logs Live View

**Displays**:
- Real-time log entries
- Color-coded by level (ERROR/WARN/INFO/SUCCESS)
- Timestamps
- Auto-scrolling to latest
- Filtering by level/type

## Detour-Specific Event Handlers

### Detours List Specific Keys

```rust
KeyCode::Char(' ') => {
    // Toggle detour active state
    app.toggle_selected_detour();
}
KeyCode::Char('e') => {
    // Edit selected detour
    app.edit_selected_detour();
}
KeyCode::Char('d') => {
    // Show diff viewer
    app.show_diff_viewer();
}
KeyCode::Char('v') => {
    // Validate selected detour
    app.validate_selected_detour();
}
KeyCode::Delete => {
    // Delete selected detour (with confirmation)
    app.delete_selected_detour();
}
```

## Detour-Specific State

### Detour Data Structure

```rust
pub struct Detour {
    pub original: String,
    pub custom: String,
    pub active: bool,
    pub size: u64,
    pub modified: String,
}

impl Detour {
    pub fn status_text(&self) -> String {
        if self.active {
            "✓ Active".to_string()
        } else {
            "○ Inactive".to_string()
        }
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
}
```

## Integration with Shell Script

### Shell Script Integration

Detour TUI integrates with `lib/detour-core.sh` for actual operations:

```rust
pub fn apply_detour_via_script(original: &Path, custom: &Path) -> Result<(), Error> {
    let output = std::process::Command::new("sudo")
        .arg("bash")
        .arg("/path/to/detour-core.sh")
        .arg("apply")
        .arg(original)
        .arg(custom)
        .output()?;
    
    if output.status.success() {
        Ok(())
    } else {
        Err(Error::ScriptExecutionFailed)
    }
}
```

## Configuration File Format

### Runtime Config (`~/.detour.yaml`)

```yaml
detours:
  - original: /home/pi/homeassistant/configuration.yaml
    custom: /home/pi/_playground/homeassistant/configuration.yaml
    enabled: true
    description: "Home Assistant main config"

includes:
  - target: /home/pi/homeassistant/configuration.yaml
    include: /home/pi/_playground/homeassistant/includes/automations.yaml
    description: "Automation includes"

services:
  - name: homeassistant
    action: restart
    description: "Restart Home Assistant"
```

### TUI Build Config (`config.yaml`)

```yaml
profile: default
views:
  - Detours
  - Injections
  - Mirrors
  - Services
  - Status
  - Logs
  - Config
```

## Extension Points

### Adding New Detour Operations

1. Add operation to `manager.rs`
2. Add action to view's action list
3. Add handler in `events.rs`
4. Add UI feedback (toast/popup)
5. Update state if needed

### Adding New View Modes

1. Add `ViewMode` variant
2. Add view to `views` list in `App::new()`
3. Add content renderer in `ui.rs`
4. Add navigation logic in `events.rs`
5. Add view-specific actions

### Adding New Validation Rules

1. Add validation rule to `validation.rs`
2. Integrate with validation report
3. Add UI indicators for validation results

## Best Practices

1. **Follow Universal Patterns**: Use universal patterns from `_dev/_docs/rust/`
2. **Extend, Don't Replace**: Extend universal patterns for Detour-specific needs
3. **Shell Script Integration**: Use shell script for actual file operations
4. **Error Handling**: Handle mount/unmount errors gracefully
5. **User Feedback**: Show toasts for operations, popups for critical errors
6. **State Synchronization**: Keep TUI state in sync with actual system state

## Reference

- **Universal Patterns**: See `_dev/_docs/rust/` for universal TUI patterns
- **Style Guide**: See `02-style-guide.md` for Detour-specific styling
- **Implementation Patterns**: See `03-implementation-patterns.md` for Detour-specific patterns
- **Formatting Reference**: See `04-formatting-reference.md` for detailed formatting (references universal docs)
