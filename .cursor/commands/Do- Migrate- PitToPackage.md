# Do Migrate PitToPackage

The purpose of this command is to migrate a Python project from `snake-pit/projects/` to `_dev/packages/` as an installable systemd service package.

## 1. :: Instructions

### 1.1. :: Initial Execution <!-- Start Fold -->

1. **Identify project**: Locate the project in `/home/pi/_playground/snake-pit/projects/<project-name>/`
2. **Verify prerequisites**: Confirm project has main script, dependencies, and should run as service
3. **Create package structure**: Set up directories in `_dev/packages/<project-name>/`
4. **Copy and fix files**: Migrate files and update hardcoded paths
5. **Create service files**: Generate systemd service file, install/uninstall scripts
6. **Create documentation**: Write package README with usage instructions
7. **Archive original**: Compress original project and move to `_archived/`
8. **Verify migration**: Run verification checklist and test installation

**NOTES**:
- Follow the pattern established by `bme680-service` package
- All paths must be user-agnostic (use `~` and user detection)
- Service files must use placeholders (`%h`, `%i`) for install-time substitution
- Package must be self-contained in `~/.local/share/`

<!-- Close Fold -->

### 1.2. :: When to Use This Command <!-- Start Fold -->

Use this migration when:

- Project needs to run as a systemd daemon/service
- Project should have install/uninstall scripts for easy deployment
- Project needs self-contained installation to `~/.local/share/`
- Project follows the pattern of other packages like `bme680-service`
- Project should be independent of development environment paths

**Do NOT use** for:
- Simple scripts that don't need service management
- Development-only projects that don't need installation
- Projects that are tightly coupled to snake-pit environment

<!-- Close Fold -->

## 2. :: Prerequisites

### 2.1. :: Project Requirements <!-- Start Fold -->

Before migration, verify:

- [ ] Project exists in `/home/pi/_playground/snake-pit/projects/<project-name>/`
- [ ] Project has a main Python script (`.py` file)
- [ ] Project has dependencies defined (`requirements.txt`)
- [ ] Project should run as a daemon/service (not just a one-time script)
- [ ] Project functionality is tested and working

<!-- Close Fold -->

### 2.2. :: Reference Package <!-- Start Fold -->

Always reference the existing package pattern:
- **Location**: `/home/pi/_playground/_dev/packages/bme680-service/`
- **Study**: `install.sh`, `uninstall.sh`, `services/*.service`, `README.md`
- **Pattern**: Self-contained installation, user detection, venv management

<!-- Close Fold -->

## 3. :: Migration Steps

### 3.1. :: Create Package Structure <!-- Start Fold -->

```bash
PACKAGE_NAME="<project-name>"
mkdir -p /home/pi/_playground/_dev/packages/${PACKAGE_NAME}/{data,services,config}
```

**Required directories**:
- `data/` - Main script and dependencies
- `services/` - Systemd service files
- `config/` - Configuration templates

<!-- Close Fold -->

### 3.2. :: Copy Project Files <!-- Start Fold -->

Copy essential files from snake-pit project:

```bash
# Main script (rename if needed for clarity)
cp /home/pi/_playground/snake-pit/projects/${PACKAGE_NAME}/*.py \
   /home/pi/_playground/_dev/packages/${PACKAGE_NAME}/data/

# Dependencies
cp /home/pi/_playground/snake-pit/projects/${PACKAGE_NAME}/requirements.txt \
   /home/pi/_playground/_dev/packages/${PACKAGE_NAME}/data/

# Config templates (if they exist)
cp /home/pi/_playground/snake-pit/projects/${PACKAGE_NAME}/config/*.dist \
   /home/pi/_playground/_dev/packages/${PACKAGE_NAME}/config/ 2>/dev/null || true
```

**Important**: Preserve file permissions and executable bits.

<!-- Close Fold -->

### 3.3. :: Fix Hardcoded Paths <!-- Start Fold -->

Search for and fix hardcoded paths in main script:

**Common patterns to fix**:
- `/home/pi/bin/...` → `~/.local/share/${PACKAGE_NAME}/...`
- `/opt/...` → Use relative paths or config-based paths
- User-specific paths → Use `os.path.expanduser('~')`

**Example transformation**:
```python
# Before:
default_update_flag_filespec = '/home/pi/bin/lastupd.date'

# After:
default_update_flag_filespec = os.path.join(
    os.path.expanduser('~'), '.local', 'share', 'package-name', 'lastupd.date')
```

**Verification**: Run `grep -rn "/home/pi\|/opt/" data/*.py` to find remaining hardcoded paths.

<!-- Close Fold -->

### 3.4. :: Create Systemd Service File <!-- Start Fold -->

Create `services/${PACKAGE_NAME}.service`:

```ini
[Unit]
Description=<Service Description>
Documentation=<URL if applicable>
After=network.target mosquitto.service network-online.target
Wants=network-online.target
Requires=network.target

[Service]
Type=notify
User=%i
Group=%i
WorkingDirectory=%h/.local/share/${PACKAGE_NAME}
Environment="PATH=%h/.local/share/${PACKAGE_NAME}/.venv/bin:/usr/local/bin:/usr/bin:/bin"
Environment="PYTHONUNBUFFERED=1"
ExecStart=%h/.local/share/${PACKAGE_NAME}/.venv/bin/python %h/.local/share/${PACKAGE_NAME}/<script-name>.py --config %h/.local/share/${PACKAGE_NAME}/config
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${PACKAGE_NAME}
NotifyAccess=all

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=%h/.local/share/${PACKAGE_NAME}

[Install]
WantedBy=multi-user.target
```

**Key placeholders**:
- `%i` - User (replaced during install)
- `%h` - Home directory (replaced during install)
- `${PACKAGE_NAME}` - Package name variable

**Critical paths**:
- Install directory: `~/.local/share/${PACKAGE_NAME}/`
- Config directory: `~/.local/share/${PACKAGE_NAME}/config`
- Venv directory: `~/.local/share/${PACKAGE_NAME}/.venv/`

<!-- Close Fold -->

### 3.5. :: Create Install Script <!-- Start Fold -->

Create `install.sh` with required functions:

**Script structure**:
```bash
#!/bin/bash
# Package Installation Script
set -e

# 1. Path and user detection setup
# 2. install_package_files() function
# 3. setup_python_environment() function
# 4. install_service() function
# 5. enable_service() function
# 6. main() function
```

**Required functions**:

- **`install_package_files()`**:
  - Create `~/.local/share/${PACKAGE_NAME}/` directory
  - Copy script files from `data/` directory
  - Copy config template to `config/config.ini` (if doesn't exist)
  - Set ownership to original user (before sudo)

- **`setup_python_environment()`**:
  - Create virtual environment in `~/.local/share/${PACKAGE_NAME}/.venv/`
  - **Use `uv` as primary tool** (faster, more reliable), fallback to `python3 -m venv` if not available
  - Install dependencies from `requirements.txt` using `uv pip install` or `pip install` accordingly
  - Run as original user (use `sudo -u $ORIGINAL_USER`)
  - **Note**: `uv` is installed globally via `bootstrap-snake-pit.sh` and should be available

- **`install_service()`**:
  - Replace `%i` and `%h` placeholders in service file with actual user/home
  - Copy to `/etc/systemd/system/${SERVICE_NAME}.service`
  - Run `systemctl daemon-reload`

- **`enable_service()`**:
  - Enable service with `systemctl enable`
  - Start service with `systemctl start`
  - Handle failures gracefully (may fail if MQTT not configured)

**User detection pattern** (MANDATORY):
```bash
ORIGINAL_USER="${SUDO_USER:-$USER}"
ORIGINAL_HOME=$(getent passwd "$ORIGINAL_USER" | cut -d: -f6)
if [ -z "$ORIGINAL_HOME" ]; then
    ORIGINAL_HOME="/home/$ORIGINAL_USER"
fi
```

**Auto-elevation pattern**:
```bash
if [ "$EUID" -ne 0 ]; then
    exec sudo "$0" "$@"
fi
```

**Reference**: See `/home/pi/_playground/_dev/packages/bme680-service/install.sh` for complete example.

<!-- Close Fold -->

### 3.6. :: Create Uninstall Script <!-- Start Fold -->

Create `uninstall.sh`:

**Required functionality**:
1. Detect original user (same pattern as install.sh)
2. Stop and disable systemd service
3. Remove service file from `/etc/systemd/system/`
4. Reload systemd daemon
5. Ask user about removing package files (optional removal)
6. Remove `~/.local/share/${PACKAGE_NAME}/` if user confirms

**User interaction pattern**:
```bash
read -p "Remove installed package files? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$INSTALL_ROOT"
fi
```

<!-- Close Fold -->

### 3.7. :: Create Package README <!-- Start Fold -->

Create comprehensive `README.md` with sections:

1. **Package description** - What it does, key features
2. **Package structure** - Directory layout
3. **Installation locations** - Where files are installed
4. **Prerequisites** - System requirements, dependencies
5. **Installation** - Step-by-step install instructions
6. **Configuration** - How to configure the service
7. **Usage** - Service management commands, manual testing
8. **Integration** - MQTT topics, Home Assistant integration (if applicable)
9. **Uninstallation** - How to remove the package
10. **Troubleshooting** - Common issues and solutions

**Reference**: See `/home/pi/_playground/_dev/packages/bme680-service/README.md` for structure.

<!-- Close Fold -->

### 3.8. :: Archive Snake-Pit Version <!-- Start Fold -->

Move original project to compressed archive:

```bash
# Create archive directory if it doesn't exist
mkdir -p /home/pi/_playground/snake-pit/projects/_archived

# Compress the project (from archive directory)
cd /home/pi/_playground/snake-pit/projects/_archived
tar -czf ${PACKAGE_NAME}-archived.tar.gz \
    -C /home/pi/_playground/snake-pit/projects \
    ${PACKAGE_NAME}/

# Remove uncompressed directory
rm -rf /home/pi/_playground/snake-pit/projects/${PACKAGE_NAME}
```

**Archive naming**: `<package-name>-archived.tar.gz`

**Verification**: Extract and verify archive contains all files:
```bash
tar -tzf ${PACKAGE_NAME}-archived.tar.gz | head -10
```

<!-- Close Fold -->

### 3.9. :: Create Archive Documentation <!-- Start Fold -->

Create or update `_archived/README.md`:

```markdown
# Archived Projects

This directory contains compressed archives of projects moved to other locations.

### ${PACKAGE_NAME}-archived.tar.gz

**Original location:** snake-pit/projects/${PACKAGE_NAME}/  
**New location:** _dev/packages/${PACKAGE_NAME}/

**To extract:** `tar -xzf ${PACKAGE_NAME}-archived.tar.gz`
```

**Optional**: Create `ARCHIVED.md` inside the project directory before compressing to document why it was moved.

<!-- Close Fold -->

### 3.10. :: Make Scripts Executable <!-- Start Fold -->

```bash
chmod +x /home/pi/_playground/_dev/packages/${PACKAGE_NAME}/install.sh
chmod +x /home/pi/_playground/_dev/packages/${PACKAGE_NAME}/uninstall.sh
```

<!-- Close Fold -->

## 4. :: Verification Checklist

### 4.1. :: Post-Migration Verification <!-- Start Fold -->

After migration, verify all items:

- [ ] Package structure matches `bme680-service` pattern
- [ ] All files copied to correct directories (`data/`, `services/`, `config/`)
- [ ] Hardcoded paths fixed in main script (no `/home/pi` or `/opt` references)
- [ ] Service file uses correct paths (`%h`, `%i` placeholders, not hardcoded)
- [ ] Install script handles user detection correctly (captures user before sudo)
- [ ] Install script creates venv and installs dependencies
- [ ] Install script substitutes placeholders in service file
- [ ] Uninstall script stops, disables, and removes service
- [ ] README.md is comprehensive with all required sections
- [ ] Original project archived and compressed (`.tar.gz` file exists)
- [ ] Archive documentation updated in `_archived/README.md`
- [ ] Install script is executable (`chmod +x`)
- [ ] Uninstall script is executable (`chmod +x`)
- [ ] No hardcoded usernames in any files
- [ ] All paths use `~/.local/share/` or user expansion

<!-- Close Fold -->

### 4.2. :: Testing Steps <!-- Start Fold -->

Test the migrated package:

```bash
# 1. Test installation
cd /home/pi/_playground/_dev/packages/${PACKAGE_NAME}
./install.sh

# 2. Check service status
systemctl status ${PACKAGE_NAME}

# 3. View logs if service started
journalctl -u ${PACKAGE_NAME} -n 50

# 4. Test uninstallation
./uninstall.sh
```

**Expected results**:
- Installation completes without errors
- Service file created in `/etc/systemd/system/`
- Package files in `~/.local/share/${PACKAGE_NAME}/`
- Service starts (may fail if MQTT not configured - that's expected)
- Uninstallation removes service and optionally package files

<!-- Close Fold -->

## 5. :: Key Principles

### 5.1. :: Design Principles <!-- Start Fold -->

1. **Self-contained**: Package installs to `~/.local/share/` independently of development paths
2. **User-aware**: Scripts detect user before sudo elevation to preserve correct ownership
3. **Clean uninstall**: All files can be removed cleanly without leaving artifacts
4. **Standard locations**: Follows Linux FHS conventions for user data
5. **Isolated dependencies**: Own virtual environment prevents conflicts
6. **Service management**: Proper systemd integration with auto-restart and logging

<!-- Close Fold -->

### 5.2. :: Path Guidelines <!-- Start Fold -->

**Installation paths**:
- Package root: `~/.local/share/${PACKAGE_NAME}/`
- Virtual environment: `~/.local/share/${PACKAGE_NAME}/.venv/`
- Configuration: `~/.local/share/${PACKAGE_NAME}/config/`
- Service file: `/etc/systemd/system/${PACKAGE_NAME}.service`

**Avoid**:
- Hardcoded `/home/pi` paths
- `/opt/` or `/usr/local/` for user packages
- Development paths (`_playground`, `snake-pit`)
- Relative paths that break when service runs

<!-- Close Fold -->

## 6. :: Reference

### 6.1. :: Common Patterns <!-- Start Fold -->

**User detection**:
```bash
ORIGINAL_USER="${SUDO_USER:-$USER}"
ORIGINAL_HOME=$(getent passwd "$ORIGINAL_USER" | cut -d: -f6)
```

**Service file placeholder substitution**:
```bash
sed "s|User=%i|User=$ORIGINAL_USER|g; s|%h|$ORIGINAL_HOME|g" \
    "$service_file" > "/etc/systemd/system/${SERVICE_NAME}.service"
```

**Venv setup with uv (primary) and pip fallback**:
```bash
if command -v uv &> /dev/null; then
    # Use uv (preferred - faster, more reliable)
    sudo -u "$ORIGINAL_USER" uv venv "$VENV_DIR"
    sudo -u "$ORIGINAL_USER" uv pip install -r "$DATA_DIR/requirements.txt" --python "$VENV_DIR/bin/python" || \
    sudo -u "$ORIGINAL_USER" "$VENV_DIR/bin/pip" install -r "$DATA_DIR/requirements.txt"
else
    # Fallback to traditional venv/pip
    sudo -u "$ORIGINAL_USER" python3 -m venv "$VENV_DIR"
    sudo -u "$ORIGINAL_USER" "$VENV_DIR/bin/pip" install --upgrade pip
    sudo -u "$ORIGINAL_USER" "$VENV_DIR/bin/pip" install -r "$DATA_DIR/requirements.txt"
fi
```

**Note**: `uv` is installed globally via `bootstrap-snake-pit.sh` and should be available in all `_dev` packages. The fallback to pip is for edge cases where uv might not be installed.

<!-- Close Fold -->
