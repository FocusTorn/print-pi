# Detour Configuration Structure

The detour system uses **two separate YAML configuration files** for different purposes:

## 1. Runtime Detours Mapping: `~/.detour.yaml`

**Purpose:** Defines which files to overlay, which configs to extend, and which services to manage

**Location:** `~/.detour.yaml` (user-specific) or `/etc/detour.yaml` (system-wide)

**Format:** YAML

**This is the file you edit** when adding/removing detours.

### Structure

```yaml
# File overlays (bind mounts)
detours:
  - original: /path/to/original/file
    custom: /path/to/custom/file
    description: Optional description of this detour

# Configuration file extensions
includes:
  - target: /path/to/target/file
    include: /path/to/include/file
    description: Optional description

# Service management
services:
  - name: service-name
    action: start|stop|restart|reload
    description: Optional description
```

### Example

```yaml
detours:
  # Override Home Assistant configuration
  - original: /home/pi/homeassistant/configuration.yaml
    custom: /home/pi/_playground/homeassistant/configuration.yaml
    description: Custom HA config with personalized automations
  
  # Override Klipper printer config
  - original: /home/pi/printer_data/config/printer.cfg
    custom: /home/pi/_playground/klipper/printer.cfg
    description: Custom printer configuration

includes:
  # Extend boot configuration
  - target: /boot/firmware/config.txt
    include: /home/pi/_playground/boot/boot-mods.txt
    description: Additional boot parameters
  
  # Add custom Klipper macros
  - target: /home/pi/printer_data/config/printer.cfg
    include: /home/pi/_playground/klipper/macros.cfg
    description: Custom G-code macros

services:
  # Restart services after configuration changes
  - name: homeassistant
    action: restart
    description: Restart HA to pick up new configuration
  
  - name: klipper
    action: restart
    description: Restart Klipper after printer.cfg changes
```

### How Detours Work

1. **Original file remains untouched** - The framework/system file is never modified
2. **Custom file contains your changes** - Keep your customizations in `_playground`
3. **Bind mount creates transparent overlay** - Reading the original path returns custom content
4. **Updates are safe** - When the original is updated by package manager, your custom version stays separate
5. **Easy rollback** - Remove the detour to instantly revert to original

---

## 2. TUI Build Configuration: `config.yaml`

**Purpose:** Controls the TUI application's appearance, keybindings, and behavior

**Location:** `/home/pi/_playground/_dev/packages/detour/config.yaml` (in package directory)

**Format:** YAML (similar to chamon's config.yaml)

**You only need to edit this** if you want to customize the TUI itself.

### Structure

```yaml
# Runtime settings
runtime:
  detours_config: "~/.detour.yaml"  # Path to detours mapping
  auto_reload: true                  # Auto-reload config on changes
  confirm_destructive: true          # Prompt before destructive actions

# UI appearance
ui:
  title_bar:
    display: "Detour - File Overlay Manager"
  
  layout:
    views_column_width: 20
    actions_column_width: 25
    content_column_min: 40
  
  theme:
    selected: "Cyan"
    active: "Green"
    # ... more theme settings

# Views (left column)
views:
  - name: "Detours"
    key: "1"
    description: "View and manage file detours"
  # ... more views

# Actions (middle column)
actions:
  global:
    - name: "[A]pply All"
      key: "a"
      command: "apply_all"
      description: "Apply all detours"
  # ... more actions

# Keybindings
keybindings:
  navigation:
    quit: ["q", "Esc"]
    column_left: "h"
    column_right: "l"
    # ... more keybindings

# Logging
logging:
  max_entries: 500
  level: "info"

# Diff viewer
diff:
  mode: "unified"
  context_lines: 3
```

### What Each Section Controls

- **`runtime`** - Paths to config files, reload behavior
- **`ui`** - Title bar, column widths, color theme
- **`views`** - Left column entries (Detours, Includes, Services, etc.)
- **`actions`** - Middle column commands and their keybindings
- **`keybindings`** - Global keyboard shortcuts
- **`logging`** - Log display settings
- **`diff`** - Diff viewer configuration

---

## Comparison with Chamon

Both `detour` and `chamon` follow the same configuration philosophy:

| File | Chamon | Detour |
|------|--------|--------|
| **Runtime data** | Git-based file tracking | `~/.detour.yaml` (detours mapping) |
| **Build config** | `config.yaml` (TUI settings) | `config.yaml` (TUI settings) |
| **Location** | In package directory | In package directory |

This separation allows:
- **Version control** of TUI configuration (in git)
- **User-specific** runtime data (not in git)
- **Easy customization** of TUI without affecting user data
- **Consistent UX** between chamon and detour

---

## Migration from Old Format

If you have an old `~/.detour.conf` or `/etc/detour.conf`, convert it to YAML:

**Old format:**
```bash
detour /path/to/original = /path/to/custom
include /path/to/target : /path/to/include
service service_name : restart
```

**New format:**
```yaml
detours:
  - original: /path/to/original
    custom: /path/to/custom

includes:
  - target: /path/to/target
    include: /path/to/include

services:
  - name: service_name
    action: restart
```

---

## Quick Reference

| Task | File to Edit | Location |
|------|--------------|----------|
| Add/remove a detour | `~/.detour.yaml` | Home directory |
| Add an include directive | `~/.detour.yaml` | Home directory |
| Add a service action | `~/.detour.yaml` | Home directory |
| Change TUI keybindings | `config.yaml` | Package directory |
| Customize TUI appearance | `config.yaml` | Package directory |
| Change column widths | `config.yaml` | Package directory |

---

**Remember:**
- Edit `~/.detour.yaml` for **what detours exist**
- Edit `config.yaml` for **how the TUI looks and behaves**

