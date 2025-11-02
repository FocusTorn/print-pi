# BME680 Air Quality Monitor

Monitors VOCs (volatile organic compounds) from 3D printing using a BME680 sensor.

## Purpose

Detects when VOC levels are safe enough to open a 3D printer enclosure after printing.

## Hardware

- **Sensor**: BME680 (temperature, humidity, pressure, VOCs/IAQ)
- **Interface**: I2C
- **Wiring**: See [WIRING.md](WIRING.md) for detailed pin connections

**Quick connection:**
- **VIN/3.3V** → Pi Pin 1 (3.3V)
- **GND** → Pi Pin 6 (GND)
- **SDA** → Pi Pin 3 (GPIO 2, I2C SDA)
- **SCL** → Pi Pin 5 (GPIO 3, I2C SCL)
- **SDO** → GND (for I2C address 0x76) or 3.3V (for 0x77)

## Project Structure

```
bme680-monitor/
├── monitor.py          # Adafruit-based simple monitor
├── monitor2/           # Official Bosch BME680 library
│   ├── __init__.py     # Main sensor library
│   ├── constants.py    # Sensor constants
│   └── adds/           # Example scripts
├── WIRING.md           # Hardware wiring guide
└── README.md           # This file
```

## Functionality

1. **Baseline Calibration**: Establish normal room air VOC baseline
2. **Monitoring**: Track VOC levels during printing
3. **Safe Threshold**: Alert when VOCs drop to safe levels (baseline + threshold)
4. **Enclosure Safety**: Indicate when it's safe to open the printer enclosure

## Libraries

### `monitor.py` - Simple Adafruit Monitor
Uses Adafruit CircuitPython library for easy setup:
- Quick start monitoring
- Basic VOC calibration
- Recommended for most users

### `monitor2/` - Official Bosch Library
Official Bosch BME680 implementation with full control:
- Low-level sensor access
- Gas heater temperature control
- Advanced calibration features
- Baseline tracking with change-over-time detection

**Accuracy Comparison:**
- Both libraries use the **same Bosch formulas** and produce identical readings when stable
- The sensor needs **2-4 heating cycles** to stabilize (Bosch library has `heat_stable` flag)
- **Long burn-in (300s) is NOT needed** - just ensure heater is stable before using readings
- Adafruit: Simpler API, automatic heater management, good for basic monitoring
- Bosch: Full control, baseline tracking, air quality scoring, multiple heater profiles

**Recommendation:**
- **For simplicity**: Use Adafruit (`monitor.py`) - just read sensor.gas
- **For advanced VOC monitoring**: Use Bosch (`monitor2`) - better for 3D printer enclosures
  with baseline calibration and air quality scoring

## Setup

From snake-pit root:
```bash
cd /home/pi/_playground/snake-pit
uv pip install adafruit-circuitpython-bme680 adafruit-blinka RPi.GPIO smbus2 colored
```

## Usage

**Simple monitoring (Adafruit):**
```bash
cd /home/pi/_playground/snake-pit
uv run python projects/bme680-monitor/monitor.py --monitor --interval 5
```

**Advanced control (Bosch library):**
```python
import sys
sys.path.insert(0, '/home/pi/_playground/snake-pit/projects/bme680-monitor')
from monitor2 import BME680, I2C_ADDR_SECONDARY

sensor = BME680(I2C_ADDR_SECONDARY)
# Configure for your needs...


```
