# YAML Configuration Migration

**Date:** October 29, 2025  
**Changes:** Configuration format migrated from custom `.conf` to standard YAML

## What Changed?

The detour system now uses **YAML** format for configuration, following the same pattern as `chamon`.

### Two Configuration Files

1. **`~/.detour.yaml`** - Runtime detours mapping (user data)
   - Where you define which files to overlay
   - Located in home directory (user-specific)
   - Not tracked in git

2. **`config.yaml`** - TUI build configuration (application settings)
   - Controls TUI appearance and behavior
   - Located in detour package directory
   - Tracked in git

## Migration Guide

### Old Format (`.detour.conf`)

```bash
# File detours
detour /path/to/original = /path/to/custom

# Include directives
include /path/to/target : /path/to/include

# Service management
service service_name : restart
```

### New Format (`~/.detour.yaml`)

```yaml
# File detours
detours:
  - original: /path/to/original
    custom: /path/to/custom
    description: Optional description

# Include directives
includes:
  - target: /path/to/target
    include: /path/to/include
    description: Optional description

# Service management
services:
  - name: service_name
    action: restart
    description: Optional description
```

## Why YAML?

1. **Standardization** - YAML is a well-known format with excellent tooling
2. **Consistency** - Matches `chamon`'s configuration style
3. **Flexibility** - Easy to add new fields (like `description`)
4. **Validation** - Schema validation, IDE support
5. **Readability** - Clear structure, no parsing ambiguity

## File Locations

### Runtime Detours Mapping

Searched in this order:
1. `~/.detour.yaml` (primary - user-specific)
2. `/etc/detour.yaml` (fallback - system-wide)

### TUI Build Configuration

Fixed location:
- `/home/pi/_playground/_dev/packages/detour/config.yaml`

## What to Do

### If You Have an Old Config

Convert your `~/.detour.conf` to `~/.detour.yaml`:

```bash
# Create new YAML config
nano ~/.detour.yaml

# Copy example structure
cat > ~/.detour.yaml << 'EOF'
detours: []
includes: []
services: []
EOF

# Add your detours in YAML format
```

### If Starting Fresh

A template `~/.detour.yaml` has been created with:
- Example structure
- Commented examples
- Full documentation

## Features Added

### In `~/.detour.yaml`

- **Description field** - Document what each detour does
- **YAML arrays** - Clear list structure
- **Comments** - Explain configuration inline

### In `config.yaml`

- **UI settings** - Title bar, colors, layout
- **Keybindings** - Customize all keyboard shortcuts
- **Views configuration** - Which views to show
- **Actions** - Commands and their keys
- **Logging** - Log levels and limits
- **Diff settings** - Diff viewer behavior

## Backward Compatibility

The old `.conf` format is **no longer supported**.

If you have existing `.detour.conf` files, they will be ignored. You must migrate to the new YAML format.

## Documentation

See:
- **`CONFIG-STRUCTURE.md`** - Complete configuration guide
- **`~/.detour.yaml`** - Runtime mapping (self-documenting)
- **`config.yaml`** - TUI settings (heavily commented)
- **`README.md`** - Updated with YAML examples

## Quick Reference

| Task | Command |
|------|---------|
| Edit runtime detours | `nano ~/.detour.yaml` |
| Edit TUI settings | `nano config.yaml` |
| View config structure | `cat CONFIG-STRUCTURE.md` |
| Test configuration | `cargo run` |

---

**This migration provides:**
- ✅ Better structure and clarity
- ✅ IDE support (syntax highlighting, validation)
- ✅ Consistency with `chamon`
- ✅ Room for future enhancements
- ✅ Industry-standard format

