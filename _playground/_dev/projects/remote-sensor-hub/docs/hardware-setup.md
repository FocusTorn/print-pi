# Hardware Setup Guide

## Components Required

### Per Sensor Node:
1. **ESP32 or ESP8266** development board
2. **TCA9548A I2C Multiplexer** (1-3 per node depending on sensor count)
3. **I2C Sensors** (BME280, SHT31, etc.)
4. **Power Supply** (3.3V or 5V, depending on components)
5. **Breadboard or PCB** for prototyping
6. **Jumper wires** for connections

## Wiring Diagram

### Basic ESP32 + TCA9548A + Sensors

```
ESP32                    TCA9548A                Sensors
┌──────────┐            ┌──────────┐            ┌──────────┐
│          │            │          │            │          │
│ 3.3V ────┼───────────►│ VCC      │            │          │
│ GND  ────┼───────────►│ GND      │───────────►│ VCC/GND  │
│          │            │          │            │          │
│ GPIO 21  ├───────────►│ SDA      │            │          │
│ (SDA)    │            │          │            │          │
│          │            │          │            │          │
│ GPIO 22  ├───────────►│ SCL      │            │          │
│ (SCL)    │            │          │            │          │
│          │            │          │            │          │
│          │            │ SD0      ├───────────►│ SDA      │
│          │            │ SC0      ├───────────►│ SCL      │
│          │            │          │            │          │
│          │            │ SD1      ├───────────►│ SDA      │
│          │            │ SC1      ├───────────►│ SCL      │
│          │            │ ...      │            │          │
│          │            │ SD7      ├───────────►│ SDA      │
│          │            │ SC7      ├───────────►│ SCL      │
│          │            │          │            │          │
└──────────┘            └──────────┘            └──────────┘
```

### ESP32 Pin Mapping

| Function | ESP32 Pin | Notes |
|----------|-----------|-------|
| I2C SDA  | GPIO 21   | Default I2C data line |
| I2C SCL  | GPIO 22   | Default I2C clock line |
| Power    | 3.3V      | For TCA9548A and sensors |
| Ground   | GND       | Common ground |

### ESP32-C6 Pin Mapping

| Function | ESP32-C6 Pin | Notes |
|----------|--------------|-------|
| I2C SDA  | GPIO 8       | Default I2C data line (I2C0) |
| I2C SCL  | GPIO 9       | Default I2C clock line (I2C0) |
| I2C SDA  | GPIO 10      | Alternative I2C data line (I2C1) |
| I2C SCL  | GPIO 11      | Alternative I2C clock line (I2C1) |
| Power    | 3.3V         | For TCA9548A and sensors |
| Ground   | GND          | Common ground |

**Note:** ESP32-C6 has two I2C controllers, allowing you to connect multiple multiplexers directly if needed.

### TCA9548A Pin Connections

| TCA9548A Pin | Connection | Notes |
|--------------|------------|-------|
| VCC          | 3.3V or 5V | Power supply (check sensor requirements) |
| GND          | GND        | Ground |
| SDA          | ESP SDA    | I2C data line |
| SCL          | ESP SCL    | I2C clock line |
| A0           | GND/VCC    | Address bit 0 (for multiple muxes) |
| A1           | GND/VCC    | Address bit 1 |
| A2           | GND/VCC    | Address bit 2 |
| SD0-SD7      | Sensor SDA | 8 I2C channels |
| SC0-SC7      | Sensor SCL | 8 I2C channels |

### TCA9548A Address Configuration

The TCA9548A has a base address of 0x70. You can set address bits A0, A1, A2 to get addresses 0x70-0x77.

**For single multiplexer:**
- A0 = GND, A1 = GND, A2 = GND → Address 0x70

**For multiple multiplexers:**
- Mux 1: A0=GND, A1=GND, A2=GND → 0x70
- Mux 2: A0=VCC, A1=GND, A2=GND → 0x71
- Mux 3: A0=GND, A1=VCC, A2=GND → 0x72
- etc.

## Power Considerations

### ESP32 Power Requirements
- **Typical:** 80-240mA (WiFi active: 80-260mA)
- **Peak:** Up to 500mA during transmission
- **Recommendation:** 500mA+ power supply

### ESP8266 Power Requirements
- **Typical:** 70-170mA (WiFi active: 80-170mA)
- **Peak:** Up to 250mA during transmission
- **Recommendation:** 300mA+ power supply

### Sensor Power Requirements
- **BME280:** ~3.6µA (sleep), ~338µA (active)
- **SHT31:** ~0.2µA (sleep), ~150µA (active)
- Most I2C sensors: <1mA per sensor

### Total Power Estimate
- ESP32 + TCA9548A + 8 sensors: ~300-400mA typical
- Add 20-30% margin for safety: **500mA+ supply recommended**

## I2C Pull-up Resistors

Most development boards have built-in pull-up resistors on I2C lines. If not:

- **4.7kΩ resistors** recommended
- Connect between SDA/SCL and VCC (3.3V)
- One set per I2C bus (main bus, not per sensor)

## Multiple Multiplexer Setup

For more than 8 sensors, connect multiple TCA9548A multiplexers:

```
ESP32 I2C Bus
    │
    ├──► TCA9548A #1 (Address 0x70)
    │       ├──► Channel 0-7 (8 sensors)
    │
    ├──► TCA9548A #2 (Address 0x71)
    │       ├──► Channel 0-7 (8 sensors)
    │
    └──► TCA9548A #3 (Address 0x72)
            ├──► Channel 0-7 (8 sensors)
```

**Maximum sensors:** 3 muxes × 8 channels = 24 sensors per ESP32

## Wiring Checklist

- [ ] ESP32/ESP8266 connected to power
- [ ] TCA9548A VCC and GND connected
- [ ] I2C SDA/SCL connected between ESP and TCA9548A
- [ ] TCA9548A address pins configured (A0, A1, A2)
- [ ] Sensors connected to TCA9548A channels (SD0-SD7, SC0-SC7)
- [ ] All grounds connected together
- [ ] Power supply adequate for total current draw
- [ ] Pull-up resistors present (if not on board)

## Testing

### 1. I2C Bus Scan
Use the I2C scanner sketch to verify:
- TCA9548A is detected at correct address
- Sensors are detected on each channel
- No address conflicts

### 2. Channel Selection Test
Test switching between TCA9548A channels to verify each sensor can be accessed independently.

### 3. WiFi Connectivity
Verify ESP32/ESP8266 can connect to your WiFi network.

### 4. MQTT Connection
Test MQTT connectivity to your broker.

## Troubleshooting

### TCA9548A Not Detected
- Check I2C wiring (SDA/SCL)
- Verify address configuration (A0, A1, A2)
- Check power connections
- Try different I2C address

### Sensors Not Detected
- Verify sensor connections to correct TCA9548A channel
- Check TCA9548A channel selection in code
- Verify sensor power connections
- Check sensor I2C address

### Communication Errors
- Verify pull-up resistors are present
- Check I2C bus speed (try slower speed)
- Verify power supply is adequate
- Check for loose connections

