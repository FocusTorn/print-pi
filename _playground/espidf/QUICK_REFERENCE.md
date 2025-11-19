# ESP-IDF Quick Reference Card

## 🚀 Quick Commands

### Environment Setup
```bash
# Activate ESP-IDF environment
get_idf

# Set target chip
idf.py set-target esp32s3
```

### Build & Flash
```bash
# Build project
idf.py build

# Flash to device
idf.py -p /dev/ttyUSB0 flash

# Build + Flash in one command
idf.py -p /dev/ttyUSB0 flash

# Monitor serial output
idf.py -p /dev/ttyUSB0 monitor

# Build + Flash + Monitor
idf.py -p /dev/ttyUSB0 flash monitor
```

### Project Management
```bash
# Create new project (from template)
cp -r ~/_playground/espidf/projects/hello_world_template my_project

# Clean build
idf.py fullclean

# Show project info
idf.py show_efuse_table
```

## 📋 Common Commands

### Build System
```bash
# Build with verbose output
idf.py build -v

# Build specific component
idf.py build --component main

# Clean build
idf.py fullclean build
```

### Flash & Monitor
```bash
# Flash with specific baud rate
idf.py -p /dev/ttyUSB0 -b 460800 flash

# Monitor with specific baud rate
idf.py -p /dev/ttyUSB0 monitor -b 115200

# Erase flash
idf.py -p /dev/ttyUSB0 erase-flash
```

### Configuration
```bash
# Open menuconfig
idf.py menuconfig

# Show configuration
idf.py show_efuse_table
```

## 🔧 Configuration

### Common Targets
- `esp32s3` - ESP32-S3 (recommended)
- `esp32` - ESP32 (original)
- `esp32c3` - ESP32-C3
- `esp32c6` - ESP32-C6

### Common Ports
- `/dev/ttyUSB0` - Most common (CH340K, CP2102)
- `/dev/ttyUSB1` - If multiple USB devices
- `/dev/ttyACM0` - Some USB-to-serial adapters

### Baud Rates
- `115200` - Default monitor baud rate
- `460800` - Fast flash baud rate
- `921600` - Very fast flash (may be unstable)

## 📁 Project Structure

```
my_project/
├── CMakeLists.txt        # Project build configuration
├── main/
│   ├── CMakeLists.txt   # Component build configuration
│   └── main.c           # Main application code
├── sdkconfig            # Project configuration (generated)
└── README.md            # Project documentation
```

## 🛠️ Troubleshooting

### Board Not Detected
```bash
# Check USB connection
lsusb

# Check port permissions
ls -l /dev/ttyUSB0

# Add user to dialout group
sudo usermod -a -G dialout $USER
# (logout and login again)
```

### Build Errors
```bash
# Clean and rebuild
idf.py fullclean
idf.py build

# Check ESP-IDF version
idf.py --version

# Verify environment
echo $IDF_PATH
```

### Flash Fails
```bash
# Try different baud rate
idf.py -p /dev/ttyUSB0 -b 115200 flash

# Put device in download mode (hold BOOT button)
# Then release BOOT and press RESET

# Check port
idf.py -p /dev/ttyUSB0 flash monitor
```

## 💡 Tips

1. **First build is slow** - Subsequent builds are faster (incremental)
2. **Use `idf.py flash monitor`** - Combines flash and monitor
3. **Menuconfig** - Use `idf.py menuconfig` to configure project
4. **Component system** - ESP-IDF uses components for modular code
5. **Partition tables** - Configure flash partitions in menuconfig

## 🔗 Resources

- [ESP-IDF Programming Guide](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/)
- [ESP-IDF API Reference](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/api-reference/)
- [ESP-IDF Examples](https://github.com/espressif/esp-idf/tree/master/examples)

---

**Last Updated**: $(date +%Y-%m-%d)


