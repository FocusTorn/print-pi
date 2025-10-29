# Home Assistant Configuration Structure

Your Home Assistant installation is properly configured with an organized directory structure.

## Directory Structure

```
/home/pi/homeassistant/
├── configuration.yaml       # Main configuration file
├── automations.yaml         # All automations (managed via UI or manually)
├── scripts.yaml             # Reusable scripts
├── scenes.yaml              # Scenes
├── secrets.yaml             # Sensitive data (passwords, API keys)
├── customize.yaml           # Entity customizations (names, icons)
│
├── themes/                  # Frontend themes
│   └── default.yaml         # Example theme
│
├── packages/                # Modular configuration packages (optional)
├── blueprints/              # Automation blueprints
├── integrations/            # Custom integration configs (if needed)
├── customize/               # Split customizations (if needed)
├── www/                     # Static files (images, custom cards)
│
├── .storage/                # HA internal storage (DO NOT EDIT)
├── .cloud/                  # Nabu Casa cloud storage (DO NOT EDIT)
├── deps/                    # Python dependencies (DO NOT EDIT)
├── tts/                     # Text-to-speech cache (DO NOT EDIT)
│
├── .vscode/                 # VS Code/Cursor settings
└── _docs/                   # Documentation (this folder)
```

## Core Files

### `configuration.yaml`
Main configuration file. Contains:
- System settings
- Includes for other config files
- Integration configurations
- Global settings

**Current includes:**
```yaml
homeassistant:
  customize: !include customize.yaml

frontend:
  themes: !include_dir_merge_named themes

automation: !include automations.yaml
script: !include scripts.yaml
scene: !include scenes.yaml
```

### `secrets.yaml`
Store sensitive information:
```yaml
# Example:
http_password: "mySecurePassword123"
latitude: 40.7128
longitude: -74.0060
api_key_openai: "sk-..."
```

Reference in configuration:
```yaml
api_key: !secret api_key_openai
```

### `automations.yaml`
All automations (UI-managed or manual):
```yaml
- id: '1234567890'
  alias: "Turn on lights at sunset"
  trigger:
    - platform: sun
      event: sunset
  action:
    - service: light.turn_on
      target:
        entity_id: light.living_room
```

### `scripts.yaml`
Reusable scripts:
```yaml
good_night:
  alias: "Good Night"
  sequence:
    - service: light.turn_off
      target:
        entity_id: all
    - service: lock.lock
      target:
        entity_id: lock.front_door
```

### `scenes.yaml`
Scenes for specific moods/situations:
```yaml
- id: movie_time
  name: "Movie Time"
  entities:
    light.living_room:
      state: on
      brightness: 25
    media_player.tv:
      state: on
```

### `customize.yaml`
Customize entity appearance and behavior:
```yaml
sensor.temperature:
  friendly_name: "Living Room Temp"
  icon: mdi:thermometer
  unit_of_measurement: "°F"
```

## Special Directories

### `themes/`
Frontend theme files (one per file).

**Usage:**
- Create theme files: `themes/dark_mode.yaml`, `themes/light_mode.yaml`
- Apply via UI: Settings → Frontend → Themes

**Current themes:**
- `default.yaml` - Example theme

### `packages/` (Optional)
Group related configurations together.

**Example: `packages/lighting.yaml`**
```yaml
# All lighting-related config in one file
light:
  - platform: mqtt
    name: "Living Room"

automation:
  - alias: "Lights on at sunset"
    trigger:
      platform: sun
      event: sunset
    action:
      service: light.turn_on

script:
  all_lights_off:
    sequence:
      - service: light.turn_off
        target:
          entity_id: all
```

Enable in `configuration.yaml`:
```yaml
homeassistant:
  packages: !include_dir_named packages
```

### `www/`
Static files accessible at `/local/`

**Usage:**
- Images: `/local/images/photo.jpg`
- Custom cards: `/local/custom-cards/`
- Icons: `/local/icons/`

**Access in Lovelace:**
```yaml
type: picture
image: /local/images/background.jpg
```

### `blueprints/`
Automation blueprints (templates).

**Structure:**
```
blueprints/
├── automation/
│   └── motion_light.yaml
└── script/
    └── notification.yaml
```

## Configuration Validation

### Using the `ha` Command
```bash
# Validate configuration before restart
ha validate

# If valid, restart
ha restart

# Check logs
ha logs-tail 50

# Check for errors
ha errors
```

### Via Web UI
Settings → System → Check Configuration

## Best Practices

### 1. Use `secrets.yaml` for Sensitive Data
❌ **Don't:**
```yaml
api_key: "sk-1234567890abcdef"
```

✅ **Do:**
```yaml
# configuration.yaml
api_key: !secret openai_api

# secrets.yaml
openai_api: "sk-1234567890abcdef"
```

### 2. Split Large Configurations
Instead of one huge `configuration.yaml`, use:
- Separate files (`automations.yaml`, `scripts.yaml`)
- Packages (`packages/lighting.yaml`, `packages/climate.yaml`)
- Directory includes (`!include_dir_merge_named`)

### 3. Comment Your Config
```yaml
# Motion sensor automation for hallway
# Turns on lights when motion detected after sunset
- alias: "Hallway Motion Light"
  trigger:
    - platform: state
      entity_id: binary_sensor.hallway_motion
      to: "on"
```

### 4. Use Version Control
```bash
cd /home/pi/homeassistant
git init
git add configuration.yaml automations.yaml scripts.yaml
git commit -m "Initial config"
```

**Note:** Add to `.gitignore`:
```
secrets.yaml
*.db
*.db-shm
*.db-wal
.storage/
.cloud/
deps/
tts/
*.log
```

### 5. Backup Before Major Changes
```bash
ha backup "before-adding-solar-integration"
# Make changes
ha validate
ha restart
```

### 6. Test in Dev Mode (Optional)
Add to `configuration.yaml`:
```yaml
logger:
  default: info
  logs:
    homeassistant.components: debug
```

## Common Include Directives

### `!include`
Include a single file:
```yaml
automation: !include automations.yaml
```

### `!include_dir_list`
Include all files in directory as list items:
```yaml
# Each file becomes a list item
automation: !include_dir_list automations/
```

### `!include_dir_named`
Include files as named dictionary:
```yaml
# Filename becomes the key
packages: !include_dir_named packages/
```

### `!include_dir_merge_named`
Merge all files in directory:
```yaml
# All theme files merged together
frontend:
  themes: !include_dir_merge_named themes/
```

### `!include_dir_merge_list`
Merge all lists from directory:
```yaml
# Merge all automation lists
automation: !include_dir_merge_list automations/
```

### `!secret`
Reference value from secrets.yaml:
```yaml
api_key: !secret my_api_key
```

## Troubleshooting

### Configuration Validation Fails
```bash
# Check the specific error
ha validate

# View full logs
ha logs-tail 200

# Common issues:
# - YAML syntax errors (indentation)
# - Missing required fields
# - Invalid entity IDs
# - Incorrect include paths
```

### Changes Not Applied
```bash
# Some changes need restart
ha restart

# Some can be reloaded
ha reload automations
ha reload scripts
ha reload scenes
```

### File Not Found Errors
```bash
# Check file exists
ls -la /home/pi/homeassistant/themes/

# Check YAML syntax
ha validate
```

## Useful Commands

```bash
# Validate configuration
ha validate

# Restart Home Assistant
ha restart

# Reload specific components
ha reload automations
ha reload scripts
ha reload themes

# View logs
ha logs
ha logs-tail 100
ha errors

# Edit files
ha edit configuration
ha edit automations
ha edit secrets

# Backup/Restore
ha backup "backup-name"
ha list-backups
ha restore "backup-name"

# Status
ha status
ha info
```

## Resources

- **Official Docs:** https://www.home-assistant.io/docs/
- **Configuration Reference:** https://www.home-assistant.io/docs/configuration/
- **YAML Syntax:** https://www.home-assistant.io/docs/configuration/yaml/
- **Packages:** https://www.home-assistant.io/docs/configuration/packages/
- **Secrets:** https://www.home-assistant.io/docs/configuration/secrets/

---

**Last Updated:** October 28, 2025  
**HA Version:** Latest stable via Docker  
**Location:** `/home/pi/homeassistant/`

