# ESP32-S3 Setup and Programming Guide

## Step 1: Connect Your ESP32-S3

1. **Connect via USB** to your Raspberry Pi
2. **Check if it's detected:**
   ```bash
   lsusb
   ls -la /dev/tty* | grep -E "USB|ACM"
   arduino-cli board list
   ```

## Step 2: Install Required Tools

### For Cursor IDE (C/C++ Extension)

The C/C++ extension (`anysphere.cpptools`) requires the **clangd language server**:

```bash
sudo apt install clangd
```

Verify installation:
```bash
clangd --version
```

**Note:** Automatic installation only works on x86-64 systems. On ARM (Raspberry Pi), you need to install manually via apt.

## Step 3: Create Your First Sketch

### Option A: Using Arduino CLI (Command Line)

1. **Create a new sketch:**
   ```bash
   cd ~/_playground/arduino
   arduino-cli sketch new MyESP32Project
   ```

2. **Edit the sketch:**
   ```bash
   code MyESP32Project/MyESP32Project.ino
   # or
   cursor MyESP32Project/MyESP32Project.ino
   ```

3. **Write your code** (example Blink):
   ```cpp
   void setup() {
     pinMode(LED_BUILTIN, OUTPUT);
   }

   void loop() {
     digitalWrite(LED_BUILTIN, HIGH);
     delay(1000);
     digitalWrite(LED_BUILTIN, LOW);
     delay(1000);
   }
   ```

4. **Compile:**
   ```bash
   arduino-cli compile --fqbn esp32:esp32:esp32s3 MyESP32Project
   ```

5. **Upload:**
   ```bash
   arduino-cli upload -p /dev/ttyUSB0 --fqbn esp32:esp32:esp32s3 MyESP32Project
   ```
   (Replace `/dev/ttyUSB0` with your actual port from `arduino-cli board list`)

### Option B: Using VSCode/Cursor with Arduino Extension

1. **Install Required Tools:**
   - **For Cursor**: Install `clangd` language server:
     ```bash
     sudo apt install clangd
     ```
   - **For VSCode**: Usually handles this automatically

2. **Install the Arduino Extension:**
   - Open Extensions (Ctrl+Shift+X)
   - Search for "Arduino" and install the Community Edition
   - Install C/C++ extension:
     - **Cursor**: `anysphere.cpptools` (requires clangd on PATH)
     - **VSCode**: `ms-vscode.cpptools-extension-pack`

2. **Configure Arduino Extension:**
   - Open Command Palette (Ctrl+Shift+P)
   - Type "Arduino: Initialize" or create a new sketch
   - Or create a folder and add `.ino` file

3. **Set up your project:**
   - Create folder: `~/_playground/arduino/MyESP32Project/`
   - Create file: `MyESP32Project.ino`
   - Add your code

4. **Configure board:**
   - Bottom right of VSCode/Cursor, click on board selector
   - Select: **ESP32S3 Dev Module** (or your specific board)
   - Select port: `/dev/ttyUSB0` (or whatever shows in `arduino-cli board list`)

5. **Upload:**
   - Click the Upload button (→) in the top right
   - Or use Command Palette: "Arduino: Upload"

## Step 3: Common Issues and Solutions

### ESP32-S3 Not Detected

1. **Check USB connection:**
   ```bash
   lsusb
   # Should show something like: Silicon Labs CP210x or CH340
   ```

2. **Check permissions:**
   ```bash
   ls -la /dev/ttyUSB0
   # If permission denied, add user to dialout group:
   sudo usermod -a -G dialout $USER
   # Then logout/login or:
   newgrp dialout
   ```

3. **Check if ESP32-S3 is in bootloader mode:**
   - Some boards need BOOT button pressed during upload
   - Some auto-enter bootloader mode

4. **Try different USB port/cable:**
   - Some cables are power-only (no data)
   - Try a different USB port

### Finding the Correct Port

```bash
# Method 1: Arduino CLI
arduino-cli board list

# Method 2: List USB devices
ls -la /dev/ttyUSB* /dev/ttyACM* 2>/dev/null

# Method 3: Check dmesg when plugging in
dmesg | tail -20
```

### Finding the Correct Board FQBN

```bash
# List all ESP32-S3 boards
arduino-cli board listall | grep esp32s3

# Common ESP32-S3 FQBNs:
# esp32:esp32:esp32s3
# esp32:esp32:esp32s3devkitc1
# esp32:esp32:adafruit_feather_esp32s3
```

## Step 4: VSCode/Cursor Settings

Create `.vscode/settings.json` in your project:

```json
{
  "arduino.path": "/home/pi/.local/bin/arduino-cli",
  "arduino.additionalUrls": [
    "https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json"
  ],
  "arduino.defaultBaudRate": 115200,
  "arduino.logLevel": "info"
}
```

## Step 5: Example Sketch Structure

```
MyESP32Project/
├── MyESP32Project.ino    (main sketch file)
├── .vscode/
│   └── settings.json     (Arduino extension config)
└── (libraries go in ~/.arduino15/libraries/)
```

## Quick Reference Commands

```bash
# List connected boards
arduino-cli board list

# List all available ESP32-S3 boards
arduino-cli board listall | grep esp32s3

# Compile sketch
arduino-cli compile --fqbn esp32:esp32:esp32s3 MyESP32Project

# Upload sketch
arduino-cli upload -p /dev/ttyUSB0 --fqbn esp32:esp32:esp32s3 MyESP32Project

# Monitor serial output
arduino-cli monitor -p /dev/ttyUSB0

# Or use screen/minicom
screen /dev/ttyUSB0 115200
# Exit: Ctrl+A then K, then Y
```

## Next Steps

1. ✅ Verify ESP32-S3 is detected: `arduino-cli board list`
2. ✅ Create your first sketch
3. ✅ Configure VSCode/Cursor Arduino extension
4. ✅ Upload and test!


