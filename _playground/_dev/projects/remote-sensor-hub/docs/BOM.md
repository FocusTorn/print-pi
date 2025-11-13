# Bill of Materials (BOM)

## Remote Sensor Hub - Complete BOM

**Last Updated:** 2024-11-07  
**Project:** Remote Sensor Hub with ESP32-C6/ESP32

---

## Per Sensor Node

### Required Components

| Item | Part Number | Description | Qty | Unit Price | Total | Notes |
|------|-------------|-------------|-----|------------|-------|-------|
| **1. Microcontroller** | | | | | | |
| ESP32-C6 Dev Board | ESP32-C6-DevKitC-1 | ESP32-C6 Development Board (Recommended) | 1 | $6-12 | $6-12 | WiFi 6, Bluetooth 5, RISC-V |
| *OR* ESP32 Dev Board | ESP32-DevKitC | ESP32 Development Board (Alternative) | 1 | $5-10 | $5-10 | Dual-core, mature ecosystem |
| | | | | | | |
| **2. I2C Multiplexer** | | | | | | |
| TCA9548A | TCA9548A | 8-Channel I2C Multiplexer | 1-3 | $2-4 | $2-12 | 1 mux = 8 sensors, 3 muxes = 24 sensors |
| | | | | | | |
| **3. Power Supply** | | | | | | |
| USB Power Supply | Generic | 5V 1A USB Power Adapter | 1 | $3-5 | $3-5 | For ESP32-C6/ESP32 |
| USB-C Cable | Generic | USB-C to USB-A Cable | 1 | $2-4 | $2-4 | For programming and power |
| *OR* DC Power Supply | MEANWELL LRS-50-5 | 5V 10A Switching Power Supply | 1 | $8-12 | $8-12 | For multiple sensors |
| | | | | | | |
| **4. Prototyping** | | | | | | |
| Breadboard | Generic | 830 Tie-Point Breadboard | 1 | $3-5 | $3-5 | For prototyping |
| *OR* PCB | Custom | Custom PCB (optional) | 1 | $10-50 | $10-50 | For production |
| Jumper Wires | Generic | Male-to-Male Jumper Wires (40pcs) | 1 | $2-4 | $2-4 | For connections |
| | | | | | | |
| **5. Sensors** | | | | | | |
| BME280 | BME280 | Temperature/Humidity/Pressure Sensor | 1-24 | $3-6 | $3-144 | I2C address: 0x76 or 0x77 |
| SHT31 | SHT31-D | Temperature/Humidity Sensor | 1-24 | $5-8 | $5-192 | I2C address: 0x44 or 0x45 |
| TMP102 | TMP102 | Temperature Sensor | 1-24 | $2-4 | $2-96 | I2C address: 0x48 |
| MPU6050 | MPU6050 | Accelerometer/Gyroscope | 1-24 | $2-4 | $2-96 | I2C address: 0x68 |
| | | | | | | |
| **6. Passive Components** | | | | | | |
| Pull-up Resistors | 4.7kΩ | 4.7kΩ Resistor (1/4W) | 2-4 | $0.10 | $0.20-0.40 | For I2C if not on board |
| | | | | | | |
| **7. Enclosure (Optional)** | | | | | | |
| Project Box | Generic | Plastic Project Enclosure | 1 | $5-15 | $5-15 | For protection |
| | | | | | | |
| **TOTAL PER NODE (Basic)** | | | | | **$14-32** | Without sensors |
| **TOTAL PER NODE (With 8 Sensors)** | | | | | **$35-80** | With 8x BME280 sensors |

---

## Central Hub (Raspberry Pi 4)

### Required Components

| Item | Part Number | Description | Qty | Unit Price | Total | Notes |
|------|-------------|-------------|-----|------------|-------|-------|
| **1. Main Board** | | | | | | |
| Raspberry Pi 4 | RPi4-4GB | Raspberry Pi 4 (4GB) | 1 | $55-75 | $55-75 | Already owned |
| MicroSD Card | SanDisk Ultra | 32GB+ MicroSD Card (Class 10) | 1 | $5-10 | $5-10 | For OS and data |
| | | | | | | |
| **2. Power Supply** | | | | | | |
| USB-C Power Supply | Official RPi PSU | 5.1V 3A USB-C Power Supply | 1 | $8-12 | $8-12 | Official recommended |
| | | | | | | |
| **3. Cooling (Optional)** | | | | | | |
| Heat Sinks | Generic | Raspberry Pi 4 Heat Sinks | 1 | $2-5 | $2-5 | For thermal management |
| *OR* Fan Case | Generic | Raspberry Pi 4 Fan Case | 1 | $10-20 | $10-20 | Active cooling |
| | | | | | | |
| **4. Network** | | | | | | |
| Ethernet Cable | Cat6 | Ethernet Cable (if using wired) | 1 | $3-8 | $3-8 | Optional |
| | | | | | | |
| **TOTAL FOR CENTRAL HUB** | | | | | **$73-118** | Excluding Pi (already owned) |

---

## Recommended Part Numbers & Sources

### ESP32-C6 Development Boards

| Vendor | Part Number | Price | Link |
|--------|-------------|-------|------|
| Espressif | ESP32-C6-DevKitC-1 | $6-12 | [Official Store](https://www.espressif.com/en/products/devkits) |
| Adafruit | Adafruit ESP32-C6 Feather | $15-20 | [Adafruit](https://www.adafruit.com/) |
| SparkFun | SparkFun ESP32-C6 Thing Plus | $15-20 | [SparkFun](https://www.sparkfun.com/) |
| AliExpress | Generic ESP32-C6 Dev Board | $4-8 | [AliExpress](https://www.aliexpress.com/) |
| Amazon | Generic ESP32-C6 | $6-12 | [Amazon](https://www.amazon.com/) |

### ESP32 Development Boards (Alternative)

| Vendor | Part Number | Price | Notes |
|--------|-------------|-------|------|
| Espressif | ESP32-DevKitC | $5-10 | Official board |
| Adafruit | Adafruit ESP32 Feather | $20-25 | High quality |
| Generic | ESP32-WROOM-32 | $4-8 | Common clone |

### TCA9548A I2C Multiplexer

| Vendor | Part Number | Price | Notes |
|--------|-------------|-------|-------|
| Adafruit | Adafruit TCA9548A | $4-6 | Breakout board, easy to use |
| SparkFun | SparkFun Qwiic Mux | $5-7 | Qwiic connector |
| Generic | TCA9548A Module | $2-3 | Bare module, cheaper |
| TI | TCA9548APWR | $1-2 | IC only (requires PCB) |

### Sensors

#### BME280 (Temperature/Humidity/Pressure)

| Vendor | Part Number | Price | Notes |
|--------|-------------|-------|-------|
| Adafruit | Adafruit BME280 | $5-8 | Breakout board |
| SparkFun | SparkFun BME280 | $5-7 | Breakout board |
| Generic | BME280 Module | $3-5 | Bare module |

#### SHT31 (Temperature/Humidity)

| Vendor | Part Number | Price | Notes |
|--------|-------------|-------|-------|
| Adafruit | Adafruit SHT31-D | $7-10 | High accuracy |
| SparkFun | SparkFun SHT31 | $6-9 | Breakout board |
| Generic | SHT31 Module | $5-7 | Bare module |

### Power Supplies

| Item | Part Number | Price | Notes |
|------|-------------|-------|-------|
| USB Power Adapter | Generic 5V 1A | $3-5 | For single node |
| MEANWELL LRS-50-5 | 5V 10A | $8-12 | For multiple sensors |
| MEANWELL LRS-100-5 | 5V 20A | $12-18 | For large sensor arrays |

---

## Complete System BOM Example

### Example: 3 Sensor Nodes + 1 Central Hub

| Component | Qty | Unit Price | Total |
|-----------|-----|------------|-------|
| **Sensor Nodes (x3)** | | | |
| ESP32-C6 Dev Board | 3 | $8 | $24 |
| TCA9548A Multiplexer | 3 | $3 | $9 |
| BME280 Sensor | 24 | $4 | $96 |
| USB Power Supply | 3 | $4 | $12 |
| USB-C Cable | 3 | $3 | $9 |
| Breadboard | 3 | $4 | $12 |
| Jumper Wires | 3 | $3 | $9 |
| **Subtotal Sensor Nodes** | | | **$171** |
| | | | |
| **Central Hub** | | | |
| MicroSD Card (32GB) | 1 | $8 | $8 |
| USB-C Power Supply | 1 | $10 | $10 |
| Heat Sinks | 1 | $3 | $3 |
| **Subtotal Central Hub** | | | **$21** |
| | | | |
| **TOTAL SYSTEM** | | | **$192** |

*Note: Raspberry Pi 4 not included (assumed already owned)*

---

## Sourcing Recommendations

### For Prototyping (1-2 Nodes)

**Best Sources:**
- **Adafruit** - High quality, excellent documentation, US-based
- **SparkFun** - Good quality, good documentation, US-based
- **Amazon** - Fast shipping, good for quick prototypes

**Budget Option:**
- **AliExpress** - Lower prices, longer shipping (2-4 weeks)

### For Production (10+ Nodes)

**Best Sources:**
- **AliExpress** - Best prices in bulk
- **LCSC** - Component distributor, good for ICs
- **Mouser/Digikey** - Reliable, fast shipping, higher prices

### Recommended Vendors

1. **Adafruit Industries** (adafruit.com)
   - Pros: Excellent quality, great documentation, US-based
   - Cons: Higher prices
   - Best for: Prototyping, learning

2. **SparkFun Electronics** (sparkfun.com)
   - Pros: Good quality, good documentation, US-based
   - Cons: Slightly higher prices
   - Best for: Prototyping

3. **AliExpress** (aliexpress.com)
   - Pros: Lowest prices, huge selection
   - Cons: Longer shipping, quality varies
   - Best for: Production, budget projects

4. **Amazon** (amazon.com)
   - Pros: Fast shipping, easy returns
   - Cons: Higher prices, quality varies
   - Best for: Quick prototypes

5. **Mouser/Digikey** (mouser.com, digikey.com)
   - Pros: Reliable, fast shipping, authentic parts
   - Cons: Higher prices
   - Best for: Production, critical applications

---

## Alternative Components

### Alternative I2C Multiplexers

| Part | Channels | Price | Notes |
|------|----------|-------|-------|
| TCA9548A | 8 | $2-4 | Recommended |
| TCA9546A | 4 | $1-3 | Cheaper, fewer channels |
| TCA9543A | 2 | $1-2 | Very cheap, only 2 channels |
| PCA9548A | 8 | $2-4 | Similar to TCA9548A |

### Alternative Sensors

| Sensor | Type | Price | Notes |
|--------|------|-------|-------|
| BME280 | Temp/Humid/Press | $3-6 | Recommended, 3-in-1 |
| SHT31 | Temp/Humid | $5-8 | High accuracy |
| TMP102 | Temperature | $2-4 | Simple, cheap |
| DHT22 | Temp/Humid | $3-5 | Not I2C (needs different approach) |
| MPU6050 | Accel/Gyro | $2-4 | Motion sensor |

---

## Quantity Discounts

### Bulk Pricing Estimates

| Component | 1-5 units | 6-20 units | 21-50 units | 50+ units |
|-----------|-----------|------------|-------------|-----------|
| ESP32-C6 | $8 | $7 | $6 | $5 |
| TCA9548A | $3 | $2.50 | $2 | $1.50 |
| BME280 | $4 | $3.50 | $3 | $2.50 |

---

## Shipping Considerations

### Estimated Shipping Costs

| Source | Shipping Time | Cost | Notes |
|--------|---------------|------|-------|
| Adafruit (US) | 2-5 days | $5-10 | US only |
| SparkFun (US) | 2-5 days | $5-10 | US only |
| Amazon | 1-2 days | $0-10 | Prime eligible |
| AliExpress | 2-4 weeks | $0-5 | Free shipping common |
| Mouser/Digikey | 1-3 days | $8-15 | Fast, reliable |

---

## Total Cost Summary

### Minimum Configuration (1 Node, 8 Sensors)
- ESP32-C6: $8
- TCA9548A: $3
- 8x BME280: $32
- Power Supply: $4
- Breadboard + Wires: $6
- **Total: ~$53**

### Recommended Configuration (3 Nodes, 24 Sensors)
- 3x ESP32-C6: $24
- 3x TCA9548A: $9
- 24x BME280: $96
- 3x Power Supplies: $12
- 3x Breadboards + Wires: $18
- **Total: ~$159**

### Production Configuration (10 Nodes, 80 Sensors)
- 10x ESP32-C6: $60
- 10x TCA9548A: $25
- 80x BME280: $240
- 10x Power Supplies: $40
- 10x Breadboards + Wires: $60
- **Total: ~$425**

---

## Notes

1. **Prices are estimates** - Actual prices vary by vendor, quantity, and time
2. **Shipping not included** - Add shipping costs to totals
3. **Taxes not included** - Add applicable sales tax
4. **Raspberry Pi 4** - Assumed already owned (not in BOM)
5. **Enclosures optional** - Add $5-15 per node if needed
6. **PCBs optional** - Custom PCBs cost $10-50 each in small quantities

---

## Next Steps

1. **Review BOM** - Confirm quantities and components
2. **Source components** - Order from recommended vendors
3. **Verify compatibility** - Ensure all components work together
4. **Order samples** - Test with 1 node before bulk order
5. **Document part numbers** - Keep track of exact part numbers used

---

## Revision History

| Date | Version | Changes |
|------|---------|---------|
| 2024-11-07 | 1.0 | Initial BOM created |

