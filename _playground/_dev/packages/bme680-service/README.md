# BME680 Service Package

Installable systemd service package for BME680 sensor monitoring with automatic sensor detection and service management.

## Features

- ✅ **Automatic sensor detection** - Checks I2C bus for BME680 before installation
- ✅ **Systemd service management** - Professional service installation/uninstallation
- ✅ **Auto-start on boot** - Services start automatically after system reboot
- ✅ **Auto-restart on failure** - Services automatically restart if they crash
- ✅ **No code modifications** - Works with existing snake-pit monitor scripts
- ✅ **Multiple monitors** - Supports both IAQ and temperature monitoring

## Package Structure

```
bme680-service/
├── data/                         # Package files to be installed
│   ├── monitor/                  # BME680 library code
│   ├── monitor-iaq.py            # IAQ monitor script
│   ├── monitor-temperature.py    # Temperature monitor script
│   └── requirements.txt          # Python dependencies
├── detectors/
│   └── detect-bme680.sh         # Sensor detection script
├── services/
│   ├── bme680-iaq.service        # IAQ monitor systemd service
│   └── bme680-temperature.service # Temperature monitor systemd service
├── install.sh                    # Installation script (root)
├── uninstall.sh                   # Uninstallation script (root)
└── README.md                      # This file
```

## Installation Locations

When installed, the package creates a **self-contained installation**:

```
~/.local/share/bme680-service/    # Package installation
├── monitor/                      # BME680 library
├── monitor-iaq.py                # IAQ monitor script
├── monitor-temperature.py        # Temperature monitor script
├── .venv/                        # Virtual environment with dependencies
└── config/                       # Configuration files (if needed)

/etc/systemd/system/               # Systemd service files
├── bme680-iaq.service
└── bme680-temperature.service
```

**Key Features:**
- ✅ **Self-contained** - No dependencies on development paths
- ✅ **Standard locations** - Uses `~/.local/share/` and `~/.local/bin/`
- ✅ **Clean uninstall** - Removes all installed files
- ✅ **Isolated dependencies** - Own virtual environment

## Prerequisites

1. **Python 3** - Python 3.x must be installed (usually pre-installed on Raspberry Pi)

2. **I2C enabled** - Enable I2C on Raspberry Pi:
   ```bash
   sudo raspi-config  # Interface Options → I2C → Enable
   ```

3. **BME680 sensor** - Hardware must be connected and working

4. **MQTT broker** - Recommended (mosquitto or other MQTT service)

**Note:** This package is **self-contained** and does NOT require snake-pit or any other development environment. All dependencies are installed automatically.

## Installation

### Option 1: Bootstrap Script (Recommended)

```bash
/home/pi/_playground/_scripts/bootstraps/bootstrap-bme680.sh
```

### Option 2: Direct Installation

```bash
cd /home/pi/_playground/_dev/packages/bme680-service
./install.sh
```

**Note:** The installer will automatically prompt for sudo privileges when needed. No need to prefix with `sudo`.

The installer will:
1. **Detect BME680 sensor** - Checks both I2C addresses (0x76, 0x77) and verifies chip ID
2. **Install package files** - Copies scripts and library to `~/.local/share/bme680-service/`
3. **Create virtual environment** - Sets up isolated Python environment
4. **Install dependencies** - Installs Python packages (smbus2, paho-mqtt, etc.)
5. **Install systemd services** - Copies service files to `/etc/systemd/system/`
6. **Enable services** - Enables services to start on boot
7. **Start services** - Starts the monitoring services immediately

## CLI Tool

The package includes a unified CLI tool (`bme680-cli`) for easy interaction:

```bash
# View all current sensor readings
bme680-cli read

# View specific sensor values
bme680-cli read --temperature
bme680-cli read --humidity
bme680-cli read --pressure
bme680-cli read --gas
bme680-cli read --iaq

# View as JSON
bme680-cli read --json
bme680-cli read --humidity --json

# Check service status
bme680-cli status

# View service logs
bme680-cli logs bme680-iaq

# Follow logs live
bme680-cli logs bme680-iaq --follow

# Calibrate baseline (do this once)
bme680-cli calibrate

# Monitor continuously (console output)
bme680-cli monitor --iaq --interval 10
```

**Note:** The CLI tool is automatically installed to `~/.local/bin/bme680-cli` during package installation.

## Usage

### Check Service Status

```bash
# IAQ Monitor
systemctl status bme680-iaq

# Temperature Monitor
systemctl status bme680-temperature
```

### View Logs

```bash
# Follow IAQ logs
journalctl -u bme680-iaq -f

# Follow temperature logs
journalctl -u bme680-temperature -f

# View recent logs (last 50 lines)
journalctl -u bme680-iaq -n 50
```

### Manual Service Control

```bash
# Start service
sudo systemctl start bme680-iaq

# Stop service
sudo systemctl stop bme680-iaq

# Restart service
sudo systemctl restart bme680-iaq

# Disable auto-start (but don't stop now)
sudo systemctl disable bme680-iaq

# Enable auto-start
sudo systemctl enable bme680-iaq
```

## Uninstallation

```bash
cd /home/pi/_playground/_dev/packages/bme680-service
./uninstall.sh
```

**Note:** The uninstaller will automatically prompt for sudo privileges when needed.

The uninstaller will:
1. Stop and disable systemd services
2. Remove service files from `/etc/systemd/system/`
3. Optionally remove package files from `~/.local/share/bme680-service/`
4. Optionally remove wrapper scripts from `~/.local/bin/`
5. Reload systemd daemon

**Manual removal** (if needed):
```bash
# Stop and disable services
sudo systemctl stop bme680-iaq bme680-temperature
sudo systemctl disable bme680-iaq bme680-temperature
sudo rm /etc/systemd/system/bme680-*.service
sudo systemctl daemon-reload

# Remove package files
rm -rf ~/.local/share/bme680-service
```

## Service Configuration

### IAQ Monitor Service

- **Service name**: `bme680-iaq.service`
- **Script**: `monitor-iaq.py`
- **MQTT topic**: `homeassistant/sensor/bme680/state`
- **Auto-restart**: Yes (10 second delay)
- **User**: `pi`

### Temperature Monitor Service

- **Service name**: `bme680-temperature.service`
- **Script**: `monitor-temperature.py`
- **MQTT topic**: `homeassistant/sensor/bme680_chamber/state`
- **Auto-restart**: Yes (10 second delay)
- **User**: `pi`

## Sensor Detection

The installer automatically detects BME680 sensors with **smart verification**:

1. **Checks BOTH addresses** - Always checks both 0x76 and 0x77
2. **Verifies chip ID** - Confirms chip ID is 0x61 (BME680 specific), not just any sensor
3. **Safe detection** - Won't confuse other I2C devices with BME680

**I2C Addresses:**
- **0x76** (primary address, SDO → GND)
- **0x77** (secondary address, SDO → 3.3V)

**Chip ID Verification:**
- Reads register `0xD0` (chip ID register)
- Must return `0x61` to confirm it's a BME680
- Prevents false positives from other sensors/devices

If no sensor is detected, the installer will show detailed diagnostics about what devices (if any) are present at each address, and you can still proceed with installation for testing purposes.

## Troubleshooting

### Service Won't Start

1. **Check sensor is detected:**
   ```bash
   i2cdetect -y 1
   # Should show 0x76 or 0x77
   ```

2. **Check logs:**
   ```bash
   journalctl -u bme680-iaq -n 50 --no-pager
   ```

3. **Check installation:**
   ```bash
   # Verify package is installed
   test -d ~/.local/share/bme680-service && echo "OK" || echo "Not installed"
   
   # Verify virtual environment exists
   test -f ~/.local/share/bme680-service/.venv/bin/python && echo "OK" || echo "Missing"
   
   # Test Python environment
   ~/.local/share/bme680-service/.venv/bin/python --version
   ```

### Sensor Not Detected

1. **Enable I2C:**
   ```bash
   sudo raspi-config  # Interface Options → I2C
   ```

2. **Check wiring** - See `/home/pi/_playground/snake-pit/projects/bme680-monitor/WIRING.md`

3. **Verify sensor power** - Check 3.3V connection

### MQTT Not Publishing

1. **Check MQTT broker is running:**
   ```bash
   systemctl status mosquitto
   # or
   systemctl status mqtt
   ```

2. **Test MQTT connection:**
   ```bash
   # Monitor MQTT topic manually
   mosquitto_sub -h localhost -t "homeassistant/sensor/bme680/state" -v
   ```

3. **Check service logs for MQTT errors**

## Integration with Home Assistant

Once services are running and publishing to MQTT, configure Home Assistant sensors:

```yaml
# Already configured in:
# /home/pi/_playground/home-assistant/sensors-bme680-sensor.yaml
# /home/pi/_playground/home-assistant/sensors-bme680-binary.yaml
```

Restart Home Assistant to load the new sensors:
```bash
ha restart
```

## Notes

- Services run as user `pi` (not root) for security
- Services automatically restart on failure (10 second delay)
- Logs are available via `journalctl`
- Services start after network and MQTT are available
- Works with both venv and uv run environments

