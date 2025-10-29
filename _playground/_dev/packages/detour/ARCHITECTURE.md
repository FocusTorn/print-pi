# Detour Architecture

## Overview

Detour is a file overlay/detour management system that allows transparent redirection of file reads to custom versions without modifying the originals.

## Current Implementation (Shell Script)

### Core Components

**Location:** `lib/detour-core.sh`

**Key Functions:**
- `parse_config()` - Parse detour configuration file
- `apply_detour()` - Apply bind mount for file redirection
- `remove_detour()` - Remove bind mount
- `apply_include()` - Inject content into target file
- `manage_service()` - Control systemd services

### Configuration Format

```bash
# Detour directive
detour <original_path> = <custom_path>

# Include directive  
include <target_file> : <include_file>

# Service directive
service <service_name> : <action>
```

### How It Works

1. **File Detour (Bind Mount)**
   - Creates backup of original file
   - Bind mounts custom file over original location
   - Reads are transparently redirected

2. **Include Directive**
   - Inserts marker comments in target file
   - Injects content from include file
   - Preserves original structure

3. **Service Management**
   - Wraps systemd service control
   - Coordinates with file changes

## Future Implementation (Rust TUI)

### Architecture Goals

1. **Performance** - Faster config parsing and validation
2. **Safety** - Type-safe operations, better error handling
3. **Usability** - Interactive TUI for management
4. **Features** - Profiles, rollback, conflict detection

### Planned Modules

```
src/
├── main.rs              # TUI entry point
├── lib.rs               # Public API
├── config.rs            # Configuration parsing
├── detour.rs            # Detour operations
├── include.rs           # Include operations
├── service.rs           # Service management
├── ui/
│   ├── app.rs           # TUI application state
│   ├── events.rs        # Event handling
│   └── widgets/         # Custom widgets
└── utils/
    ├── filesystem.rs    # File operations
    ├── mount.rs         # Bind mount operations
    └── validation.rs    # Config validation
```

### Data Flow

```
Config File → Parser → Validator → Executor → System
                                      ↓
                                   Logger
```

### TUI Design

```
┌─ Detour Manager ────────────────────────────────────┐
│                                                      │
│ Status: 3 active detours                            │
│                                                      │
│ ┌─ Active Detours ─────────────────────────────┐   │
│ │ ✓ /etc/nginx/nginx.conf                      │   │
│ │ ✓ /home/pi/printer_data/config/printer.cfg   │   │
│ │ ✓ /home/pi/klipper/klippy.py                 │   │
│ └───────────────────────────────────────────────┘   │
│                                                      │
│ [A]pply  [R]emove  [E]dit  [S]tatus  [Q]uit        │
└──────────────────────────────────────────────────────┘
```

## Migration Path

### Phase 1: Structure Setup ✅
- [x] Create directory structure
- [x] Move shell scripts to lib/
- [x] Create Cargo.toml
- [x] Add placeholder Rust files

### Phase 2: Rust Core
- [ ] Implement config parser
- [ ] Port detour operations
- [ ] Add validation logic
- [ ] Write unit tests

### Phase 3: CLI
- [ ] Command-line interface
- [ ] Match shell script functionality
- [ ] Add new features (profiles, etc.)

### Phase 4: TUI
- [ ] Design TUI layout
- [ ] Implement interactive features
- [ ] Add status monitoring
- [ ] Polish and test

## Compatibility

### Config File
The Rust implementation will use the **same config format**, ensuring:
- Existing configs work without modification
- Users can switch between implementations
- Gradual migration path

### Commands
All shell script commands will be supported:
```bash
detour apply
detour remove
detour status
detour init <file>
```

Plus new commands:
```bash
detour tui              # Launch TUI
detour profile list     # Manage profiles
detour rollback         # Undo changes
detour validate         # Check config
```

## Design Principles

1. **Non-Destructive** - Never modify original files
2. **Transparent** - Applications see custom files seamlessly
3. **Reversible** - Easy to remove all detours
4. **Traceable** - Log all operations
5. **Safe** - Validate before applying

## Dependencies

### Current (Shell)
- bash
- mount/umount
- systemctl (for service management)
- Standard coreutils

### Future (Rust)
- ratatui (TUI)
- crossterm (Terminal handling)
- serde (Serialization)
- clap (CLI parsing)

## Testing Strategy

### Unit Tests
- Config parser
- Path validation
- Mount operations

### Integration Tests
- Full detour lifecycle
- Service coordination
- Error handling

### Manual Tests
- Real system configurations
- Permission handling
- Reboot persistence

## See Also

- [README.md](README.md) - User documentation
- [examples/](examples/) - Configuration examples
- [chamon](../chamon/) - Sister project with similar architecture


