#!/usr/bin/env bash
# Bootstrap Home Assistant installation via Docker
# Installs Docker and sets up Home Assistant container

set -e

echo "🏠 Bootstrapping Home Assistant installation..."

# Check if Docker is already installed
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo "✅ Docker is already installed:"
    echo "   $DOCKER_VERSION"
    
    # Check if Home Assistant container already exists
    if docker ps -a --format '{{.Names}}' | grep -q '^homeassistant$'; then
        echo "⚠️  Home Assistant container already exists"
        read -p "Remove and recreate? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "🗑️  Stopping and removing existing container..."
            docker stop homeassistant 2>/dev/null || true
            docker rm homeassistant 2>/dev/null || true
        else
            echo "❌ Installation cancelled"
            exit 0
        fi
    fi
else
    echo "📦 Docker not found, installing..."
    
    # Create downloads directory if it doesn't exist
    mkdir -p /home/pi/Downloads/curls
    
    # Download Docker installation script
    echo "📥 Downloading Docker installer..."
    curl -o /home/pi/Downloads/curls/get-docker.sh https://get.docker.com
    
    # Run installer
    echo "⚙️  Installing Docker (this may take a few minutes)..."
    sudo bash /home/pi/Downloads/curls/get-docker.sh
    
    # Add pi user to docker group
    echo "👤 Adding user 'pi' to docker group..."
    sudo usermod -aG docker pi
    
    echo ""
    echo "⚠️  IMPORTANT: You need to log out and back in for docker group to take effect!"
    echo "   Run one of these commands:"
    echo "   • exec su - pi     (refresh without disconnecting)"
    echo "   • exit             (then reconnect via SSH)"
    echo ""
    read -p "Continue with Home Assistant setup now? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "❌ Setup paused. Run this script again after refreshing your session."
        exit 0
    fi
    
    # Try to activate docker group for current session
    echo "🔄 Attempting to activate docker group..."
    # Note: This won't fully work, but we'll try with sudo for the container creation
fi

# Create Home Assistant config directory
echo "📁 Creating Home Assistant config directory..."
mkdir -p /home/pi/homeassistant

# Detect timezone
TIMEZONE=$(cat /etc/timezone 2>/dev/null || echo "UTC")
echo "🌍 Detected timezone: $TIMEZONE"

# Check if we need sudo for docker (group not active yet)
DOCKER_CMD="docker"
if ! docker ps &> /dev/null; then
    echo "⚠️  Docker group not active, using sudo for container creation"
    DOCKER_CMD="sudo docker"
fi

# Pull Home Assistant image
echo "📥 Pulling Home Assistant Docker image (this may take several minutes)..."
$DOCKER_CMD pull ghcr.io/home-assistant/home-assistant:stable

# Run Home Assistant container
echo "🚀 Starting Home Assistant container..."
$DOCKER_CMD run -d \
  --name homeassistant \
  --privileged \
  --restart=unless-stopped \
  --cap-add=NET_ADMIN \
  --cap-add=NET_RAW \
  -e TZ="$TIMEZONE" \
  -v /home/pi/homeassistant:/config \
  -v /run/dbus:/run/dbus:ro \
  --network=host \
  ghcr.io/home-assistant/home-assistant:stable

# Wait for container to start
echo "⏱️  Waiting for Home Assistant to initialize..."
sleep 5

# Verify container is running
if ! $DOCKER_CMD ps --filter "name=homeassistant" --format '{{.Status}}' | grep -q "Up"; then
    echo "❌ Container failed to start. Check logs with:"
    echo "   docker logs homeassistant"
    exit 1
fi

echo "✅ Container is running!"
echo ""

# Wait for HA to create initial files
echo "⏱️  Waiting for Home Assistant to create initial configuration (30 seconds)..."
sleep 30

# Setup proper directory structure
echo "📁 Setting up directory structure..."
mkdir -p /home/pi/homeassistant/{themes,packages,integrations,customize,www,_docs,.vscode}

# Fix permissions
sudo chown -R pi:pi /home/pi/homeassistant

# Create .gitignore
echo "📝 Creating .gitignore..."
cat > /home/pi/homeassistant/.gitignore << 'GITIGNORE_EOF'
# Home Assistant .gitignore
secrets.yaml
*.db
*.db-shm
*.db-wal
*.log
*.log.*
.storage/
.cloud/
deps/
__pycache__/
*.pyc
tts/
*.tmp
*.bak
*~
.DS_Store
Thumbs.db
*.swp
*.swo
home-assistant.log*
*.uuid
OZW_Log.txt
GITIGNORE_EOF

# Create customize.yaml with examples
echo "📝 Creating customize.yaml..."
cat > /home/pi/homeassistant/customize.yaml << 'CUSTOMIZE_EOF'
# Entity customizations
# Customize entity names, icons, and other attributes
# Examples:

light.living_room:
  friendly_name: "Living Room Light"
  icon: mdi:ceiling-light

switch.office_fan:
  friendly_name: "Office Fan"
  icon: mdi:fan

sensor.outdoor_temperature:
  friendly_name: "Outdoor Temp"
  icon: mdi:thermometer

CUSTOMIZE_EOF

# Create default theme
echo "📝 Creating default theme..."
cat > /home/pi/homeassistant/themes/default.yaml << 'THEME_EOF'
# Default theme for Home Assistant
Default:
  # Primary colors
  primary-color: "#03a9f4"
  accent-color: "#ff9800"
  
  # Background colors
  primary-background-color: "#fafafa"
  secondary-background-color: "#e5e5e5"
  
  # Text colors
  primary-text-color: "#212121"
  secondary-text-color: "#727272"
  disabled-text-color: "#bdbdbd"
  
  # Sidebar colors
  sidebar-background-color: "#ffffff"
  sidebar-text-color: "#212121"
  sidebar-selected-background-color: "#e5e5e5"
  
  # Card colors
  card-background-color: "#ffffff"
  paper-card-background-color: "#ffffff"
  
  # Switch colors
  switch-checked-color: "#03a9f4"
  switch-unchecked-color: "#bdbdbd"
THEME_EOF

# Update configuration.yaml with proper structure
echo "📝 Updating configuration.yaml..."
cat > /home/pi/homeassistant/configuration.yaml << 'CONFIG_EOF'
# Home Assistant Configuration
# https://www.home-assistant.io/docs/configuration/

# Loads default set of integrations. Do not remove.
default_config:

# Customizations
homeassistant:
  customize: !include customize.yaml

# Load frontend themes from the themes folder
frontend:
  themes: !include_dir_merge_named themes

# Text to speech
tts:
  - platform: google_translate

# Includes for organized configuration
automation: !include automations.yaml
script: !include scripts.yaml
scene: !include scenes.yaml
CONFIG_EOF

# Create VS Code settings to prevent X11 symlink loop
echo "📝 Creating VS Code settings..."
cat > /home/pi/homeassistant/.vscode/settings.json << 'VSCODE_EOF'
{
  "files.associations": {
    "*.yaml": "home-assistant",
    "*.yml": "home-assistant"
  },
  "yaml.customTags": [
    "!include scalar",
    "!include_dir_list scalar",
    "!include_dir_named scalar",
    "!include_dir_merge_list scalar",
    "!include_dir_merge_named scalar",
    "!secret scalar",
    "!env_var scalar"
  ],
  "yaml.completion": true,
  "yaml.validate": true,
  "yaml.hover": true,
  "files.watcherExclude": {
    "/bin/**": true,
    "/sbin/**": true,
    "/usr/**": true,
    "/lib/**": true,
    "/boot/**": true,
    "/dev/**": true,
    "/proc/**": true,
    "/sys/**": true,
    "/tmp/**": true,
    "/var/**": true,
    "**/X11/**": true,
    "**/.git/objects/**": true,
    "**/node_modules/**": true,
    "**/deps/**": true,
    "**/tts/**": true,
    "**/*.db": true,
    "**/.storage/**": true
  },
  "search.exclude": {
    "/bin/**": true,
    "/usr/**": true,
    "/sys/**": true,
    "**/deps": true,
    "**/tts": true,
    "**/*.db": true,
    "**/.storage": true,
    "**/X11/**": true
  },
  "homeAssistant.hostUrl": "http://192.168.1.159:8123",
  "files.autoSave": "afterDelay",
  "files.autoSaveDelay": 1000,
  "editor.tabSize": 2
}
VSCODE_EOF

# Create quick reference documentation
echo "📝 Creating documentation..."
cat > /home/pi/homeassistant/_docs/README.md << 'README_EOF'
# Home Assistant Quick Reference

## Access Home Assistant
- Local: http://192.168.1.159:8123
- Hostname: http://MyP.local:8123

## Quick Commands

### Configuration
```bash
ha edit configuration       # Edit main config
ha edit automations         # Edit automations
ha validate                 # Validate config
ha restart                  # Restart HA
```

### Management
```bash
ha status                   # Check status
ha logs                     # View logs
ha errors                   # Show errors only
ha backup "name"            # Create backup
ha list-backups             # List backups
```

### Reload (No Restart)
```bash
ha reload automations
ha reload scripts
ha reload themes
```

## Directory Structure
```
/home/pi/homeassistant/
├── configuration.yaml       # Main config
├── automations.yaml         # Automations
├── scripts.yaml             # Scripts
├── scenes.yaml              # Scenes
├── secrets.yaml             # Sensitive data
├── customize.yaml           # Entity customizations
├── themes/                  # Frontend themes
├── packages/                # Modular configs
├── www/                     # Static files
└── _docs/                   # Documentation
```

## Configuration Files

### secrets.yaml
Store sensitive information:
```yaml
api_key_openai: "sk-..."
latitude: 40.7128
longitude: -74.0060
```

Reference in config:
```yaml
api_key: !secret api_key_openai
```

### customize.yaml
Customize entities (already has examples).

### themes/
Add theme YAML files here. Already includes default.yaml.

## Best Practices

1. **Always validate before restarting:**
   ```bash
   ha validate && ha restart
   ```

2. **Backup before major changes:**
   ```bash
   ha backup "before-big-change"
   ```

3. **Use secrets for sensitive data:**
   ```yaml
   api_key: !secret my_api_key  # in configuration.yaml
   my_api_key: "actual-key"     # in secrets.yaml
   ```

4. **Check logs after changes:**
   ```bash
   ha logs-tail 50
   ha errors
   ```

## Help
- Full documentation: /home/pi/homeassistant/_docs/
- Official docs: https://www.home-assistant.io/docs/
- Helper script: `ha help`

---
Created: $(date +"%Y-%m-%d")
Platform: Raspberry Pi 4 - Docker
README_EOF

# Create empty files if they don't exist
touch /home/pi/homeassistant/{automations.yaml,scripts.yaml,scenes.yaml,secrets.yaml}

# Fix all permissions
sudo chown -R pi:pi /home/pi/homeassistant

# Setup ha helper script symlink
if [ ! -f /home/pi/.local/bin/ha ]; then
    echo "🔗 Setting up 'ha' command..."
    mkdir -p /home/pi/.local/bin
    ln -sf /home/pi/_playground/home-assistant/ha-helper.sh /home/pi/.local/bin/ha
    echo "✅ 'ha' command available globally"
fi

echo ""
echo "✅ Home Assistant installation complete!"
echo ""
echo "📊 Container Status:"
$DOCKER_CMD ps --filter "name=homeassistant" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo ""
echo "📁 Directory Structure:"
echo "   ✅ Configuration files created"
echo "   ✅ Directory structure established"
echo "   ✅ VS Code settings configured (X11 loop prevented)"
echo "   ✅ Documentation created in _docs/"
echo "   ✅ .gitignore configured"
echo ""
echo "🌐 Access Home Assistant at:"
echo "   • http://192.168.1.159:8123"
echo "   • http://MyP.local:8123"
echo ""
echo "⏱️  HA is still initializing. Wait 1-2 minutes before accessing."
echo ""
echo "🔧 Quick Commands:"
echo "   • ha status          (check status)"
echo "   • ha validate        (validate config)"
echo "   • ha restart         (restart HA)"
echo "   • ha logs            (view logs)"
echo "   • ha help            (show all commands)"
echo ""
echo "📖 Documentation: /home/pi/homeassistant/_docs/README.md"
echo ""

# Offer to install HACS
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🏪 HACS (Home Assistant Community Store)"
echo ""
echo "HACS allows you to discover and download custom integrations,"
echo "themes, and plugins for Home Assistant."
echo ""
read -p "Install HACS now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    /home/pi/_playground/_scripts/bootstraps/bootstrap-hacs.sh
else
    echo ""
    echo "ℹ️  You can install HACS later by running:"
    echo "   /home/pi/_playground/_scripts/bootstraps/bootstrap-hacs.sh"
    echo ""
fi

