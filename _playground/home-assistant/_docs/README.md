# Home Assistant Documentation

Welcome to your Home Assistant installation on Raspberry Pi!

## Quick Start

### Status Check
```bash
ha status              # Check if HA is running
ha info                # View version and URLs
```

### Access Home Assistant
- **Local:** http://192.168.1.159:8123
- **Hostname:** http://MyP.local:8123

### Configuration Workflow
```bash
# 1. Edit configuration
cursor /home/pi/homeassistant/configuration.yaml
# or
ha edit configuration

# 2. Validate changes
ha validate

# 3. Apply changes
ha restart
# or for specific components
ha reload automations

# 4. Check logs
ha logs-tail 50
ha errors
```

## Directory Structure

```
/home/pi/homeassistant/
├── configuration.yaml       ✅ Main config (validated)
├── automations.yaml         ✅ Automations
├── scripts.yaml             ✅ Scripts
├── scenes.yaml              ✅ Scenes
├── secrets.yaml             ✅ Sensitive data
├── customize.yaml           ✅ Entity customizations
│
├── themes/                  ✅ Frontend themes
│   └── default.yaml         ✅ Example theme
│
├── packages/                ✅ Modular configs (optional)
├── blueprints/              ✅ Automation blueprints
├── integrations/            ✅ Custom integrations
├── www/                     ✅ Static files
│
├── .vscode/                 ✅ VS Code settings (X11 loop fixed)
└── _docs/                   ✅ Documentation (you are here)
```

## Documentation Files

### Core Guides
1. **[ha-helper-guide.md](ha-helper-guide.md)** - Complete `ha` command reference
2. **[configuration-structure.md](configuration-structure.md)** - HA configuration guide
3. **[vscode-features-enabled.md](vscode-features-enabled.md)** - VS Code features

### Community Store
4. **[hacs-setup.md](hacs-setup.md)** - HACS installation & usage guide ✅

### Troubleshooting
5. **[x11-symlink-loop-fix.md](x11-symlink-loop-fix.md)** - X11 recursion issue (FIXED ✅)
6. **[pi-memory-optimization.md](pi-memory-optimization.md)** - Memory optimization
7. **[keeping-root-in-workspace.md](keeping-root-in-workspace.md)** - Workspace setup

## Common Tasks

### Edit Configuration Files
```bash
ha edit configuration       # Main config
ha edit automations         # Automations
ha edit scripts             # Scripts
ha edit secrets             # Secrets
```

### Manage Home Assistant
```bash
ha start                    # Start HA
ha stop                     # Stop HA
ha restart                  # Restart (with auto-backup)
ha update                   # Update to latest version
```

### Backup & Restore
```bash
ha backup "my-backup"       # Create backup
ha list-backups             # List all backups
ha restore "my-backup"      # Restore from backup
```

### View Logs
```bash
ha logs                     # Live tail
ha logs-tail 100            # Last 100 lines
ha errors                   # Errors only
```

### Reload Components (No Restart)
```bash
ha reload core              # Core config
ha reload automations       # Automations
ha reload scripts           # Scripts
ha reload scenes            # Scenes
ha reload themes            # Frontend themes
```

## Current Status

✅ **Home Assistant:** Running  
✅ **Configuration:** Valid  
✅ **HA Extension:** Working (X11 loop fixed)  
✅ **Themes Directory:** Created  
✅ **Documentation:** Complete  
✅ **Backup System:** Enabled  
✅ **Helper Script:** `/home/pi/.local/bin/ha`  

## VS Code/Cursor Features

The Home Assistant extension is now working with:
- ✅ Entity autocomplete
- ✅ Service completion
- ✅ Real-time validation
- ✅ Hover documentation
- ✅ Jinja2 template highlighting
- ✅ Custom tag support (!include, !secret)

**Note:** System directories excluded to prevent X11 symlink loop.

## Bootstrap Script

Home Assistant installed via:
```bash
/home/pi/_playground/_scripts/bootstraps/bootstrap-home-assistant.sh
```

Reinstall anytime by running the bootstrap script.

## HACS (Community Store)

✅ **HACS is installed and loaded!**

### First-Time Setup
```bash
# 1. Open Home Assistant web interface
# 2. Go to Settings → Devices & Services
# 3. Click "+ Add Integration"
# 4. Search for "HACS"
# 5. Follow setup wizard (requires free GitHub account)
```

### Using HACS
```bash
# Install integrations, themes, plugins via HACS UI
# Then restart to load them:
ha restart

# Reinstall HACS if needed:
/home/pi/_playground/_scripts/install-hacs.sh
```

### Popular HACS Add-ons
- **Browser Mod** - Advanced browser control
- **Mushroom Cards** - Beautiful Lovelace cards
- **Adaptive Lighting** - Smart lighting automation
- **Mini Graph Card** - Compact graphs

📖 **Full Guide:** [hacs-setup.md](hacs-setup.md)

## Tips

### Prevent Configuration Errors
Always validate before restarting:
```bash
ha validate && ha restart
```

### Safe Experimentation
Create backups before major changes:
```bash
ha backup "before-adding-mqtt"
# Make changes
ha validate && ha restart
# If something breaks:
ha restore "before-adding-mqtt"
```

### Monitor Resources
```bash
ha stats                    # Container resources
free -h                     # System memory
```

### Quick Directory Navigation
```bash
cd /home/pi/homeassistant
# or
cd $(ha cd)
```

## Help

### Command Help
```bash
ha help                     # Show all commands
ha <command> --help         # Command-specific help
```

### Documentation
- `/home/pi/homeassistant/_docs/` - Local documentation
- https://www.home-assistant.io/docs/ - Official docs

### Troubleshooting
If something isn't working:
1. Check status: `ha status`
2. View logs: `ha logs-tail 100`
3. Check errors: `ha errors`
4. Validate config: `ha validate`
5. Review docs in `_docs/`

---

**Installation Date:** October 28, 2025  
**Platform:** Raspberry Pi 4 - Docker  
**Location:** `/home/pi/homeassistant/`  
**Helper:** `ha` command (global)  

**Everything is ready! Start building your smart home! 🏠✨**

