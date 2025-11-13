# Identifying Arduino Nano Clone Versions

## Quick Identification Guide

### Method 1: Physical Inspection

#### Check the Microcontroller (MCU)
Look for the large chip in the center of the board:
- **ATmega328P** - Standard Nano (most common, 32KB flash, 2KB RAM)
- **ATmega328PB** - Extended variant (more I/O pins, 32KB flash, 2KB RAM)
- **ATmega4808** - Nano Every style (48KB flash, 6KB RAM)
- **ATmega168** - Older/lower-end (16KB flash, 1KB RAM)

#### Check the USB-to-Serial Chip
Small chip near the USB connector:
- **FT232RL** - Original/common (usually works with standard drivers)
- **CH340** / **CH341** - Very common in clones (requires CH340 drivers)
- **CP2102** - Also common (usually works with standard drivers)

#### Board Markings
- Look for version numbers: "V3.0", "V3.1", "Rev C", etc.
- Check silkscreen quality and color (genuine = turquoise, clones vary)

### Method 2: Arduino IDE

1. **Connect your Nano via USB**
2. **Open Arduino IDE** → Tools → Board
3. **Select "Arduino Nano"**
4. **Check Tools → Processor**:
   - "ATmega328P" (Old Bootloader)
   - "ATmega328P" (New Bootloader)
   - "ATmega328PB"
   - "ATmega4808" (if Nano Every)

5. **Try uploading a simple sketch** (like Blink)
   - If it fails with "Old Bootloader" selected, try "New Bootloader"
   - If it fails with both, you may need drivers for CH340/CH341

### Method 3: Serial Monitor Identification

Upload the `identify-arduino-nano.ino` sketch and open Serial Monitor at 9600 baud to see:
- MCU type
- Clock frequency
- Flash memory size
- SRAM size
- Bootloader status

### Method 4: Linux Command Line

#### Check USB device info:
```bash
# List USB devices
lsusb

# Look for Arduino-related devices
dmesg | grep -i arduino

# Check serial port
ls -l /dev/ttyUSB* /dev/ttyACM*

# Get detailed USB info
usb-devices | grep -A 10 -i "arduino\|ch340\|ft232\|cp2102"
```

#### Common USB device IDs:
- **FTDI FT232RL**: `0403:6001`
- **CH340**: `1a86:7523` or `1a86:5523`
- **CH341**: `1a86:5523`
- **CP2102**: `10c4:ea60`

### Method 5: Bootloader Timing

The bootloader type affects upload behavior:

- **Old Bootloader**: 
  - Original Arduino bootloader
  - Longer upload delay
  - Select "ATmega328P (Old Bootloader)" in IDE

- **New Bootloader**: 
  - Optiboot (smaller, faster)
  - Shorter upload delay
  - Select "ATmega328P" (default) in IDE

- **No Bootloader**: 
  - Some clones ship without bootloader
  - Requires ISP programmer to upload

## Common Clone Characteristics

### CH340-based clones (most common):
- Very cheap
- Requires CH340 driver installation
- Usually ATmega328P
- Often blue or green board (not turquoise)

### FT232RL-based clones:
- More expensive
- Usually works without additional drivers
- Closer to genuine Arduino

### CP2102-based clones:
- Mid-range price
- Usually works without additional drivers
- Less common than CH340

## Driver Installation (if needed)

### CH340/CH341 Drivers:

**Linux:**
```bash
# Usually works out of the box on modern Linux
# If not, check kernel modules
lsmod | grep ch341
# If missing, may need to build driver
```

**Windows:**
- Download CH340 driver from manufacturer
- Install before connecting the board

**macOS:**
- Usually requires driver installation
- Download from CH340 manufacturer website

## Troubleshooting

### Board not detected:
1. Check USB cable (data cable, not just power)
2. Install appropriate USB-to-serial driver
3. Check USB port functionality
4. Try different USB port

### Upload fails:
1. Try different bootloader option in IDE
2. Press reset button at right moment during upload
3. Check COM port selection in IDE
4. Verify correct board selection

### Wrong clock speed:
- Check Tools → Processor → Clock settings
- Most Nanos are 16 MHz
- Some clones may be 8 MHz (less common)

## Summary

Most third-party Nano clones are:
- **ATmega328P** microcontroller
- **CH340** USB-to-serial chip
- **Blue or green** board color
- Require **CH340 drivers** installation
- Use **"ATmega328P (Old Bootloader)"** or **"ATmega328P"** in Arduino IDE

