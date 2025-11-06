# Pi to Home Assistant Reporter Package

Installable systemd service package for reporting Raspberry Pi system status to Home Assistant via MQTT.

## Features

- ✅ **System Monitoring** - Temperature, CPU load, memory usage, disk usage, network status
- ✅ **MQTT Integration** - Publishes data to MQTT broker for Home Assistant
- ✅ **Auto-Discovery** - Automatic Home Assistant MQTT discovery integration
- ✅ **Systemd Service** - Runs as a background daemon with auto-restart
- ✅ **Self-Contained** - Complete installation with virtual environment

## Package Structure

```
pi-to-ha-reporter/
├── data/                              # Package files to be installed
│   ├── pi-to-ha-reporter.py          # Main daemon script
│   └── requirements.txt               # Python dependencies
├── config/                            # Configuration templates
│   └── config.ini.dist                # Configuration template
├── services/                          # Systemd service files
│   └── pi-to-ha-reporter.service     # Main service file
├── install.sh                         # Installation script
├── uninstall.sh                       # Uninstallation script
└── README.md                          # This file
```

## Installation Locations

When installed, the package creates a **self-contained installation**:

```
~/.local/share/pi-to-ha-reporter/     # Package installation
├── pi-to-ha-reporter.py              # Main script
├── .venv/                            # Virtual environment
├── config/                           # Configuration files
│   └── config.ini                    # Active configuration

/etc/systemd/system/                   # Systemd service file
└── pi-to-ha-reporter.service
```

**Key Features:**
- ✅ **Self-contained** - No dependencies on development paths
- ✅ **Standard locations** - Uses `~/.local/share/` for user data
- ✅ **Clean uninstall** - Removes all installed files
- ✅ **Isolated dependencies** - Own virtual environment

## Prerequisites

1. **Python 3** - Python 3.x must be installed
2. **MQTT Broker** - Mosquitto or other MQTT broker (install with `sudo apt-get install mosquitto`)
3. **System packages** - Some packages may be needed:
   ```bash
   sudo apt-get install python3-tzlocal python3-sdnotify python3-colorama \
     python3-unidecode python3-apt python3-paho-mqtt python3-requests net-tools
   ```

## Installation

```bash
cd /home/pi/_playground/_dev/packages/pi-to-ha-reporter
./install.sh
```

The installation script will:
1. Create installation directory at `~/.local/share/pi-to-ha-reporter/`
2. Copy script files and create configuration from template
3. Set up Python virtual environment using `uv` (fast, reliable) and install dependencies with `uv pip install`
4. Install and enable systemd service

**Note:** This package uses `uv` for Python package management (installed globally via `bootstrap-snake-pit.sh`). If `uv` is not available, it falls back to traditional `pip`.

**⚠️ Important:** After installation, edit `~/.local/share/pi-to-ha-reporter/config/config.ini` with your settings:
- `hostname`: MQTT broker hostname/IP (default: localhost)
- `port`: MQTT broker port (default: 1883)
- `base_topic`: MQTT base topic (default: home/nodes)
- `interval_in_seconds`: Polling interval in seconds (default: 60, range: 10-1800)

## Configuration

Edit the configuration file:
```bash
nano ~/.local/share/pi-to-ha-reporter/config/config.ini
```

Minimum required settings:
```ini
[MQTT]
hostname = localhost
port = 1883
base_topic = home/nodes
```

If your MQTT broker requires authentication:
```ini
[MQTT]
username = your_mqtt_username
password = your_mqtt_password
```

### Polling Interval Configuration

The service can be configured to report at different intervals:

**Seconds-based interval (recommended):**
```ini
[Daemon]
# Report every 60 seconds (10-1800 seconds range)
interval_in_seconds = 60
```

**Legacy minutes-based interval (backwards compatible):**
```ini
[Daemon]
# Report every 5 minutes (converts to 300 seconds)
interval_in_minutes = 5
```

**Notes:**
- `interval_in_seconds` takes precedence if both are set
- Range: 10-1800 seconds (10 seconds to 30 minutes)
- Default: 60 seconds (1 minute)
- Lower intervals provide more frequent updates but increase MQTT traffic
- Higher intervals reduce network load but provide less frequent updates

After editing, restart the service:
```bash
sudo systemctl restart pi-to-ha-reporter
```

## Usage

### Service Management

```bash
# Check service status
sudo systemctl status pi-to-ha-reporter

# Start service
sudo systemctl start pi-to-ha-reporter

# Stop service
sudo systemctl stop pi-to-ha-reporter

# Restart service
sudo systemctl restart pi-to-ha-reporter

# View logs
journalctl -u pi-to-ha-reporter -f

# View logs since boot
journalctl -u pi-to-ha-reporter -b
```

### Manual Testing

Test the script manually (without service):
```bash
cd ~/.local/share/pi-to-ha-reporter
.venv/bin/python pi-to-ha-reporter.py --config config -v --stall
```

## MQTT Topics

Data is published to: `{base_topic}/raspberrypi/{hostname}/...`

- `monitor`: Timestamp and full system information (JSON)
- `temperature`: System temperature in °C
- `disk_used`: Root filesystem usage percentage
- `cpu_load`: CPU load percentage (5-minute average)
- `mem_used`: RAM usage percentage

## Home Assistant Integration

If MQTT discovery is enabled in Home Assistant, the Raspberry Pi will automatically appear as a device with sensors for:
- Temperature
- Disk usage
- CPU load
- Memory usage
- Last update timestamp

## Uninstallation

```bash
cd /home/pi/_playground/_dev/packages/pi-to-ha-reporter
./uninstall.sh
```

The uninstallation script will:
1. Stop and disable the systemd service
2. Remove the service file
3. Optionally remove package files from `~/.local/share/pi-to-ha-reporter/`

## Troubleshooting

- **Service fails to start**: Check MQTT broker is running (`systemctl status mosquitto`)
- **No data in Home Assistant**: Verify MQTT broker settings in `config.ini`
- **Temperatures not showing**: Install `libraspberrypi-bin` package (for Ubuntu)
- **Network interfaces missing**: Ensure `net-tools` package is installed

## Original Project

Based on [RPi-Reporter-MQTT2HA-Daemon](https://github.com/ironsheep/RPi-Reporter-MQTT2HA-Daemon) by IronSheep.

This package provides a clean, installable version adapted for the workspace architecture.
