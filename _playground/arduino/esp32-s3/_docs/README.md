# ESP32-S3 Projects

This directory contains all ESP32-S3 Arduino projects.

## Structure

```
esp32-s3/
├── .vscode/
│   └── settings.json          # Shared Arduino/VSCode settings for all projects
├── Blink_ESP32S3/             # Example blink project
│   └── Blink_ESP32S3.ino
├── YourProject1/              # Your project here
│   └── YourProject1.ino
└── README.md                   # This file
```

## Configuration

**Shared settings** (in `.vscode/settings.json`):
- Arduino CLI path
- ESP32 board configuration
- Flash Size: 16MB (for n16r* boards)
- PSRAM: 8MB enabled

**Individual projects** don't need their own `.vscode/settings.json` - they inherit from the parent directory.

## Creating a New Project

1. **Create project directory:**
   ```bash
   cd ~/_playground/arduino/esp32-s3
   mkdir MyNewProject
   cd MyNewProject
   ```

2. **Create your sketch:**
   ```bash
   touch MyNewProject.ino
   # Edit with your code
   ```

3. **Or use Arduino CLI:**
   ```bash
   cd ~/_playground/arduino/esp32-s3
   arduino-cli sketch new MyNewProject
   ```

4. **Open in Cursor/VSCode:**
   ```bash
   cursor ~/_playground/arduino/esp32-s3
   # or
   code ~/_playground/arduino/esp32-s3
   ```

## Board Configuration

All projects in this directory use:
- **Board**: ESP32S3 Dev Module
- **Flash Size**: 16MB (128Mb)
- **PSRAM**: 8MB enabled (QSPI PSRAM)

This is configured for **n16r*** variant boards.

## Compiling and Uploading

### Using VSCode/Cursor:
- Select board and port in bottom right
- Click Upload button (→)

### Using Command Line:
```bash
cd ~/_playground/arduino/esp32-s3/YourProject

# Compile
arduino-cli compile --fqbn esp32:esp32:esp32s3:FlashSize=16M,PSRAM=enabled YourProject

# Upload (replace /dev/ttyUSB0 with your port)
arduino-cli upload -p /dev/ttyUSB0 --fqbn esp32:esp32:esp32s3:FlashSize=16M,PSRAM=enabled YourProject
```

## Quick Reference

**Full FQBN with options:**
```
esp32:esp32:esp32s3:FlashSize=16M,PSRAM=enabled
```

**Check connected boards:**
```bash
arduino-cli board list
```

**Monitor serial output:**
```bash
arduino-cli monitor -p /dev/ttyUSB0
```

