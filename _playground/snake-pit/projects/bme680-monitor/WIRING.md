# BME680 Sensor Wiring Guide

## Raspberry Pi 4 I2C Pinout

### Physical GPIO Pins (40-pin header)

```
      3.3V  [1]  [2]  5V
     GPIO2  [3]  [4]  5V
     GPIO3  [5]  [6]  GND
     GPIO4  [7]  [8]  GPIO14
       GND  [9]  [10] GPIO15
   GPIO17  [11] [12] GPIO18
   GPIO27  [13] [14] GND
   GPIO22  [15] [16] GPIO23
      3.3V [17] [18] GPIO24
   GPIO10  [19] [20] GND
    GPIO9  [21] [22] GPIO25
   GPIO11  [23] [24] GPIO8
       GND [25] [26] GPIO7
    GPIO0  [27] [28] GPIO1
    GPIO5  [29] [30] GND
    GPIO6  [31] [32] GPIO12
   GPIO13  [33] [34] GND
   GPIO19  [35] [36] GPIO16
   GPIO26  [37] [38] GPIO20
       GND [39] [40] GPIO21
```

## BME680 Wiring

### Power Connection

| BME680 Pin | Raspberry Pi | Notes |
|------------|--------------|-------|
| **VIN** or **3.3V** | Pin 1 or 17 (3.3V) | Power supply |
| **GND** | Pin 6, 9, 14, 20, 25, 30, 34, 39 (GND) | Ground |

### I2C Connection

| BME680 Pin | Raspberry Pi | Notes |
|------------|--------------|-------|
| **SDA** | Pin 3 (GPIO 2, I2C SDA) | Data line |
| **SCL** | Pin 5 (GPIO 3, I2C SCL) | Clock line |

### Optional Pins

| BME680 Pin | Raspberry Pi | Notes |
|------------|--------------|-------|
| **CS** | Not connected | For I2C (only used for SPI) |
| **SDI** | Not connected | For I2C (only used for SPI) |
| **SDO** | Can change I2C address | See "I2C Address" below |

## I2C Address

The BME680 has a configurable I2C address:

- **Default I2C address: 0x76** (when SDO connected to GND)
- **Alternative I2C address: 0x77** (when SDO connected to VIN/3.3V)

**Important:** Make sure your code uses the correct address.
- `monitor.py` defaults to **0x77**
- `monitor2` library supports both (use `I2C_ADDR_PRIMARY` or `I2C_ADDR_SECONDARY`)

## Complete Wiring Diagram



```
BME680 Sensor Board
┌─────────────────┐
│                 │
│   VIN ←─────────┼──→ 3.3V (Pin 1) `Orange`
│                 │
│   GND ←─────────┼──→ GND (Pin 6) `Brown`
│                 │
│   SCL ←─────────┼──→ GPIO 3 / I2C SCL (Pin -5) GREEN
│                 │
│   SDA ←─────────┼──→ GPIO 2 / I2C SDA (Pin 3) BLUE
│                 │
│   SDO ←─────────┼──→ GND for 0x76             WHITE
│                 │      or 3.3V for 0x77
└─────────────────┘
```

## Verification

After wiring:

1. **Enable I2C** (if not already):
   ```bash
   sudo raspi-config
   # Navigate to: Interface Options → I2C → Enable
   ```

2. **Scan for I2C devices**:
   ```bash
   sudo i2cdetect -y 1
   ```
   
   You should see a device at either **76** or **77**.

3. **Test the sensor**:
   ```bash
   cd /home/pi/_playground/snake-pit
   uv run python projects/bme680-monitor/monitor.py --monitor --interval 5
   ```

## Troubleshooting

### "No hardware I2C found"
- Check wiring connections
- Verify I2C is enabled with `sudo raspi-config`
- Try running `sudo i2cdetect -y 1`

### "Failed to initialize BME680"
- Check that I2C address matches wiring (0x76 or 0x77)
- Verify power is connected (sensor should have power LED)
- Check all connections are secure

### Sensor reading but values are wrong
- Normal: sensor needs ~1 minute to warm up for accurate readings
- Try running calibration: `--calibrate` flag

### Quick Wiring Check
```bash
# This should show your BME680
sudo i2cdetect -y 1

# If you see "76" or "77" - wiring is correct!
```

## Additional Resources

- Adafruit BME680 Guide: https://learn.adafruit.com/adafruit-bme680-humidity-temperature-barometic-pressure-voc-gas
- Raspberry Pi GPIO Pinout: https://pinout.xyz/

