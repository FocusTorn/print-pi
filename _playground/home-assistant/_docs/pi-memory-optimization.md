# Working with Home Assistant on Raspberry Pi

## Memory Constraints

Your Raspberry Pi 4 has **3.7 GB RAM**, which is shared between:
- System processes
- SSH/remote development server (Cursor/VS Code)
- Home Assistant container
- Other services

When editing HA configs remotely, VS Code extensions can consume significant memory, causing crashes.

## The Problem You Encountered

**Error:** `JavaScript heap out of memory`

**Cause:** The Home Assistant language server extension (`keesschollaart.vscode-home-assistant`) is too memory-intensive for remote development on Pi.

**Impact:**
- Extension crashes when analyzing YAML files
- Cursor server restarts repeatedly
- Poor editing experience

---

## Solution: Lightweight Development Workflow

### ✅ Recommended Approach

**Use the `ha` command-line tool instead of heavy extensions:**

```bash
# Edit files in Cursor (no extension needed)
cursor /home/pi/homeassistant/configuration.yaml

# Validate using terminal (lightweight)
ha validate

# Apply changes
ha restart

# Check for errors
ha errors
```

### ⚙️ VS Code Settings Optimized

The `.vscode/settings.json` has been configured for **minimal memory usage:**

**Disabled Features:**
- Home Assistant language server ❌
- YAML schema validation ❌
- IntelliSense/autocomplete ❌
- Hover documentation ❌
- Minimap ❌
- Heavy file watchers ❌

**Enabled Features:**
- Basic YAML syntax highlighting ✅
- Manual formatting ✅
- File editing ✅
- Git integration ✅

---

## Development Workflow

### 1. Edit Files Locally in Cursor

```bash
# Open HA config directory
cursor /home/pi/homeassistant

# Edit files normally
# Syntax highlighting works, but no autocomplete
```

### 2. Validate Before Applying

```bash
# Check for errors
ha validate
```

### 3. Apply Changes

```bash
# Full restart (with auto-backup)
ha restart

# Or reload specific components (faster)
ha reload automations
ha reload scripts
```

### 4. Check Results

```bash
# View recent logs
ha logs-tail 50

# Filter for errors
ha errors
```

---

## Alternative: Edit on Desktop

If you need full IDE features with autocomplete:

### Option A: Edit Locally, Sync to Pi

1. **Install HA extension on your desktop** (has more RAM)
2. **Edit files locally** with full autocomplete
3. **Sync to Pi** using rsync or git:

```bash
# From your desktop
rsync -av ./homeassistant/ pi@MyP.local:/home/pi/homeassistant/
```

### Option B: Use SSH FS

Mount the Pi's filesystem on your desktop:

1. Install **SSHFS** extension on desktop
2. Mount `/home/pi/homeassistant`
3. Edit with full features locally
4. Changes automatically sync

---

## Memory Monitoring

### Check Current Usage

```bash
# Overall system memory
free -h

# Cursor server memory usage
ps aux | grep cursor-server | awk '{sum+=$6} END {print sum/1024 " MB"}'

# Home Assistant container memory
ha stats
```

### If System is Low on Memory

```bash
# Restart Cursor server
killall node

# Reduce HA memory (edit /home/pi/homeassistant/configuration.yaml)
# Add under 'homeassistant:':
#   purge_keep_days: 3
#   recorder:
#     purge_keep_days: 3
#     db_url: sqlite:////config/home-assistant_v2.db
#     commit_interval: 30
```

---

## Extensions to Avoid on Pi

These extensions are **too heavy** for remote Pi development:

❌ **Home Assistant Config Helper** - Uses ~200MB+ RAM  
❌ **Python** (with full IntelliSense) - Heavy language server  
❌ **ESLint/Prettier** - Continuous file analysis  
❌ **GitLens** - Large history analysis  
❌ **Docker** (with all features) - Use `ha` commands instead  

---

## Lightweight Extensions (OK to Use)

These are fine on Pi:

✅ **YAML** (basic, no validation)  
✅ **Git** (built-in)  
✅ **Simple file browsers/explorers**  
✅ **Basic color themes**  

---

## Best Practices

### 1. Use Command-Line Tools

```bash
# Instead of HA extension autocomplete
ha edit automations        # Opens in Cursor
ha validate               # Check syntax
ha reload automations     # Apply changes
```

### 2. Keep Database Small

```yaml
# In configuration.yaml
recorder:
  purge_keep_days: 7
  commit_interval: 30
```

### 3. Limit Logs

```yaml
# In configuration.yaml
logger:
  default: warning
  logs:
    homeassistant.core: info
```

### 4. Monitor Resources

```bash
# Check before starting big edits
ha stats
free -h
```

### 5. Restart Services Periodically

```bash
# If Cursor feels sluggish
killall node
# Reconnect SSH session

# If HA is using too much memory
ha restart
```

---

## Quick Reference Card

| Task | Command |
|------|---------|
| Edit config | `cursor /home/pi/homeassistant/configuration.yaml` |
| Validate | `ha validate` |
| Apply changes | `ha restart` or `ha reload <type>` |
| View logs | `ha logs-tail 50` |
| Check errors | `ha errors` |
| Check memory | `ha stats` or `free -h` |
| Backup before big changes | `ha backup "name"` |

---

## When to Use Desktop vs Pi

### Edit on Pi (via SSH) When:
- ✅ Quick config changes
- ✅ Testing automations
- ✅ Checking logs
- ✅ Making small adjustments

### Edit on Desktop When:
- ✅ Major configuration overhaul
- ✅ Need autocomplete for entities
- ✅ Learning HA syntax
- ✅ Writing complex automations

---

## Troubleshooting

### Extension Keeps Crashing

**Solution:** Disable it
```bash
# Uninstall HA extension
code --uninstall-extension keesschollaart.vscode-home-assistant

# Or disable in settings UI
```

### Cursor Server Out of Memory

**Solution:** Reduce features
```bash
# Kill and restart
killall node

# Edit workspace settings to disable more features
cursor /home/pi/homeassistant/.vscode/settings.json
```

### Can't Validate Config

**Solution:** Use terminal
```bash
# Don't rely on extension
ha validate

# This runs validation inside HA container (lightweight)
```

---

## Summary

**Key Takeaway:** On Raspberry Pi, prefer **command-line validation** over heavy IDE extensions.

The `ha` helper script provides all the functionality you need without the memory overhead:
- ✅ Validation
- ✅ Restart/reload
- ✅ Log viewing
- ✅ Backup/restore
- ✅ Error filtering

Use Cursor for **editing only** (syntax highlighting), and `ha` commands for **everything else**.

---

**Updated:** October 28, 2025  
**System:** Raspberry Pi 4 Model B (3.7 GB RAM)





