# ESP32-C6 Firmware

## Overview

Firmware for the ESP32-C6 sensor node that reads data from multiple I2C sensors (via TCA9548A multiplexer) and transmits sensor data over WiFi/MQTT to a central Raspberry Pi 4.

## Features

- WiFi 6 (802.11ax) connectivity
- MQTT client for data transmission
- I2C multiplexer support (TCA9548A)
- Multiple sensor support (BME280, SHT31, etc.)
- OTA (Over-The-Air) updates support
- Low power modes
- Configurable via WiFi/MQTT

## Hardware Requirements

- ESP32-C6 development board
- TCA9548A I2C multiplexer(s)
- I2C sensors (BME280, SHT31, etc.)
- 3.3V or 5V power supply

## Pin Configuration

### Default I2C Pins (ESP32-C6)

- **SDA:** GPIO 8 (I2C0)
- **SCL:** GPIO 9 (I2C0)

### Alternative I2C Pins

- **SDA:** GPIO 10 (I2C1)
- **SCL:** GPIO 11 (I2C1)

## Setup

### 1. Install PlatformIO

```bash
# Install PlatformIO
pip install platformio

# Or use the installer
python -m pip install platformio
```

### 2. Clone and Configure

```bash
# Copy configuration files
cp ../../config/wifi-config.example.h include/wifi-config.h
cp ../../config/mqtt-config.example.h include/mqtt-config.h

# Edit configuration files with your WiFi and MQTT credentials
nano include/wifi-config.h
nano include/mqtt-config.h
```

### 3. Build and Upload

```bash
# Build firmware
pio run

# Upload to ESP32-C6
pio run -t upload

# Monitor serial output
pio device monitor
```

## Configuration

### WiFi Configuration

Edit `include/wifi-config.h`:

```cpp
#define WIFI_SSID "your-wifi-ssid"
#define WIFI_PASSWORD "your-wifi-password"
```

### MQTT Configuration

Edit `include/mqtt-config.h`:

```cpp
#define MQTT_BROKER_HOST "192.168.1.100"
#define MQTT_BROKER_PORT 1883
#define MQTT_CLIENT_ID "kitchen-node"
```

### Sensor Configuration

Edit `include/sensor-config.h` to configure your sensors and multiplexers.

## Project Structure

```
esp32-c6/
├── src/
│   ├── main.cpp              # Main firmware code
│   ├── wifi_manager.cpp      # WiFi connection management
│   ├── mqtt_client.cpp       # MQTT client implementation
│   ├── i2c_multiplexer.cpp   # TCA9548A multiplexer control
│   └── sensors/              # Sensor drivers
│       ├── bme280.cpp
│       └── sht31.cpp
├── include/
│   ├── wifi-config.h         # WiFi credentials (gitignored)
│   ├── mqtt-config.h         # MQTT configuration (gitignored)
│   └── sensor-config.h       # Sensor configuration
├── platformio.ini            # PlatformIO configuration
└── README.md                 # This file
```

## Libraries

Required libraries (automatically installed via PlatformIO):

- WiFi (built-in)
- ArduinoJson (for MQTT messages)
- PubSubClient or AsyncMQTT (MQTT client)
- Adafruit TCA9548A (I2C multiplexer)
- Sensor-specific libraries (Adafruit BME280, Adafruit SHT31, etc.)

## Development

### Serial Monitor

```bash
# Monitor at 115200 baud
pio device monitor -b 115200
```

### OTA Updates

Once connected to WiFi, you can update firmware over-the-air:

```bash
# Build and upload via OTA
pio run -t upload --upload-port <ESP32-C6-IP>
```

## Troubleshooting

### WiFi Connection Issues

- Check WiFi credentials in `wifi-config.h`
- Verify ESP32-C6 is within WiFi range
- Check if your router supports WiFi 6 (802.11ax)
- ESP32-C6 is backward compatible with WiFi 4/5 routers

### MQTT Connection Issues

- Verify MQTT broker IP and port
- Check firewall settings
- Verify MQTT broker is running on Raspberry Pi
- Check MQTT credentials if authentication is enabled

### I2C Issues

- Verify I2C wiring (SDA/SCL)
- Check TCA9548A address configuration
- Verify sensor connections
- Check pull-up resistors (usually on development board)

## Resources

- [ESP32-C6 Datasheet](https://www.espressif.com/sites/default/files/documentation/esp32-c6_datasheet_en.pdf)
- [ESP32 Arduino Core](https://github.com/espressif/arduino-esp32)
- [PlatformIO ESP32](https://docs.platformio.org/en/latest/platforms/espressif32.html)

