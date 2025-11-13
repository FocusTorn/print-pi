# Hardware Selection Guide

## Recommended Options for Remote Sensor Hub

### Option 1: ESP32-C6 (Recommended - Best Choice)

**Advantages:**
- ✅ **WiFi 6 (802.11ax)** - Better performance, especially in congested WiFi environments
- ✅ **Lower power consumption** - More efficient than ESP32
- ✅ **Bluetooth 5 (LE)** - Better Bluetooth support than ESP32
- ✅ **Thread/Zigbee support** - Future-proof for IoT protocols
- ✅ **RISC-V architecture** - Modern, open-source CPU architecture
- ✅ **Good I2C support** - Two I2C controllers
- ✅ **Supports OTA updates** - Over-the-air firmware updates
- ✅ **Future-proof** - Newer generation, actively developed

**Disadvantages:**
- ⚠️ **Newer platform** - Less mature ecosystem than ESP32
- ⚠️ **Single-core** - Less parallel processing than dual-core ESP32
- ⚠️ **Fewer GPIO pins** - 30 pins vs 34 on ESP32
- ⚠️ **Less community support** - Newer, so fewer tutorials/examples

**Specifications:**
- CPU: Single-core 32-bit RISC-V, up to 160 MHz
- RAM: 512KB SRAM
- Flash: 4MB+ (varies by module)
- WiFi: 802.11ax (WiFi 6)
- Bluetooth: 5.0 (LE) + IEEE 802.15.4 (Thread/Zigbee)
- GPIO: 30 programmable pins
- I2C: Two I2C controllers
- Price: ~$5-10

**Best For:**
- **This project** - Best choice for remote sensor hubs
- Modern WiFi networks (WiFi 6 routers)
- Lower power applications
- Future expansion to Thread/Zigbee
- Production deployments

### Option 2: ESP32 (Mature & Stable)

**Advantages:**
- ✅ **Dual-core processor** - Better for multitasking
- ✅ **Mature ecosystem** - Extensive libraries and examples
- ✅ **Excellent community support** - Large user base, lots of tutorials
- ✅ **More GPIO pins** - 34 pins vs 30 on ESP32-C6
- ✅ **Built-in sensors** - Temperature sensor, hall effect sensor
- ✅ **Better for complex tasks** - Dual-core helps with sensor arrays
- ✅ **Proven reliability** - Battle-tested in many projects

**Disadvantages:**
- ⚠️ **WiFi 4 only** - Older WiFi standard (802.11 b/g/n)
- ⚠️ **Higher power consumption** - Less efficient than ESP32-C6
- ⚠️ **Older Bluetooth** - Bluetooth 4.2 vs 5.0 on ESP32-C6
- ⚠️ **No Thread/Zigbee** - Missing newer IoT protocols

**Specifications:**
- CPU: Dual-core Tensilica LX6, 240 MHz
- RAM: 520KB SRAM
- Flash: 4MB+ (varies by module)
- WiFi: 802.11 b/g/n (WiFi 4)
- Bluetooth: 4.2 BLE
- GPIO: 34 pins
- I2C: Multiple I2C buses supported
- Price: ~$5-10

**Best For:**
- Projects requiring extensive community resources
- Complex sensor arrays needing dual-core processing
- When you need maximum GPIO pins
- Learning and prototyping (more examples available)
- When WiFi 6 features aren't needed

## Comparison Table

| Feature | ESP32-C6 | ESP32 |
|---------|----------|-------|
| **WiFi** | ✅ WiFi 6 (802.11ax) | ✅ WiFi 4 (802.11 b/g/n) |
| **Bluetooth** | ✅ 5.0 (LE) | ✅ 4.2 BLE |
| **Thread/Zigbee** | ✅ Yes (802.15.4) | ❌ No |
| **CPU** | RISC-V, 160 MHz | Tensilica LX6, 240 MHz |
| **Cores** | 1 | 2 |
| **RAM** | 512KB | 520KB |
| **Flash** | 4MB+ | 4MB+ |
| **GPIO** | 30 pins | 34 pins |
| **I2C Buses** | 2 | Multiple |
| **Power Consumption** | Lower | Higher |
| **MQTT Support** | Excellent | Excellent |
| **OTA Updates** | ✅ Yes | ✅ Yes |
| **Ecosystem Maturity** | Newer, less mature | Mature, extensive |
| **Community Support** | Growing | Extensive |
| **Price** | $5-10 | $5-10 |
| **Best For** | Modern projects, WiFi 6 | Complex tasks, learning |

## Recommendation

**For this project (Remote Sensor Hub with MQTT):**

### Primary Choice: ESP32-C6 ⭐
- **Best for this project** - WiFi 6 provides better performance
- Lower power consumption - Better for remote/battery applications
- Future-proof - Thread/Zigbee support for expansion
- Modern architecture - RISC-V, actively developed
- Excellent MQTT support
- Can handle multiple I2C multiplexers
- Production-ready

**Choose ESP32-C6 if:**
- You have WiFi 6 router (or plan to upgrade)
- You want better power efficiency
- You want modern features (WiFi 6, Bluetooth 5)
- You may expand to Thread/Zigbee in the future

### Alternative: ESP32
- Mature and stable - Extensive community support
- Dual-core - Better for complex sensor processing
- More GPIO pins - If you need extra pins
- More examples/tutorials - Easier to learn

**Choose ESP32 if:**
- You need maximum community support and examples
- You need dual-core processing for complex tasks
- You need more GPIO pins (34 vs 30)
- WiFi 6 features aren't important to you
- You're learning and want more tutorials

## I2C Multiplexer Selection

### TCA9548A (Recommended)

**Why TCA9548A?**
- ✅ 8 I2C channels per multiplexer
- ✅ Can cascade multiple multiplexers
- ✅ Configurable I2C address (0x70-0x77)
- ✅ Low power consumption
- ✅ Widely available
- ✅ Good library support
- ✅ Price: ~$2-3

**Alternatives:**
- PCA9548A (similar to TCA9548A)
- TCA9546A (4 channels, cheaper)
- TCA9543A (2 channels, very cheap)

## Complete Hardware Bill of Materials

### Per Sensor Node (ESP32-C6-based - Recommended):

| Component | Quantity | Unit Price | Total |
|-----------|----------|------------|-------|
| ESP32-C6 Dev Board | 1 | $5-10 | $5-10 |
| TCA9548A Multiplexer | 1-3 | $2-3 | $2-9 |
| I2C Sensors | As needed | $2-10 | Variable |
| Power Supply (5V, 1A) | 1 | $3-5 | $3-5 |
| Breadboard/PCB | 1 | $2-5 | $2-5 |
| Jumper Wires | 1 set | $2-3 | $2-3 |
| **Total (basic)** | | | **$14-32** |

### Per Sensor Node (ESP32-based - Alternative):

| Component | Quantity | Unit Price | Total |
|-----------|----------|------------|-------|
| ESP32 Dev Board | 1 | $5-10 | $5-10 |
| TCA9548A Multiplexer | 1-3 | $2-3 | $2-9 |
| I2C Sensors | As needed | $2-10 | Variable |
| Power Supply (5V, 1A) | 1 | $3-5 | $3-5 |
| Breadboard/PCB | 1 | $2-5 | $2-5 |
| Jumper Wires | 1 set | $2-3 | $2-3 |
| **Total (basic)** | | | **$14-32** |

## Decision Guide

### Choose ESP32-C6 if:
- ✅ You want the best WiFi performance (WiFi 6)
- ✅ You prioritize lower power consumption
- ✅ You want modern features (Bluetooth 5, Thread/Zigbee)
- ✅ You're building for the future
- ✅ You have WiFi 6 router or plan to upgrade

### Choose ESP32 if:
- ✅ You need extensive community support and examples
- ✅ You need dual-core for complex processing
- ✅ You need maximum GPIO pins (34 vs 30)
- ✅ You're learning and want more tutorials
- ✅ WiFi 4 is sufficient for your needs

## Next Steps

1. **Choose ESP32-C6 (recommended) or ESP32** based on your needs
2. **Purchase hardware** components
3. **Set up development environment** (PlatformIO or Arduino IDE)
4. **Wire hardware** according to hardware-setup.md
5. **Develop firmware** for sensor reading and MQTT transmission
6. **Set up MQTT broker** on Raspberry Pi
7. **Test and deploy**

## Resources

### ESP32-C6
- [ESP32-C6 Datasheet](https://www.espressif.com/sites/default/files/documentation/esp32-c6_datasheet_en.pdf)
- [ESP32-C6 Technical Reference](https://www.espressif.com/sites/default/files/documentation/esp32-c6_technical_reference_manual_en.pdf)
- [ESP32-C6 Getting Started](https://docs.espressif.com/projects/esp-idf/en/latest/esp32c6/get-started/)

### ESP32
- [ESP32 Datasheet](https://www.espressif.com/sites/default/files/documentation/esp32_datasheet_en.pdf)
- [ESP32 Technical Reference](https://www.espressif.com/sites/default/files/documentation/esp32_technical_reference_manual_en.pdf)

### Development
- [ESP32 Arduino Core](https://github.com/espressif/arduino-esp32) (Supports both ESP32 and ESP32-C6)
- [PlatformIO ESP32](https://docs.platformio.org/en/latest/platforms/espressif32.html)
- [ESP-IDF](https://docs.espressif.com/projects/esp-idf/en/latest/)

### Hardware
- [TCA9548A Datasheet](https://www.ti.com/lit/ds/symlink/tca9548a.pdf)

