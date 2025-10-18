# ChaMon Architecture

## Overview

ChaMon (Change Monitor) has been restructured to support both TUI and CLI usage with a clean, modular architecture.

## Directory Structure

```
chamon/
├── src/                    # Rust TUI application
│   ├── main.rs            # Entry point
│   ├── lib.rs             # Library exports
│   ├── app.rs             # Application state & logic
│   ├── config.rs          # Configuration structures
│   ├── events.rs          # Event handling (keyboard & mouse)
│   └── ui.rs              # UI rendering
│
├── lib/                    # Shared bash libraries
│   ├── common.sh          # Common utilities & JSON functions
│   ├── monitor-core.sh    # System monitoring core functions
│   └── tracker-core.sh    # File tracking core functions
│
├── system-monitor          # Monitor wrapper (CLI/TUI friendly)
├── system-tracker          # Tracker wrapper (CLI/TUI friendly)
├── config.yaml            # TUI configuration
└── Cargo.toml             # Rust dependencies

```

## Architecture Principles

### 1. **Separation of Concerns**
- **TUI Layer** (Rust): User interface, event handling, rendering
- **Core Logic** (Bash libraries): File monitoring, tracking, checksums
- **Wrappers** (Bash scripts): Thin CLI interfaces with JSON output

### 2. **Multiple Output Modes**
Each script supports three output modes:
- **Human**: Colored, formatted output for CLI use
- **JSON**: Structured data for TUI consumption
- **Quiet**: Silent operation (errors only)

### 3. **Modular Libraries**
Core functionality is extracted into reusable bash libraries:

#### `lib/common.sh`
- Configuration management
- Logging functions (info, warning, error, success)
- JSON output utilities
- Common helper functions

#### `lib/monitor-core.sh`
- `get_changes()` - Detect file changes
- `create_baseline()` - Create checksum baseline
- `get_status()` - Get monitoring status

#### `lib/tracker-core.sh`
- `track_file()` - Start tracking a file
- `untrack_file()` - Stop tracking a file
- `list_tracked()` - List tracked files
- `check_tracked_status()` - Check status of tracked files


---

## Usage Patterns

### CLI Usage (Human Output)
```bash
# System monitoring
./system-monitor baseline
./system-monitor check
./system-monitor status

# File tracking
./system-tracker add /etc/config.conf
./system-tracker list
./system-tracker status
```

### TUI Integration (JSON Output)
```bash
# Get changes as JSON
./system-monitor --json check

# Example output:
# [
#   {"type":"MODIFIED","path":"/etc/config","timestamp":"20241017 14:30:00","status":"untracked"},
#   {"type":"NEW","path":"/etc/newfile","timestamp":"20241017 14:31:00","status":"untracked"}
# ]

# Track file with JSON response
./system-tracker --json add /etc/config.conf

# Example output:
# {"status":"success","path":"/etc/config.conf"}
```

### Programmatic Usage (Library Import)
```bash
#!/bin/bash
source lib/common.sh
source lib/monitor-core.sh

# Set output mode
OUTPUT_MODE="json"

# Use core functions
create_baseline
get_changes
```

## Data Flow

### TUI → Scripts → Core Libraries

```
┌─────────────────────────────────────────────────────────┐
│                     Rust TUI (src/)                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐  │
│  │ main.rs  │→ │ app.rs   │→ │events.rs │→ │  ui.rs  │  │
│  └──────────┘  └─────┬────┘  └──────────┘  └─────────┘  │
└──────────────────────┼──────────────────────────────────┘
                       │ calls with --json
                       ↓
┌─────────────────────────────────────────────────────────┐
│              Bash Wrappers (CLI Entry)                  │
│  ┌──────────────────┐        ┌──────────────────┐       │
│  │ system-monitor   │        │ system-tracker   │       │
│  │ --json check     │        │ --json add <file>│       │
│  └────────┬─────────┘        └────────┬─────────┘       │
└───────────┼───────────────────────────┼─────────────────┘
            │                           │
            │ sources                   │ sources
            ↓                           ↓
┌─────────────────────────────────────────────────────────┐
│           Core Libraries (lib/*.sh)                     │
│  ┌──────────────┐                                       │
│  │  common.sh   │←───────────────┐                      │
│  │ (utilities)  │                │                      │
│  └──────────────┘                │                      │
│                                  │                      │
│  ┌──────────────────┐            │  ┌─────────────────┐ │
│  │ monitor-core.sh  │────────────┘  │ tracker-core.sh │ │
│  │ get_changes()    │               │ track_file()    │ │
│  │ create_baseline()│               │ list_tracked()  │ │
│  └──────────────────┘               └─────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Benefits of This Architecture

### ✅ **Maintainability**
- Clear separation between UI and logic
- Modular functions easy to test and modify
- DRY principle - no code duplication

### ✅ **Flexibility**
- Can use CLI or TUI independently
- Easy to add new output formats
- Core libraries can be used in other scripts

### ✅ **Testability**
- Core functions can be tested independently
- JSON output makes TUI testing easier
- Dry-run mode for safe testing

### ✅ **Performance**
- Thin wrappers minimize overhead
- TUI can efficiently parse JSON
- Caching strategies easy to implement

### ✅ **Extensibility**
- New features added to core libraries
- TUI automatically gets new features
- CLI remains functional during TUI development

## Migration Guide

### Old Usage → New Usage

**Old (monolithic scripts):**
```bash
./system-monitor.sh check
./system-tracker.sh add /etc/config
```

**New (modular architecture):**
```bash
# CLI usage (same interface)
./system-monitor check
./system-tracker add /etc/config

# TUI usage (JSON mode)
./system-monitor --json check
./system-tracker --json add /etc/config

# Library usage (import functions)
source lib/monitor-core.sh
get_changes
```

## Future Enhancements

1. **Caching Layer**: Cache JSON responses for faster TUI updates
2. **WebSocket API**: Real-time updates from scripts to TUI
3. **Database Backend**: SQLite for better change tracking
4. **Plugin System**: Add custom monitors without modifying core
5. **Config Files**: Centralized configuration for all components

---

**Last Updated**: 2024-10-17
**Version**: 2.0 (Modular Architecture)

