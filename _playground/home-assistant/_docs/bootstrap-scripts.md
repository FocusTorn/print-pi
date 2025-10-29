# Bootstrap Scripts Reference

Complete guide to all bootstrap scripts for Home Assistant and related services.

## Available Bootstrap Scripts

All scripts located in: `/home/pi/_playground/_scripts/bootstraps/`

### 🏠 Home Assistant
**Script:** `bootstrap-home-assistant.sh`

**What it does:**
- Installs Docker (if needed)
- Creates Home Assistant container
- Sets up complete directory structure
- Creates all configuration files with examples
- Configures VS Code settings (prevents X11 loop)
- Sets up `ha` command globally
- Offers to install HACS

**Usage:**
```bash
/home/pi/_playground/_scripts/bootstraps/bootstrap-home-assistant.sh
```

**Includes:**
- configuration.yaml (with proper includes)
- customize.yaml (with examples)
- themes/default.yaml
- All YAML files (automations, scripts, scenes)
- .gitignore
- VS Code settings
- Documentation

---

### 🏪 HACS (Community Store)
**Script:** `bootstrap-hacs.sh`

**What it does:**
- Downloads latest HACS release
- Installs to `custom_components/hacs/`
- Sets proper permissions
- Offers to restart Home Assistant

**Usage:**
```bash
/home/pi/_playground/_scripts/bootstraps/bootstrap-hacs.sh
```

**Post-install:**
1. Restart HA: `ha restart`
2. Settings → Devices & Services
3. Add Integration → Search "HACS"
4. Authenticate with GitHub

**Documentation:** [hacs-setup.md](hacs-setup.md)

---

### 🖨️  Bambu Lab Integration
**Script:** `bootstrap-bambulab.sh`

**What it does:**
- Downloads latest Bambu Lab integration
- Installs to `custom_components/bambu_lab/`
- Sets proper permissions
- Offers to restart Home Assistant

**Usage:**
```bash
/home/pi/_playground/_scripts/bootstraps/bootstrap-bambulab.sh
```

**Post-install:**
1. Restart HA: `ha restart`
2. Settings → Devices & Services
3. Add Integration → Search "Bambu Lab"
4. Configure:
   - Printer IP address
   - Device serial number
   - Access code
   - Connection type (LAN/Cloud)

**Connection Types:**
- **LAN Mode (Recommended):**
  - Faster, more reliable
  - Enable in Bambu Studio: Device → Network → LAN Only Mode
  - Requires printer IP address
  
- **Cloud Mode:**
  - Works from anywhere
  - Requires Bambu Cloud credentials
  - Slightly slower

**Features:**
- Real-time printer status
- Print progress monitoring
- Temperature sensors
- Camera feed
- Control buttons (pause, resume, cancel)
- Filament sensors
- AMS status (if equipped)

---

### 🔴 Node-RED
**Script:** `bootstrap-nodered.sh`

**What it does:**
- Creates Node-RED container (separate from HA)
- Sets up data directory at `/home/pi/nodered`
- Configures network access
- Runs on port 1880

**Usage:**
```bash
/home/pi/_playground/_scripts/bootstraps/bootstrap-nodered.sh
```

**Access:**
- http://192.168.1.159:1880
- http://MyP.local:1880

**Post-install Setup:**
1. Access Node-RED web interface
2. Menu → Manage palette
3. Install → Search: `node-red-contrib-home-assistant-websocket`
4. Add "server" configuration node
5. Create Long-Lived Access Token in HA:
   - HA → Profile → Security tab
   - Create token
   - Paste in Node-RED server config

**Features:**
- Visual flow programming
- Direct MQTT access to Bambu Lab printer
- Complex automation workflows
- Integration with external services
- Data processing and transformation

---

## Complete Installation Sequence

### Fresh System Setup
```bash
# 1. Home Assistant (includes HACS prompt)
/home/pi/_playground/_scripts/bootstraps/bootstrap-home-assistant.sh

# 2. Bambu Lab integration (optional)
/home/pi/_playground/_scripts/bootstraps/bootstrap-bambulab.sh

# 3. Node-RED (optional)
/home/pi/_playground/_scripts/bootstraps/bootstrap-nodered.sh

# 4. Verify everything
ha status
docker ps
```

### Reinstall Individual Components
```bash
# Just HACS
/home/pi/_playground/_scripts/bootstraps/bootstrap-hacs.sh

# Just Bambu Lab
/home/pi/_playground/_scripts/bootstraps/bootstrap-bambulab.sh

# Just Node-RED
/home/pi/_playground/_scripts/bootstraps/bootstrap-nodered.sh
```

---

## Bambu Lab + Node-RED Integration

### Why Use Both?

**HACS Integration (Simple):**
- ✅ Quick setup
- ✅ Basic monitoring and control
- ✅ Dashboard ready
- ✅ Standard automations

**Node-RED (Advanced):**
- ✅ Complex workflows
- ✅ Direct MQTT control
- ✅ Custom commands
- ✅ Multi-step logic
- ✅ External integrations

**Best Practice:** Use both!
- HACS for daily monitoring
- Node-RED for advanced automation

### Example: Advanced Print Workflow

**Via Node-RED:**
```
1. Printer starts → Send Telegram notification
2. Print 50% complete → Flash office lights
3. Print failed 3x → Create HA issue ticket
4. Filament < 10% → Send shopping list reminder
5. Print complete → Turn off lights, play sound
```

### MQTT Topics (for Node-RED)

Bambu Lab uses MQTT for communication:

**Subscribe to:**
- `device/{serial}/report` - Printer status updates
- `device/{serial}/print` - Print job info

**Publish to:**
- `device/{serial}/request` - Send commands

**Common Commands:**
```json
// Pause print
{"print": {"command": "pause"}}

// Resume print
{"print": {"command": "resume"}}

// Stop print
{"print": {"command": "stop"}}
```

---

## Container Management

### View All Containers
```bash
docker ps -a
```

### Manage Containers
```bash
# Home Assistant
ha restart
ha logs
ha status

# Node-RED
docker restart nodered
docker logs -f nodered
docker stop nodered
docker start nodered

# Both
docker restart homeassistant nodered
```

### Resource Monitoring
```bash
# Overall status
ha stats

# All containers
docker stats

# System resources
free -h
df -h
```

---

## Troubleshooting

### Home Assistant Won't Start
```bash
ha logs-tail 100
ha errors
ha validate

# Check Docker
docker ps -a
docker logs homeassistant
```

### HACS Not Showing
```bash
# Verify installation
ls -la /home/pi/homeassistant/custom_components/hacs/

# Restart and clear cache
ha restart
# Then: Ctrl+Shift+R in browser
```

### Bambu Lab Not Connecting
```bash
# Check integration files
ls -la /home/pi/homeassistant/custom_components/bambu_lab/

# Verify printer network
ping <printer-ip>

# Check HA logs
ha logs-tail 100 | grep -i bambu

# Enable LAN mode on printer
# Bambu Studio → Device → Network → LAN Only Mode
```

### Node-RED Can't Connect to HA
```bash
# Check Node-RED logs
docker logs nodered

# Verify HA running
ha status

# Check Long-Lived Access Token
# HA → Profile → Security → Create token

# Verify URL in Node-RED
# Should be: http://192.168.1.159:8123
```

---

## Backup Before Changes

Always backup before running bootstrap scripts:

```bash
# Backup Home Assistant
ha backup "before-reinstall"

# Backup Node-RED flows
cp /home/pi/nodered/flows.json /home/pi/nodered/flows_backup.json

# List backups
ha list-backups
```

---

## Update Scripts

Scripts are in git repo, so updating is easy:

```bash
cd /home/pi/_playground
git pull

# Scripts automatically updated
```

---

## Quick Reference

| Component | Bootstrap Script | Access URL | Container Name |
|-----------|-----------------|------------|----------------|
| Home Assistant | `bootstrap-home-assistant.sh` | :8123 | `homeassistant` |
| HACS | `bootstrap-hacs.sh` | - | - |
| Bambu Lab | `bootstrap-bambulab.sh` | - | - |
| Node-RED | `bootstrap-nodered.sh` | :1880 | `nodered` |

| Task | Command |
|------|---------|
| Full setup | Run all bootstrap scripts in order |
| HA management | `ha <command>` |
| Container logs | `docker logs <container>` |
| Restart container | `docker restart <container>` |
| List containers | `docker ps -a` |
| System resources | `free -h && df -h` |

---

**Last Updated:** October 28, 2025  
**Platform:** Raspberry Pi 4 - Debian 13  
**Docker:** Required for all components

