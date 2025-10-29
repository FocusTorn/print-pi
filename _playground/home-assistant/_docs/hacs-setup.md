# HACS Setup Guide

**HACS (Home Assistant Community Store)** is installed and ready to use!

## What is HACS?

HACS allows you to discover, download, and manage:
- **Custom Integrations** - Additional device/service integrations
- **Themes** - Beautiful UI themes
- **Frontend Plugins** - Custom Lovelace cards and plugins
- **AppDaemon Apps** - Advanced automation apps
- **NetDaemon Apps** - .NET automation apps
- **Python Scripts** - Custom Python scripts

## Installation Status

✅ **HACS Version:** 2.0.5  
✅ **Location:** `/home/pi/homeassistant/custom_components/hacs/`  
✅ **Status:** Installed, ready for setup  

## Setup Steps

### 1. Access Home Assistant
```
http://192.168.1.159:8123
http://MyP.local:8123
```

### 2. Add HACS Integration

1. Navigate to **Settings** → **Devices & Services**
2. Click the **+ Add Integration** button (bottom right)
3. Search for **"HACS"**
4. Click on **HACS** to start setup

### 3. Acknowledge Requirements

HACS will show you important information:
- ✅ Check all acknowledgment boxes
- ✅ Click **Submit**

### 4. Authenticate with GitHub

You'll need a GitHub account (free):

1. **Go to GitHub:** https://github.com/signup (if you don't have an account)

2. **Device Activation:**
   - HACS will show you a code (e.g., `XXXX-XXXX`)
   - Click the link provided or go to: https://github.com/login/device
   - Enter the code shown in HACS
   - Authorize HACS to access your GitHub account

3. **Complete Setup:**
   - Return to Home Assistant
   - HACS should now show "Authenticated successfully"
   - Click **Finish**

### 5. Verify Installation

Go to **Settings** → **Devices & Services** → **HACS**

You should see:
- **Integrations** tab
- **Frontend** tab
- **Automation** tab
- **Themes** tab

## Using HACS

### Browse and Install Integrations

1. **Open HACS:**
   - Settings → Devices & Services → HACS

2. **Browse Categories:**
   - Click **Integrations**, **Frontend**, **Themes**, etc.

3. **Install Something:**
   - Click on an integration/theme
   - Click **Download**
   - Choose version (usually latest)
   - Click **Download** again
   - Restart Home Assistant: `ha restart`

### Popular Integrations to Try

**Integrations:**
- **Browser Mod** - Advanced browser control
- **Xiaomi Cloud Map Extractor** - Vacuum maps
- **Adaptive Lighting** - Smart lighting
- **Auto Entities** - Dynamic Lovelace cards

**Frontend:**
- **Mushroom Cards** - Beautiful Lovelace cards
- **Mini Graph Card** - Compact graphs
- **Button Card** - Customizable buttons
- **Card Mod** - Style any card

**Themes:**
- **Minimalist** - Clean minimal theme
- **iOS Dark Mode** - iOS-style dark theme
- **Google Home** - Google-inspired theme

### Install via Command Line (Advanced)

HACS can also be managed via configuration files:

```yaml
# configuration.yaml
hacs:
  token: !secret github_token
  sidepanel_title: Community
  sidepanel_icon: mdi:alpha-c-box
  appdaemon: true
  python_script: true
```

## Common Tasks

### Update HACS

HACS will notify you when updates are available:

1. Settings → Devices & Services → HACS
2. Click the update notification
3. Click **Download**
4. Restart: `ha restart`

### Update Installed Integrations

1. Open HACS
2. Look for the update badge (number)
3. Click on the integration with update available
4. Click **Update** or **Redownload**
5. Restart Home Assistant

### Remove an Integration

1. Open HACS
2. Find the integration
3. Click the three dots (**⋮**)
4. Click **Remove**
5. Restart Home Assistant

### Backup Before Changes

Always backup before installing new integrations:

```bash
ha backup "before-hacs-install"
# Install integration via HACS
ha restart
# If something breaks:
ha restore "before-hacs-install"
```

## Troubleshooting

### HACS Not Showing in Integrations

**Solution:**
```bash
# Verify HACS is installed
ls -la /home/pi/homeassistant/custom_components/hacs/

# Restart Home Assistant
ha restart

# Clear browser cache
# Ctrl+Shift+R (or Cmd+Shift+R on Mac)
```

### GitHub Authentication Failed

**Solutions:**
1. Make sure you have a GitHub account
2. Try the device activation flow again
3. Check your GitHub doesn't have 2FA issues
4. Use a personal access token instead (advanced)

### Integration Not Loading After Install

**Solution:**
```bash
# Check logs for errors
ha errors

# Validate configuration
ha validate

# Restart HA
ha restart

# Check if integration requires additional configuration
```

### HACS Shows "Rate Limited"

**Cause:** GitHub API rate limits

**Solution:**
- Wait an hour (GitHub resets hourly)
- Or create a GitHub Personal Access Token:
  1. GitHub → Settings → Developer Settings → Personal Access Tokens
  2. Generate new token (classic)
  3. Add to `secrets.yaml`: `github_token: "ghp_xxx..."`
  4. Reference in `configuration.yaml`:
     ```yaml
     hacs:
       token: !secret github_token
     ```

## File Locations

```
/home/pi/homeassistant/
├── custom_components/
│   └── hacs/                    # HACS integration
│
├── www/
│   └── community/               # Frontend plugins installed by HACS
│
└── themes/
    └── [theme-name]/            # Themes installed by HACS
```

## Best Practices

### 1. Always Backup First
```bash
ha backup "before-hacs-changes"
```

### 2. Read Integration Documentation
Before installing, click through to the GitHub repo and read the README.

### 3. Check Compatibility
Make sure integrations support your HA version.

### 4. Start Small
Don't install 50 integrations at once. Add one, test, then add more.

### 5. Monitor Logs
```bash
ha logs-tail 100
ha errors
```

### 6. Update Regularly
Keep HACS and integrations updated for bug fixes and features.

## Reinstalling HACS

If you need to reinstall:

```bash
# Remove HACS
rm -rf /home/pi/homeassistant/custom_components/hacs

# Reinstall
/home/pi/_playground/_scripts/install-hacs.sh

# Restart
ha restart
```

## Resources

- **HACS Documentation:** https://hacs.xyz/docs/
- **HACS Discord:** https://discord.gg/apgchf8
- **GitHub:** https://github.com/hacs/integration
- **Community Forum:** https://community.home-assistant.io/t/hacs-community-store/

## Quick Reference

| Task | Command |
|------|---------|
| Install HACS | `/home/pi/_playground/_scripts/install-hacs.sh` |
| Reinstall HACS | Remove `custom_components/hacs/`, run installer |
| Update HACS | Via HACS UI → Settings → Update |
| Access HACS | Settings → Devices & Services → HACS |
| Backup before changes | `ha backup "name"` |
| Restart after install | `ha restart` |
| Check logs | `ha errors` |

---

**Installed:** $(date +"%Y-%m-%d")  
**Version:** 2.0.5  
**Status:** ✅ Ready for setup  

**Next Step:** Configure HACS via Settings → Devices & Services!

