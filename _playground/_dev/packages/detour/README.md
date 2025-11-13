# Detour - File Overlay Management System

A unified system for managing file detours, includes, and services. Allows you to create transparent file overlays that redirect system files to custom versions without modifying the originals.

## Status

**Current:** Rust TUI is now functional! 🎉  
**Shell Script:** Still available in `lib/detour-core.sh` for CLI usage  
**Development:** Active - TUI features being added

## Quick Start

### Using the TUI (Recommended)

```bash
# Run directly from source (development)
./run-tui.sh

# Or build and run
cargo build
./target/debug/detour

# Navigation:
#   Tab - Next panel
#   ↑↓ / jk - Navigate items
#   Enter - Select
#   Space - Toggle
#   q - Quit
```

### Using Shell Script (CLI)

```bash
# Install globally
./install.sh

# Apply detours from config
bin/detour apply

# Check status
bin/detour status

# Remove all detours
bin/detour remove
```

## Documentation

**For AI Agents and Developers:**
- See `docs/README.md` for comprehensive AI Agent-focused documentation
- Structure guide: `docs/01-structure-guide.md`
- Style guide: `docs/02-style-guide.md`
- Implementation patterns: `docs/03-implementation-patterns.md`
- Formatting reference: `docs/04-formatting-reference.md`

**For Users:**
- This README: Usage and quick start
- Architecture: `ARCHITECTURE.md`
- Config structure: `CONFIG-STRUCTURE.md`
- Migration: `docs/MIGRATION.md`

## Directory Structure

```
detour/
├── bin/
│   └── detour              # Executable wrapper
├── lib/
│   └── detour-core.sh      # Current shell implementation
├── src/
│   ├── main.rs             # Future Rust TUI entry point
│   └── lib.rs              # Future Rust library
├── examples/
│   └── detour.conf.example # Example configuration
├── docs/                   # Documentation
├── Cargo.toml              # Rust project configuration
├── install.sh              # Installation script
├── uninstall.sh            # Uninstallation script
└── README.md               # This file
```

## Configuration

The detour system uses **two separate configuration files**:

### 1. Runtime Detours Mapping: `~/.detour.yaml`

This is where you define which files to overlay, include, and which services to manage.

**Example:**
```yaml
detours:
  - original: /home/pi/printer_data/config/printer.cfg
    custom: /home/pi/_playground/klipper/printer.cfg
    description: Custom Klipper configuration

includes:
  - target: /home/pi/printer_data/config/printer.cfg
    include: /home/pi/_playground/klipper/macros.cfg
    description: Custom macro definitions

services:
  - name: klipper
    action: restart
    description: Restart Klipper after config changes
```

### 2. TUI Build Configuration: `config.yaml`

Located in the detour package directory, this controls the TUI's appearance and behavior (similar to chamon's config). You only need to edit this if customizing the TUI itself.

## Features

### Current (Shell Script)

- ✅ File detours using bind mounts
- ✅ Include directives (file injection)
- ✅ Service management
- ✅ Configuration file support
- ✅ Logging and error handling
- ✅ Dry-run mode

### Planned (Rust TUI)

- 🚧 Interactive TUI for managing detours
- 🚧 Visual configuration editor
- 🚧 Real-time status monitoring
- 🚧 Conflict detection
- 🚧 Rollback functionality
- 🚧 Multiple configuration profiles

## Commands

```bash
detour apply              # Apply all detours from config
detour remove             # Remove all active detours
detour status             # Show current detour status
detour init <file>        # Initialize detour for a file
detour validate           # Validate configuration
detour --dry-run apply    # Test without applying
```

## Use Cases

### 1. System Configuration Management
Keep your customizations separate from system files:
```bash
detour /etc/nginx/nginx.conf = /home/pi/_playground/nginx/nginx.conf
```

### 2. Development Environment
Test configurations without modifying originals:
```bash
detour /home/pi/app/config.yaml = /home/pi/_playground/app/config-dev.yaml
```

### 3. 3D Printer Setup
Manage Klipper/Moonraker configs from a version-controlled directory:
```bash
detour /home/pi/printer_data/config/printer.cfg = /home/pi/_playground/klipper/printer.cfg
```

## Migration to Rust

The Rust implementation will:
1. Maintain compatibility with current config format
2. Add TUI for interactive management
3. Improve performance and safety
4. Add advanced features (profiles, rollback, etc.)

### Development Roadmap

- [x] Shell script implementation
- [x] Project structure setup
- [x] Rust config parser (YAML)
- [x] Rust core logic
- [x] TUI implementation (horizontal 3-column layout)
- [x] Navigation and keybindings
- [x] Diff viewer
- [x] Popup system
- [ ] Advanced features (profiles, rollback)
- [ ] Testing and validation
- [ ] Migration guide

## Installation

```bash
# From package directory
./install.sh

# Or manually
chmod +x bin/detour
sudo ln -sf $(pwd)/bin/detour /usr/local/bin/detour
```

## See Also

- [ARCHITECTURE.md](ARCHITECTURE.md) - Technical architecture
- [examples/detour.conf.example](examples/detour.conf.example) - Configuration examples
- [chamon](../chamon/) - Sister project for change monitoring

---

**Status:** Active Development  
**Current Version:** 0.1.0 (Shell)  
**Target Version:** 1.0.0 (Rust TUI)

