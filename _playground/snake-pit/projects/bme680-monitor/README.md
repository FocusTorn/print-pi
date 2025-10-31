# BME680 Air Quality Monitor

Monitors VOCs (volatile organic compounds) from 3D printing using a BME680 sensor.

## Purpose

Detects when VOC levels are safe enough to open a 3D printer enclosure after printing.

## Hardware

- **Sensor**: BME680 (temperature, humidity, pressure, VOCs/IAQ)
- **Interface**: I2C or SPI
- **Raspberry Pi**: I2C pins (GPIO 2/3 for I2C)

## Functionality

1. **Baseline Calibration**: Establish normal room air VOC baseline
2. **Monitoring**: Track VOC levels during printing
3. **Safe Threshold**: Alert when VOCs drop to safe levels (baseline + threshold)
4. **Enclosure Safety**: Indicate when it's safe to open the printer enclosure

## Setup

From snake-pit root:
```bash
cd /home/pi/_playground/snake-pit
uv pip install adafruit-circuitpython-bme680
```

Or if using GPIO/I2C:
```bash
uv pip install adafruit-circuitpython-bme680 adafruit-blinka
```

## Usage

```bash
cd /home/pi/_playground/snake-pit
uv run python projects/bme680-monitor/monitor.py
```

