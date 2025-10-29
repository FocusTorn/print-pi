# Home Assistant Helper Script (`ha`)

Complete development toolkit for managing Home Assistant on your Raspberry Pi. Streamlines configuration management, validation, backups, and container operations.

## Installation

The helper script is located at:
```bash
/home/pi/_playground/_scripts/ha-helper.sh
```

### Create Global Command (Recommended)

Add a symlink to make it globally available:
```bash
sudo ln -s /home/pi/_playground/_scripts/ha-helper.sh /usr/local/bin/ha
```

Or add an alias to your `.zshrc`:
```bash
alias ha='/home/pi/_playground/_scripts/ha-helper.sh'
```

## Quick Start

```bash
# Check status
ha status

# Validate configuration
ha validate

# Create backup
ha backup "my-backup"

# Restart (auto-creates backup)
ha restart

# View logs
ha logs
```

---

## Command Reference

### 🐳 Container Management

#### `ha status` (alias: `st`)
Shows comprehensive system status including:
- Container status and uptime
- CPU and memory usage
- Home Assistant version
- Access URLs
- Config and backup directory paths

**Example:**
```bash
ha status
```

#### `ha start`
Starts the Home Assistant container if it's stopped.

**Example:**
```bash
ha start
```

#### `ha stop`
Stops the Home Assistant container gracefully.

**Example:**
```bash
ha stop
```

#### `ha restart` (alias: `r`)
Restarts the container with automatic backup creation.

**Options:**
- `--no-backup` - Skip automatic backup

**Example:**
```bash
ha restart                  # With auto-backup
ha restart --no-backup      # Skip backup
```

#### `ha update` (alias: `upgrade`, `up`)
Updates Home Assistant to the latest stable version.

**Process:**
1. Shows current version
2. Creates backup
3. Pulls latest image
4. Recreates container with new version
5. Shows new version and logs

**Example:**
```bash
ha update
```

#### `ha stats` (alias: `stat`)
Shows live resource usage statistics (CPU, memory, network, disk I/O).

Press `Ctrl+C` to exit.

**Example:**
```bash
ha stats
```

#### `ha shell` (alias: `sh`, `bash`)
Opens an interactive bash shell inside the Home Assistant container.

Type `exit` to leave the shell.

**Example:**
```bash
ha shell
```

---

### ⚙️ Configuration Management

#### `ha validate` (alias: `check`, `val`)
Validates your Home Assistant configuration without restarting.

Checks for:
- YAML syntax errors
- Invalid configuration options
- Missing required fields
- Deprecated features

**Example:**
```bash
ha validate
```

**Best Practice:**
Always validate before restarting:
```bash
ha validate && ha restart
```

#### `ha edit [file]` (alias: `e`)
Opens configuration files in your preferred editor (Cursor/VS Code/nano).

**Shortcuts:**
- `config` or `configuration` → `configuration.yaml`
- `auto` or `automations` → `automations.yaml`
- `script` or `scripts` → `scripts.yaml`
- `secret` or `secrets` → `secrets.yaml`
- `scene` or `scenes` → `scenes.yaml`
- `customize` → `customize.yaml`

**Examples:**
```bash
ha edit                     # Opens configuration.yaml
ha edit automations         # Opens automations.yaml
ha edit secrets             # Opens secrets.yaml
ha edit custom_file.yaml    # Opens specific file
```

#### `ha reload [type]` (alias: `rel`)
Reloads specific configuration without full restart.

**Types:**
- `core` or `config` - Core configuration
- `automations`, `automation`, `auto` - Automations
- `scripts`, `script` - Scripts
- `scenes`, `scene` - Scenes
- `themes`, `theme` - Frontend themes

**Examples:**
```bash
ha reload core              # Reload core config
ha reload automations       # Reload automations
ha reload scripts           # Reload scripts
```

**Workflow:**
```bash
ha edit automations         # Make changes
ha reload automations       # Apply without restart
```

#### `ha cd`
Prints the cd command to navigate to the config directory.

**Usage with command substitution:**
```bash
cd $(ha cd)
# or
$(ha cd)
```

---

### 💾 Backup & Restore

All backups are stored in `/home/pi/_playground/_ha-backups/`

#### `ha backup [name]` (alias: `bak`)
Creates a complete backup of your Home Assistant configuration.

**Auto-naming:**
If no name provided, uses timestamp: `2025-10-28-14-30-45`

**What's backed up:**
- All configuration files
- Automations, scripts, scenes
- Custom components
- WWW directory
- Metadata (version, timestamp)

**Examples:**
```bash
ha backup                           # Auto-named with timestamp
ha backup "before-big-changes"      # Custom name
ha backup "working-config-v2"       # Version tracking
```

#### `ha restore <name>` (alias: `res`)
Restores configuration from a backup.

**Safety features:**
- Creates auto-backup before restore
- Shows backup metadata before proceeding
- Requires confirmation
- Automatically restarts container

**Example:**
```bash
ha restore "before-big-changes"
```

#### `ha list-backups` (alias: `list`, `lb`)
Lists all available backups with details.

Shows:
- Backup name
- Creation date/time
- Backup size
- HA version (if available)

**Example:**
```bash
ha list-backups
```

**Output example:**
```
Available Backups:

  before-update-2025-10-28-10-15-30 (2.3M)
    Created: Tue Oct 28 10:15:30 AM EDT 2025

  working-config (2.1M)
    Created: Mon Oct 27 03:45:12 PM EDT 2025
```

---

### 📋 Logs & Debugging

#### `ha logs` (alias: `log`, `l`)
Tails logs in real-time (live streaming).

Press `Ctrl+C` to exit.

**Example:**
```bash
ha logs
```

#### `ha logs-tail [n]` (alias: `tail`, `lt`)
Shows the last N lines of logs (default: 50).

**Examples:**
```bash
ha logs-tail            # Last 50 lines
ha logs-tail 100        # Last 100 lines
ha logs-tail 10         # Last 10 lines
```

#### `ha errors` (alias: `err`, `e`)
Filters logs to show only errors, warnings, critical messages, and exceptions.

Shows last 50 matching lines.

**Example:**
```bash
ha errors
```

---

### ℹ️ Information

#### `ha info` (alias: `i`)
Shows detailed system information including:
- Container name
- Config and backup directories
- Home Assistant version
- Container uptime
- Access URLs
- Quick command reference

**Example:**
```bash
ha info
```

#### `ha help` (alias: `h`, `--help`, `-h`)
Shows complete command reference with examples.

**Example:**
```bash
ha help
```

---

## Workflow Examples

### Daily Development Workflow

```bash
# 1. Check status
ha status

# 2. Edit config
ha edit automations

# 3. Validate before applying
ha validate

# 4. Reload without full restart
ha reload automations

# 5. Check logs for errors
ha errors
```

### Major Configuration Changes

```bash
# 1. Create backup first
ha backup "before-major-changes"

# 2. Make your changes
ha edit configuration

# 3. Validate
ha validate

# 4. Restart (creates another auto-backup)
ha restart

# 5. Watch logs
ha logs-tail 50

# 6. If something broke, restore
ha restore "before-major-changes"
```

### Update Workflow

```bash
# 1. Check current version
ha info

# 2. Update (auto-creates backup)
ha update

# 3. Verify new version
ha status

# 4. Check logs for issues
ha logs-tail 100
```

### Troubleshooting Workflow

```bash
# 1. Check status
ha status

# 2. View errors
ha errors

# 3. Check full logs
ha logs-tail 200

# 4. Validate config
ha validate

# 5. Access container shell if needed
ha shell
```

---

## Auto-Backup System

The script automatically creates timestamped backups before:
- `ha restart` - `before-restart-YYYY-MM-DD-HH-MM-SS`
- `ha restore` - `before-restore-YYYY-MM-DD-HH-MM-SS`
- `ha update` - `before-update-YYYY-MM-DD-HH-MM-SS`

This ensures you can always roll back if something goes wrong.

**Backup Location:** `/home/pi/_playground/_ha-backups/`

**Backup Contents:**
- All configuration files
- Automations, scripts, scenes
- Custom components and integrations
- WWW directory (if exists)
- Metadata file with version and timestamp

**Storage Management:**
Backups are stored in your playground directory, making them:
- Easy to source control with git
- Safe from container recreation
- Portable for system restore

---

## Integration with VS Code / Cursor

The script is designed to work seamlessly with VS Code/Cursor:

### Edit Commands
```bash
ha edit automations     # Opens in Cursor/VS Code
```

The script will:
1. Try `cursor` command first
2. Fall back to `code` if cursor not available
3. Use `nano` as final fallback

### Recommended Workflow
Keep Cursor open with:
```
/home/pi/homeassistant
```

Then use the script for:
- Validation: `ha validate`
- Restart: `ha restart`
- Logs: `ha logs-tail 50`
- Backups: `ha backup`

---

## Tips & Best Practices

### Always Validate First
```bash
ha validate && ha restart
```

### Use Named Backups for Milestones
```bash
ha backup "working-garage-automation"
ha backup "before-adding-solar-integration"
```

### Quick Status Check
```bash
# Add to .zshrc for startup
ha status
```

### Monitor Resources
```bash
# Check if HA is using too much memory
ha stats
```

### Grep Logs
```bash
ha logs-tail 1000 | grep "sensor.temperature"
```

### Combine with Watch
```bash
watch -n 5 'ha errors'
```

---

## Troubleshooting

### "Container not found"
Run the bootstrap script first:
```bash
/home/pi/_playground/_scripts/bootstraps/bootstrap-home-assistant.sh
```

### "Permission denied" for docker
Your user needs to be in the docker group:
```bash
sudo usermod -aG docker pi
exec su - pi
```

### Config validation fails
```bash
# View the specific error
ha validate

# Check logs for more details
ha logs-tail 100

# Restore last working config
ha restore "before-restart-YYYY-MM-DD-HH-MM-SS"
```

### Container won't start
```bash
# Check logs
ha logs

# Try removing and recreating
docker stop homeassistant
docker rm homeassistant

# Run bootstrap again
bootstrap-home-assistant.sh
```

---

## Advanced Usage

### Chaining Commands
```bash
ha validate && ha restart && ha logs-tail 50
```

### Automated Backups (Cron)
```bash
# Add to crontab: Daily backup at 3 AM
0 3 * * * /home/pi/_playground/_scripts/ha-helper.sh backup "auto-$(date +\%Y-\%m-\%d)"
```

### Git Integration
```bash
# Track configs in git
cd /home/pi/homeassistant
git init
git add configuration.yaml automations.yaml scripts.yaml
git commit -m "Initial config"

# After changes
ha backup "pre-git-push"
git add -A
git commit -m "Updated automations"
git push
```

### Remote Management via SSH
```bash
# From your desktop
ssh pi@MyP.local "ha status"
ssh pi@MyP.local "ha restart"
ssh pi@MyP.local "ha logs-tail 100"
```

---

## Files & Directories

| Path | Purpose |
|------|---------|
| `/home/pi/_playground/_scripts/ha-helper.sh` | Main script |
| `/home/pi/homeassistant/` | HA configuration directory |
| `/home/pi/_playground/_ha-backups/` | Backup storage |
| `/home/pi/homeassistant/.vscode/` | VS Code/Cursor settings |
| `/home/pi/homeassistant/_docs/` | Documentation |

---

## Script Features

✅ **Safety First**
- Auto-backups before critical operations
- Confirmation prompts for destructive actions
- Validation before applying changes

✅ **User-Friendly**
- Color-coded output with emojis
- Clear error messages
- Helpful command suggestions

✅ **Efficient**
- Command aliases for speed
- Smart sudo detection
- Fast validation without restart

✅ **Flexible**
- Works with or without docker group
- Multiple editor support
- Customizable backup locations

---

## Support & Documentation

- **Home Assistant Docs:** https://www.home-assistant.io/docs/
- **Docker Docs:** https://docs.docker.com/
- **This Guide:** `/home/pi/homeassistant/_docs/ha-helper-guide.md`

---

**Created:** October 28, 2025  
**Version:** 1.0  
**System:** Raspberry Pi 4 Model B - Debian 13 (trixie)

