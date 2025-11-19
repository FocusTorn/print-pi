# ESP32-S3 n16r* Configuration

For ESP32-S3 boards with **16MB Flash and 8MB PSRAM** (n16r* variant), you need to configure these settings.

## Board Options Required:
- **Flash Size**: `16M` (16MB / 128Mb)
- **PSRAM**: `enabled` (QSPI PSRAM - 8MB)

## Configuration Methods:

### Method 1: VSCode/Cursor Arduino Extension

1. **Open your project** in VSCode/Cursor
2. **Click the board selector** (bottom right)
3. **Select**: `ESP32S3 Dev Module`
4. **Click the gear icon** (⚙️) next to the board to open board configuration
5. **Set the options:**
   - Flash Size: `16MB (128Mb)`
   - PSRAM: `QSPI PSRAM`
6. **Save** and upload

### Method 2: Command Line (Arduino CLI)

**Compile with options:**
```bash
arduino-cli compile --fqbn esp32:esp32:esp32s3:FlashSize=16M,PSRAM=enabled Blink_ESP32S3
```

**Upload with options:**
```bash
arduino-cli upload -p /dev/ttyUSB0 --fqbn esp32:esp32:esp32s3:FlashSize=16M,PSRAM=enabled Blink_ESP32S3
```

### Method 3: VSCode Settings File

Add to `.vscode/settings.json` in your project:

```json
{
  "arduino.configuration": {
    "FlashSize": "16M",
    "PSRAM": "enabled"
  }
}
```

### Method 4: Arduino CLI Config File

You can also create a `arduino-cli.yaml` in your project or use the global config:

```yaml
board:
  fqbn: esp32:esp32:esp32s3:FlashSize=16M,PSRAM=enabled
```

## Quick Reference

**Full FQBN with options:**
```
esp32:esp32:esp32s3:FlashSize=16M,PSRAM=enabled
```

**Available Flash Sizes:**
- `4M` - 4MB (32Mb) - default
- `8M` - 8MB (64Mb)
- `16M` - 16MB (128Mb) ← **Use this for n16r***
- `32M` - 32MB (256Mb)

**Available PSRAM Options:**
- `disabled` - No PSRAM (default)
- `enabled` - QSPI PSRAM (8MB) ← **Use this for n16r***
- `opi` - OPI PSRAM

## Verify Configuration

After uploading, you can verify the configuration in your code:

```cpp
void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.printf("Flash Size: %d bytes\n", ESP.getFlashChipSize());
  Serial.printf("PSRAM Size: %d bytes\n", ESP.getPsramSize());
}
```

Expected output for n16r*:
- Flash Size: 16777216 bytes (16MB)
- PSRAM Size: 8388608 bytes (8MB)


