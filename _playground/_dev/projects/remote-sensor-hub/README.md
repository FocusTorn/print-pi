# Remote Sensor Hub

## Project Overview

A distributed sensor system that collects data from multiple I2C sensors (potentially with duplicate addresses) and transmits sensor data over WiFi/MQTT to a central Raspberry Pi 4.

**Key Features:**
- Multiple I2C sensors with duplicate address support (via I2C multiplexer)
- WiFi connectivity for remote sensor nodes
- MQTT-based data transmission
- Local sensor deployment with centralized data collection

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Sensor Node (ESP32/ESP32-C6)                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ I2C Mux      │  │ I2C Mux      │  │ I2C Mux      │      │
│  │ (TCA9548A)   │  │ (TCA9548A)   │  │ (TCA9548A)   │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │              │
│    ┌────┴─────┐      ┌────┴─────┐      ┌────┴─────┐        │
│    │ Sensor   │      │ Sensor   │      │ Sensor   │        │
│    │ Group 1  │      │ Group 2  │      │ Group 3  │        │
│    │ (8 ports)│      │ (8 ports)│      │ (8 ports)│        │
│    └──────────┘      └──────────┘      └──────────┘        │
│                                                              │
│  ESP32/ESP32-C6 ──────── WiFi ────────► MQTT Broker        │
└─────────────────────────────────────────────────────────────┘
                                 │
                                 │ MQTT Topics
                                 ▼
┌─────────────────────────────────────────────────────────────┐
│  Raspberry Pi 4 (Central Hub)                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  MQTT Broker (Mosquitto)                             │   │
│  │  └───► Data Collection & Processing                  │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Hardware Requirements

### Sensor Node (ESP32 or ESP32-C6)

**Recommended Options:**

1. **ESP32-C6** (Recommended - Best Performance)
   - WiFi 6 (802.11ax) - Better performance in congested networks
   - Single-core RISC-V processor (160 MHz)
   - Bluetooth 5 (LE) + Thread/Zigbee support
   - Lower power consumption
   - More future-proof
   - Price: ~$5-10

2. **ESP32** (Mature & Stable)
   - Dual-core processor (240 MHz)
   - WiFi 4 (802.11 b/g/n) + Bluetooth 4.2
   - Mature ecosystem, extensive libraries
   - More GPIO pins (34 pins)
   - Best community support
   - Price: ~$5-10

### I2C Multiplexer (TCA9548A)

**Purpose:** Handle multiple I2C sensors with duplicate addresses

**Specifications:**
- 8 I2C channels per multiplexer
- Can cascade multiple multiplexers
- Address: 0x70-0x77 (configurable via jumpers)
- Allows up to 8 sensors with same address on one mux

**Example:** 
- 1x TCA9548A = 8 sensors with duplicate addresses
- 3x TCA9548A = 24 sensors with duplicate addresses

### Sensors

- Any I2C-compatible sensors
- Examples: BME280, SHT31, TMP102, MPU6050, etc.
- Can mix different sensor types

### Power Supply

- ESP32: 3.3V (500mA typical, 1A peak)
- ESP8266: 3.3V (200mA typical, 500mA peak)
- Sensors: 3.3V or 5V (check datasheets)
- I2C Multiplexer: 3.3V or 5V

## Software Requirements

### Sensor Node Firmware
- PlatformIO or Arduino IDE
- ESP32 or ESP32-C6 board support
- Libraries:
  - WiFi library (built-in)
  - MQTT client (PubSubClient or AsyncMQTT)
  - I2C multiplexer library (Adafruit TCA9548A)
  - Sensor-specific libraries

### Raspberry Pi 4 (Central Hub)
- MQTT Broker: Mosquitto
- MQTT Client: Python (paho-mqtt) or Node.js
- Data storage: InfluxDB, SQLite, or JSON files
- Visualization: Grafana, Home Assistant, or custom dashboard

## Project Structure

```
remote-sensor-hub/
├── README.md                          # This file
├── docs/                              # Documentation
│   ├── BOM.md                        # Bill of Materials
│   ├── hardware-selection.md         # ESP32-C6 vs ESP32 comparison
│   ├── hardware-setup.md              # Hardware wiring guide
│   ├── mqtt-topics.md                # MQTT topic structure
│   └── troubleshooting.md            # Common issues
├── firmware/                          # ESP32/ESP32-C6 firmware
│   ├── esp32/                        # ESP32 version
│   │   ├── src/
│   │   ├── platformio.ini
│   │   └── README.md
│   └── esp32-c6/                     # ESP32-C6 version
│       ├── src/
│       ├── platformio.ini
│       └── README.md
├── raspberry-pi/                     # Pi-side software
│   ├── mqtt-broker/                  # Mosquitto setup
│   ├── data-collector/               # MQTT subscriber
│   ├── database/                     # Data storage
│   └── visualization/                # Dashboards
├── config/                           # Configuration files
│   ├── wifi-config.example.h        # WiFi credentials template
│   ├── mqtt-config.example.h        # MQTT broker config
│   └── sensor-config.example.json   # Sensor mapping
└── tests/                            # Test scripts
    ├── i2c-scan/                    # I2C bus scanner
    └── mqtt-test/                   # MQTT connectivity test
```

## Quick Start

### 0. Bill of Materials
See `docs/BOM.md` for complete parts list, part numbers, and sourcing information.

### 1. Hardware Setup
See `docs/hardware-setup.md` for wiring diagrams and connections.

### 2. Configure WiFi and MQTT
Copy `config/wifi-config.example.h` and `config/mqtt-config.example.h` to your firmware directory and fill in your credentials.

### 3. Flash Firmware
Use PlatformIO or Arduino IDE to flash the firmware to your ESP32 or ESP32-C6.

### 4. Set Up MQTT Broker
Install and configure Mosquitto on your Raspberry Pi 4.

### 5. Run Data Collector
Start the MQTT subscriber on your Raspberry Pi to collect sensor data.

## MQTT Topic Structure

```
sensor-hub/{node-id}/{mux-channel}/{sensor-type}/{sensor-id}/data
sensor-hub/{node-id}/{mux-channel}/{sensor-type}/{sensor-id}/status
sensor-hub/{node-id}/system/status
```

**Example:**
```
sensor-hub/kitchen-node/0/bme280/0/data
sensor-hub/kitchen-node/0/bme280/0/temperature
sensor-hub/kitchen-node/0/bme280/0/humidity
sensor-hub/kitchen-node/0/bme280/0/pressure
```

## Development Status

- [ ] Hardware selection and procurement
- [ ] Firmware development (ESP32)
- [ ] Firmware development (ESP32-C6)
- [ ] I2C multiplexer integration
- [ ] MQTT broker setup
- [ ] Data collection service
- [ ] Database schema
- [ ] Visualization dashboard
- [ ] Documentation
- [ ] Testing

## Resources

- [ESP32 Datasheet](https://www.espressif.com/sites/default/files/documentation/esp32_datasheet_en.pdf)
- [ESP32-C6 Datasheet](https://www.espressif.com/sites/default/files/documentation/esp32-c6_datasheet_en.pdf)
- [TCA9548A Datasheet](https://www.ti.com/lit/ds/symlink/tca9548a.pdf)
- [MQTT Protocol Specification](https://mqtt.org/mqtt-specification/)
- [Mosquitto MQTT Broker](https://mosquitto.org/)
- [ESP32 Arduino Core](https://github.com/espressif/arduino-esp32)
- [ESP32-C6 Arduino Core](https://github.com/espressif/arduino-esp32)

## License

[Add your license here]

## Author

[Your name/contact info]

