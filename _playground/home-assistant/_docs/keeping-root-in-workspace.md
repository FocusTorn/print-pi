# Keeping `/` in Workspace While Preventing HA Extension Scanning

## The Challenge

You want:
- ✅ `/` (root) in Explorer for easy system file access
- ❌ Home Assistant extension NOT scanning system directories
- ❌ No X11 symlink loop crashes

## Solution: Multi-Root Workspace with Exclusions

### 1. Use the Workspace File

A workspace configuration file has been created at:
```
/home/pi/printy-pi.code-workspace
```

**To use it:**
```bash
# Open the workspace
cursor /home/pi/printy-pi.code-workspace
```

This workspace includes:
- `/home/pi/homeassistant` - HA configs (HA extension active)
- `/home/pi/_playground` - Scripts
- `/` - System root (HA extension disabled for this folder)

### 2. Workspace Features

The workspace configuration:

✅ **Massive exclusions** - All system paths excluded from scanning  
✅ **Folder-specific settings** - Root folder has different file associations  
✅ **Safe browsing** - You can still browse `/` in Explorer  
✅ **HA features only where needed** - Extension active only in HA folder  

### 3. How It Works

```
/home/pi/homeassistant/
  ├── .yaml files → treated as "home-assistant" language
  └── HA extension: ACTIVE ✅

/home/pi/_playground/
  ├── scripts, tools
  └── HA extension: inactive

/ (root)
  ├── browsable in Explorer ✅
  ├── .yaml files → treated as plain "yaml"
  └── HA extension: DISABLED ❌
```

## Alternative Solutions

If the workspace file doesn't fully solve it, here are alternatives:

### Option A: Disable Extension, Use CLI

**Disable the extension:**
1. Press `Ctrl+Shift+P`
2. Type "Extensions: Disable"
3. Search "Home Assistant"
4. Select "Disable (Workspace)"

**Use the `ha` command instead:**
```bash
ha validate          # Instead of real-time validation
ha edit config       # Opens files
ha errors            # Check for problems
```

**Benefits:**
- ✅ No extension crashes
- ✅ Keep `/` in workspace
- ✅ Full filesystem access
- ✅ Command-line validation works great

### Option B: Conditional Extension Loading

**Enable extension only when working in HA folder:**

1. Keep extension disabled globally
2. When editing HA configs:
   ```
   Ctrl+Shift+P → "Extensions: Enable (Workspace)"
   ```
3. When done:
   ```
   Ctrl+Shift+P → "Extensions: Disable (Workspace)"
   ```

### Option C: Symbolic Link Trick

Create a separate workspace without `/`, but use symlinks:

```bash
# Create a links directory
mkdir -p /home/pi/_links

# Link to common system directories you access
ln -s /etc /home/pi/_links/etc
ln -s /var/log /home/pi/_links/log
ln -s /usr/local /home/pi/_links/local

# Use workspace: /home/pi only
# Access system files via /home/pi/_links/
```

**Benefits:**
- ✅ No `/` in workspace
- ✅ Access system files via symlinks
- ✅ No X11 loop (symlinks are explicit)

### Option D: Use File > Open File

Don't add `/` to workspace, just open system files individually:

```bash
# From terminal
cursor /etc/nginx/nginx.conf

# Or in Cursor: File > Open File
```

Files open in the same window without indexing the whole system.

## Recommended Approach

**For best results:**

1. **Use the workspace file**: `/home/pi/printy-pi.code-workspace`
2. **If extension still scans `/`**: Disable it and use `ha` CLI
3. **Keep the settings in**: `/home/pi/homeassistant/.vscode/settings.json`

## Testing the Workspace

```bash
# 1. Close current workspace
# File > Close Workspace

# 2. Open the workspace file
cursor /home/pi/printy-pi.code-workspace

# 3. Check if HA extension activates
# Open: /home/pi/homeassistant/configuration.yaml
# Should have autocomplete ✅

# 4. Check if it ignores root
# Browse to /bin in Explorer
# Extension should not scan it ✅

# 5. Monitor memory
ha stats
free -h
```

## If Extension Still Crashes

The Home Assistant extension may not respect folder-specific exclusions perfectly. In that case:

**Permanent solution:**
```bash
# Uninstall the extension
cursor --uninstall-extension keesschollaart.vscode-home-assistant

# Use lightweight alternatives:
# - redhat.vscode-yaml (basic YAML support)
# - ha command-line tool (validation, restart, logs)
```

**You get:**
- ✅ Syntax highlighting (via YAML extension)
- ✅ Validation (via `ha validate`)
- ✅ Quick restart (via `ha restart`)
- ✅ Log viewing (via `ha logs`)
- ✅ No crashes
- ✅ Keep `/` in workspace

## Summary

**Problem:** HA extension scans `/` and hits X11 loop  
**Root cause:** Extension doesn't have per-folder scanning controls  
**Best fix:** Use workspace file with massive exclusions  
**Backup plan:** Disable extension, use `ha` CLI tool  

The `ha` command-line helper is actually **more efficient and reliable** than the extension on Pi!

---

**Created:** October 28, 2025  
**Workspace file:** `/home/pi/printy-pi.code-workspace`  
**Status:** Testing required




