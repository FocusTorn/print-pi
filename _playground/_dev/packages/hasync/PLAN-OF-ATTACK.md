# HA Dashboard Sync (hasync) - Plan of Attack

## Overview

Create a Rust TUI application for synchronizing Home Assistant dashboards between YAML source files and JSON storage files. This tool will provide bidirectional sync capabilities with a user-friendly interface.

## Quick Start (Quick Win Implementation)

**Status**: ✅ Core functionality working! The app can now:
- Load dashboard configurations from `~/.config/hasync/config.yaml`
- Display dashboard list with sync status
- Show detailed sync status (file paths, modification times)
- Sync YAML→JSON with backup creation
- Show confirmation dialogs and success/error toasts

**Setup**:
1. Copy `CONFIG-EXAMPLE.yaml` to `~/.config/hasync/config.yaml`
2. Customize the dashboard paths in the config file
3. Run: `cargo run --bin hasync`

**Usage**:
- Navigate between Views, Actions, and Content columns with Tab/Arrow keys
- Select a dashboard in the Content column
- Select "Sync YAML→JSON" in the Actions column
- Press Enter to confirm sync
- View sync status in the Sync Status view

## Package Name

**hasync** - Home Assistant Dashboard Sync

## Goals

1. **Bidirectional Sync**: YAML ↔ JSON synchronization
2. **TUI Interface**: Interactive terminal UI for managing sync operations
3. **Automatic Detection**: Detect which file is newer
4. **Safe Operations**: Backup before sync, confirmation for destructive operations
5. **Visual Feedback**: Progress indicators, status messages, error handling

## Foundation

### Universal Patterns

**All implementation will follow universal Rust TUI patterns:**
- **Color Palette**: `_dev/_docs/rust/01-color-palette.md`
- **Styling Helpers**: `_dev/_docs/rust/02-styling-helpers.md`
- **Layout Patterns**: `_dev/_docs/rust/03-layout-patterns.md`
- **Component Patterns**: `_dev/_docs/rust/04-component-patterns.md`
- **Event Handling**: `_dev/_docs/rust/05-event-handling.md`
- **State Management**: `_dev/_docs/rust/06-state-management.md`

### Reference Implementation

**Detour package** (`_dev/packages/detour/`) serves as the reference implementation:
- Study Detour's structure and patterns
- Reference Detour's component usage
- Follow Detour's event handling patterns
- Use Detour's state management approach

## Package Structure

### Directory Layout

```
hasync/
├── src/                    # Rust source code
│   ├── main.rs            # Entry point (TUI launcher)
│   ├── lib.rs             # Library root (module declarations)
│   ├── app.rs             # Application state management
│   ├── events.rs          # Event handling
│   ├── ui.rs              # Main UI rendering
│   ├── popup.rs           # Popup/dialog rendering
│   ├── sync.rs            # Sync operations (YAML ↔ JSON)
│   ├── config.rs          # Configuration management
│   ├── validation.rs      # Validation logic
│   └── components/        # Reusable UI components (use universal patterns)
│       ├── mod.rs
│       ├── list_panel.rs  # Reuse or reference universal list_panel
│       └── form_panel.rs  # Reuse or reference universal form_panel
├── docs/                  # Documentation
│   ├── README.md         # Package documentation
│   └── PLAN-OF-ATTACK.md # This file
├── Cargo.toml            # Rust project configuration
├── install.sh            # Installation script
├── uninstall.sh          # Uninstallation script
└── README.md             # User-facing documentation
```

## Phase 1: Project Setup

### 1.1 Initialize Rust Project

- [ ] Create `Cargo.toml` with dependencies:
  - `ratatui = "0.26"` - TUI framework
  - `crossterm = "0.27"` - Terminal handling
  - `serde = { version = "1.0", features = ["derive"] }` - Serialization
  - `serde_json = "1.0"` - JSON handling
  - `serde_yaml = "0.9"` - YAML handling
  - `clap = { version = "4.5", features = ["derive"] }` - CLI
  - `anyhow = "1.0"` - Error handling
  - `chrono = "0.4"` - Time handling

- [ ] Create basic module structure (`src/lib.rs`, `src/main.rs`)
- [ ] Create placeholder modules for all planned modules

### 1.2 Project Configuration

- [ ] Set up `Cargo.toml` with proper metadata
- [ ] Configure binary and library targets
- [ ] Add development dependencies if needed

## Phase 2: Core Functionality

### 2.1 Sync Operations (`src/sync.rs`)

**Responsibilities**:
- Convert YAML to JSON (Home Assistant dashboard format)
- Convert JSON to YAML (extract dashboard config)
- Detect which file is newer (modification time comparison)
- Validate file formats before sync
- Create backups before sync operations

**Key Functions**:
```rust
pub fn yaml_to_json(yaml_path: &Path) -> Result<Value, SyncError>
pub fn json_to_yaml(json_path: &Path) -> Result<Value, SyncError>
pub fn detect_newer_file(yaml_path: &Path, json_path: &Path) -> FileStatus
pub fn create_backup(file_path: &Path) -> Result<PathBuf, SyncError>
pub fn sync_yaml_to_json(yaml_path: &Path, json_path: &Path) -> Result<(), SyncError>
pub fn sync_json_to_yaml(json_path: &Path, yaml_path: &Path) -> Result<(), SyncError>
```

**File Status Enum**:
```rust
pub enum FileStatus {
    YamlNewer,
    JsonNewer,
    Synced,
    Error(String),
}
```

### 2.2 Configuration Management (`src/config.rs`)

**Responsibilities**:
- Load dashboard configuration (YAML and JSON paths)
- Validate configuration
- Default configuration handling

**Configuration Structure**:
```rust
pub struct DashboardConfig {
    pub name: String,
    pub yaml_source: PathBuf,
    pub json_storage: PathBuf,
    pub dashboard_key: String,  // e.g., "printerific"
    pub dashboard_title: String,
    pub dashboard_path: String,
}

pub struct AppConfig {
    pub dashboards: Vec<DashboardConfig>,
    pub default_dashboard: Option<String>,
}
```

### 2.3 Validation (`src/validation.rs`)

**Responsibilities**:
- Validate YAML format
- Validate JSON format (Home Assistant dashboard structure)
- Validate file paths exist
- Validate dashboard structure (views, cards, etc.)

**Key Functions**:
```rust
pub fn validate_yaml(path: &Path) -> Result<(), ValidationError>
pub fn validate_json(path: &Path) -> Result<(), ValidationError>
pub fn validate_dashboard_structure(json: &Value) -> Result<(), ValidationError>
```

## Phase 3: TUI Foundation

### 3.1 Application State (`src/app.rs`)

**State Structure**:
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
    
    // hasync-specific data
    pub dashboards: Vec<DashboardInfo>,
    pub selected_dashboard: Option<usize>,
    pub sync_status: SyncStatus,
    pub config: AppConfig,
    
    // UI state (universal pattern)
    pub toasts: Vec<Toast>,
    pub should_quit: bool,
    pub logs: Vec<LogEntry>,
}
```

**View Modes**:
```rust
pub enum ViewMode {
    DashboardList,    // List all dashboards
    SyncStatus,       // Show sync status
    SyncHistory,      // Show sync history
}
```

**Sync Status**:
```rust
pub struct SyncStatus {
    pub yaml_path: PathBuf,
    pub json_path: PathBuf,
    pub yaml_mtime: Option<SystemTime>,
    pub json_mtime: Option<SystemTime>,
    pub status: FileStatus,
}
```

### 3.2 UI Rendering (`src/ui.rs`)

**Views to Implement**:
1. **Dashboard List View**: List all configured dashboards
2. **Sync Status View**: Show sync status for selected dashboard
3. **Sync Operations View**: Perform sync operations

**Layout**:
- Follow universal three-column layout pattern
- Column 1: Views (Dashboard List, Sync Status, Sync History)
- Column 2: Actions (List, Sync YAML→JSON, Sync JSON→YAML, Check Status, Show Diff)
- Column 3: Content (Dashboard list, sync status, diff viewer)

### 3.3 Event Handling (`src/events.rs`)

**Key Bindings**:
- Global: `q`/`Esc` to quit, `Tab`/`h`/`l` for column navigation
- Dashboard List: `Enter` to select, `s` to sync, `d` to show diff
- Sync Operations: `y` for YAML→JSON, `j` for JSON→YAML, `Enter` to confirm

**Event Priority**:
1. Popups/Modals
2. Forms (if any)
3. Global navigation
4. View-specific handlers

## Phase 4: Sync Operations UI

### 4.1 Sync Status Display

**Show**:
- YAML file path and modification time
- JSON file path and modification time
- Which file is newer
- Sync recommendation (YAML→JSON or JSON→YAML)
- Last sync time (if tracked)

### 4.2 Sync Operation Flow

**YAML → JSON**:
1. Validate YAML file exists and is valid
2. Parse YAML to dashboard structure
3. Convert to Home Assistant JSON format
4. Create backup of JSON file
5. Write JSON file
6. Show success toast or error popup

**JSON → YAML**:
1. Validate JSON file exists and is valid
2. Parse JSON to dashboard structure
3. Extract dashboard config from JSON
4. Convert to YAML format
5. Create backup of YAML file
6. Write YAML file
7. Show success toast or error popup

### 4.3 Confirmation Dialogs

**Before Sync**:
- Show confirmation dialog with:
  - Source and destination paths
  - Backup location
  - What will happen (overwrite warning)
- Default to "No" for safety

### 4.4 Diff Viewer

**Features**:
- Show differences between YAML and JSON (structural)
- Side-by-side comparison
- Highlight differences
- Scrollable content

## Phase 5: Advanced Features

### 5.1 Multiple Dashboard Support

- Support multiple dashboards
- Dashboard selection in Column 1
- Per-dashboard sync status
- Batch operations (sync all dashboards)

### 5.2 Sync History

- Track sync operations
- Show sync history with timestamps
- Show what was synced (YAML→JSON or JSON→YAML)
- Show file sizes and modification times

### 5.3 Configuration Management

- Add/remove dashboards via TUI
- Edit dashboard configuration
- Set default dashboard
- Validate all dashboard configurations

### 5.4 File Watching (Future)

- Watch YAML files for changes
- Auto-detect when YAML is modified
- Prompt for sync when changes detected

## Phase 6: Installation & Distribution

### 6.1 Installation Script

- Create `install.sh`:
  - Build Rust binary
  - Install binary to `~/.local/bin/hasync`
  - Create symlink
  - Install shell completion (if applicable)

### 6.2 Uninstallation Script

- Create `uninstall.sh`:
  - Remove binary
  - Remove symlink
  - Clean up configuration (optional)

### 6.3 Documentation

- Create `README.md` with usage instructions
- Create `docs/README.md` for developers
- Document configuration format
- Provide examples

## Implementation Order

### Phase 1: Foundation (Week 1)
1. ✅ Project setup (`Cargo.toml`, basic structure)
2. ✅ **QUICK WIN: Core sync operations** (`sync.rs`)
   - ✅ `detect_newer_file()` - File modification time comparison
   - ✅ `create_backup()` - Backup creation with timestamp
   - ✅ `yaml_to_json()` - YAML to Home Assistant JSON conversion
   - ✅ `sync_yaml_to_json()` - Full sync workflow (YAML→JSON)
   - ⏳ `json_to_yaml()` - JSON to YAML conversion (TODO)
   - ⏳ `sync_json_to_yaml()` - Full sync workflow (JSON→YAML) (TODO)
3. ✅ **QUICK WIN: Configuration management** (`config.rs`)
   - ✅ `load()` - Load from `~/.config/hasync/config.yaml`
   - ✅ `save()` - Save configuration
   - ✅ `get_config_path()` - Get config file path
   - ✅ Default configuration handling
4. ⏳ Validation (`validation.rs`) - TODO

### Phase 2: TUI Foundation (Week 1-2)
1. ✅ Application state (`app.rs`)
   - ✅ Navigation state
   - ✅ Modal management
   - ✅ **QUICK WIN: Dashboard loading and sync status calculation**
   - ✅ **QUICK WIN: Sync operation methods** (`sync_yaml_to_json_selected()`, `update_dashboard_status()`)
2. ✅ Basic UI rendering (`ui.rs`)
   - ✅ Three-column layout
   - ✅ **QUICK WIN: Dashboard list view with sync status**
   - ✅ **QUICK WIN: Sync status view with file details**
   - ✅ Toast notifications
3. ✅ Event handling (`events.rs`)
   - ✅ Navigation
   - ✅ **QUICK WIN: Sync action handler** (YAML→JSON)
   - ✅ **QUICK WIN: Popup confirmation dialog**
   - ✅ **QUICK WIN: Toast notifications**
4. ✅ Popup system (`popup.rs`)

### Phase 3: Sync UI (Week 2) - QUICK WIN COMPLETE
1. ✅ **QUICK WIN: Dashboard list view** - Shows dashboards with sync status, modification times
2. ✅ **QUICK WIN: Sync status view** - Shows detailed file status, paths, timestamps
3. ✅ **QUICK WIN: Sync operation dialogs** - Confirmation dialog before sync
4. ✅ **QUICK WIN: Success/error feedback** - Toast notifications for sync results
5. ⏳ JSON→YAML sync (TODO)
6. ⏳ Diff viewer (TODO)
7. ⏳ Sync history (TODO)

### Phase 4: Polish (Week 2-3)
1. ⏳ Diff viewer
2. ⏳ Sync history
3. ⏳ Configuration management UI
4. ⏳ Error handling improvements
5. ⏳ Validation UI

### Phase 5: Distribution (Week 3)
1. ⏳ Installation script
2. ⏳ Uninstallation script
3. ⏳ Documentation
4. ⏳ Testing

## Technical Decisions

### YAML to JSON Conversion

**Home Assistant Dashboard JSON Structure**:
```json
{
  "version": 1,
  "key": "dashboard_key",
  "data": {
    "config": {
      "views": [...]
    },
    "title": "Dashboard Title",
    "url_path": "dashboard-path"
  }
}
```

**YAML Structure** (simplified):
```yaml
views:
  - title: Dashboard Title
    path: dashboard-path
    # ... dashboard config
```

**Conversion Logic**:
1. Parse YAML to get views structure
2. Wrap in Home Assistant JSON format
3. Add metadata (key, title, url_path)

### JSON to YAML Conversion

**Extraction Logic**:
1. Parse JSON to get dashboard structure
2. Extract `data.config` (contains views)
3. Convert to YAML format
4. Preserve structure and formatting

### Backup Strategy

**Backup Naming**:
- Format: `{original_filename}.backup.{timestamp}`
- Location: Same directory as original file
- Cleanup: Keep last N backups (configurable, default 3)

### Error Handling

**Error Types**:
```rust
pub enum SyncError {
    FileNotFound(PathBuf),
    InvalidYaml(String),
    InvalidJson(String),
    BackupFailed(String),
    WriteFailed(String),
    PermissionDenied,
    ValidationFailed(String),
}
```

**Error Display**:
- Critical errors: Error popup (blocks interaction)
- Non-critical errors: Error toast (auto-dismiss)
- Validation errors: Validation report panel

## Dependencies

### Required Dependencies

```toml
[dependencies]
ratatui = "0.26"
crossterm = "0.27"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
serde_yaml = "0.9"
clap = { version = "4.5", features = ["derive"] }
anyhow = "1.0"
chrono = "0.4"
thiserror = "1.0"
```

### Optional Dependencies (Future)

```toml
notify = "6.1"  # File watching
```

## Testing Strategy

### Unit Tests

- Test YAML to JSON conversion
- Test JSON to YAML conversion
- Test file status detection
- Test validation logic
- Test backup creation

### Integration Tests

- Test full sync workflows
- Test error scenarios
- Test file operations
- Test configuration loading

### Manual Testing

- Test TUI interactions
- Test sync operations
- Test error handling
- Test with actual Home Assistant dashboards

## Success Criteria

### Functional Requirements

- [ ] Bidirectional sync (YAML ↔ JSON) works correctly
- [ ] Automatic detection of newer file
- [ ] Backup creation before sync
- [ ] Validation before sync operations
- [ ] Error handling and user feedback
- [ ] TUI interface is intuitive and responsive

### Non-Functional Requirements

- [ ] Follows universal Rust TUI patterns
- [ ] Consistent with Detour package style
- [ ] Well-documented code
- [ ] Error messages are user-friendly
- [ ] Performance is acceptable (< 1s for sync operations)

## Risks & Mitigations

### Risk 1: YAML/JSON Conversion Issues

**Risk**: Complex dashboard structures may not convert correctly
**Mitigation**: 
- Comprehensive validation
- Test with real Home Assistant dashboards
- Provide diff viewer to verify changes
- Always create backups

### Risk 2: Data Loss

**Risk**: Sync operation could overwrite important data
**Mitigation**:
- Always create backups
- Confirmation dialogs for sync operations
- Show diff before sync (optional)
- Default to "No" for confirmations

### Risk 3: Permission Issues

**Risk**: May not have permission to write JSON file
**Mitigation**:
- Check permissions before operations
- Clear error messages
- Suggest solutions (sudo, file permissions)

## Next Steps

1. **Review Universal Patterns**: Study `_dev/_docs/rust/` documentation
2. **Study Detour Implementation**: Review Detour package as reference
3. **Create Project Structure**: Set up `Cargo.toml` and basic modules
4. **Implement Core Sync**: Start with `sync.rs` functionality
5. **Build TUI Foundation**: Implement state management and basic UI
6. **Add Sync UI**: Implement sync operation interfaces
7. **Polish & Test**: Add features, improve error handling, test thoroughly

## Reference

- **Universal Patterns**: `_dev/_docs/rust/`
- **Detour Reference**: `_dev/packages/detour/`
- **Home Assistant Docs**: Home Assistant dashboard configuration
- **Existing Script**: `_scripts/sync-homeassistant-dashboard.sh` (bash version)

## Notes

- This is a new package, so start fresh with universal patterns
- Don't port the bash script directly - rewrite using Rust TUI patterns
- Focus on user experience and safety (backups, confirmations)
- Maintain consistency with other TUI packages (Detour, etc.)

