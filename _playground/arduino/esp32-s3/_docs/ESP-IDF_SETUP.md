# ESP-IDF Setup Guide for ESP32-S3

Complete guide for setting up and using ESP-IDF (Espressif IoT Development Framework) for ESP32-S3 development.

## Overview

ESP-IDF is Espressif's official development framework for ESP32 series chips. Unlike Arduino, ESP-IDF provides:
- Native dual-core support
- Full hardware control
- Standard embedded systems structure (no `setup()`/`loop()`)
- Better performance and optimization
- Direct FreeRTOS access

## Prerequisites

### System Requirements
- **Python 3.6+** (already installed)
- **pip** (already installed)
- **Git** (will be installed by bootstrap)
- **Build tools** (cmake, ninja, etc. - installed by bootstrap)

### Hardware
- ESP32-S3 development board (N16R8 variant: 16MB Flash + 8MB PSRAM)
- USB cable (data-capable)
- Linux system (Raspberry Pi 4 / Debian 13)

## Installation

### Step 1: Run Bootstrap Script

```bash
~/_playground/_scripts/bootstraps/bootstrap-esp-idf.sh
```

This will:
- Install build tools and dependencies
- Clone ESP-IDF repository to `~/esp/esp-idf`
- Run ESP-IDF's install script for ESP32-S3
- Set up environment variables
- Create project template

### Step 2: Activate ESP-IDF Environment

After installation, activate ESP-IDF in your shell:

```bash
# Restart shell or source .zshrc
source ~/.zshrc

# Activate ESP-IDF environment
get_idf
```

**Note**: You need to run `get_idf` in each new terminal session, or add it to your `.zshrc` to auto-load (slower startup).

### Step 3: Verify Installation

```bash
idf.py --version
idf.py --help
```

## Project Structure

ESP-IDF projects use a different structure than Arduino:

```
my_project/
├── CMakeLists.txt          # Project build configuration
├── main/
│   ├── CMakeLists.txt      # Component build configuration
│   └── main.c              # Main application code
├── sdkconfig               # Project configuration (generated)
└── README.md
```

### Key Differences from Arduino

| Arduino | ESP-IDF |
|---------|---------|
| `setup()` + `loop()` | `app_main()` + FreeRTOS tasks |
| `.ino` files | `.c` or `.cpp` files |
| Arduino build system | CMake build system |
| `arduino-cli` commands | `idf.py` commands |
| Single core by default | Dual-core native |

## Creating Your First Project

### Option 1: Use Template

```bash
cp -r ~/_playground/arduino/esp32-s3/esp-idf-projects/hello_world_template my_project
cd my_project
```

### Option 2: Create from Scratch

```bash
mkdir my_project
cd my_project
mkdir main

# Create CMakeLists.txt
cat > CMakeLists.txt << 'EOF'
cmake_minimum_required(VERSION 3.16)
include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(my_project)
EOF

# Create main/CMakeLists.txt
cat > main/CMakeLists.txt << 'EOF'
idf_component_register(SRCS "main.c"
                    INCLUDE_DIRS ".")
EOF

# Create main/main.c
cat > main/main.c << 'EOF'
#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"

static const char *TAG = "my_project";

void app_main(void)
{
    ESP_LOGI(TAG, "Hello from ESP32-S3!");
    
    int count = 0;
    while (1) {
        ESP_LOGI(TAG, "Count: %d", count++);
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}
EOF
```

## Building and Flashing

### Set Target

First, set the target chip:

```bash
idf.py set-target esp32s3
```

This creates `sdkconfig` with ESP32-S3-specific settings.

### Build

```bash
idf.py build
```

### Flash

```bash
# Auto-detect port
idf.py flash

# Or specify port
idf.py -p /dev/ttyUSB0 flash
```

### Monitor Serial Output

```bash
# After flashing
idf.py -p /dev/ttyUSB0 monitor

# Or flash and monitor together
idf.py -p /dev/ttyUSB0 flash monitor
```

### Exit Monitor

Press `Ctrl+]` to exit the monitor.

## Configuration

### Menu Configuration

ESP-IDF uses a menu-based configuration system:

```bash
idf.py menuconfig
```

This opens an interactive menu where you can configure:
- Component settings
- WiFi/Bluetooth options
- Memory settings
- PSRAM configuration
- Partition tables
- And much more

### Key Settings for ESP32-S3 N16R8

In `menuconfig`:
- **Component config → ESP32S3-Specific → PSRAM**: Enable if using PSRAM
- **Partition Table**: Choose partition scheme
- **Serial flasher config**: Set flash size (16MB for N16R8)

## Dual-Core Usage

ESP-IDF makes dual-core usage straightforward:

```c
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

void task_core0(void *parameter) {
    while(1) {
        // Code running on Core 0
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

void task_core1(void *parameter) {
    while(1) {
        // Code running on Core 1
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

void app_main(void) {
    // Create task on Core 0
    xTaskCreatePinnedToCore(
        task_core0,
        "Core0Task",
        4096,
        NULL,
        5,
        NULL,
        0  // Core 0
    );
    
    // Create task on Core 1
    xTaskCreatePinnedToCore(
        task_core1,
        "Core1Task",
        4096,
        NULL,
        5,
        NULL,
        1  // Core 1
    );
}
```

## Common Commands

### Build System

```bash
# Build project
idf.py build

# Clean build
idf.py fullclean

# Rebuild (clean + build)
idf.py rebuild
```

### Flashing

```bash
# Flash firmware
idf.py flash

# Flash with specific port
idf.py -p /dev/ttyUSB0 flash

# Erase flash
idf.py erase-flash
```

### Monitoring

```bash
# Monitor serial output
idf.py monitor

# Flash and monitor
idf.py flash monitor

# Monitor with specific baud rate
idf.py monitor -b 115200
```

### Configuration

```bash
# Open configuration menu
idf.py menuconfig

# Show configuration
idf.py show_efuse_table
```

### Project Management

```bash
# Set target chip
idf.py set-target esp32s3

# Show project info
idf.py show-property-value PROJECT_NAME
```

## Project Organization

### Recommended Structure

```
esp32-s3/
├── esp-idf-projects/          # ESP-IDF projects
│   ├── project1/
│   ├── project2/
│   └── hello_world_template/
├── _scripts/                  # Helper scripts
├── _docs/                     # Documentation
└── Blink_ESP32S3/            # Old Arduino project (if keeping)
```

### Component Structure

ESP-IDF uses components (similar to libraries):

```
components/
├── my_component/
│   ├── CMakeLists.txt
│   ├── include/
│   │   └── my_component.h
│   └── my_component.c
└── another_component/
    └── ...
```

## Using PSRAM (N16R8)

Your board has 8MB PSRAM. To use it:

1. Enable in `menuconfig`:
   ```
   Component config → ESP32S3-Specific → Support for external, SPI-connected RAM → Enable
   ```

2. Allocate PSRAM in code:
   ```c
   #include "esp_heap_caps.h"
   
   void *psram_ptr = heap_caps_malloc(size, MALLOC_CAP_SPIRAM);
   ```

## WiFi Example

```c
#include "esp_wifi.h"
#include "esp_event.h"
#include "nvs_flash.h"

void app_main(void)
{
    // Initialize NVS
    nvs_flash_init();
    
    // Initialize WiFi
    esp_netif_init();
    esp_event_loop_create_default();
    esp_netif_create_default_wifi_sta();
    
    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    esp_wifi_init(&cfg);
    
    // Configure WiFi
    wifi_config_t wifi_config = {
        .sta = {
            .ssid = "YourSSID",
            .password = "YourPassword",
        },
    };
    
    esp_wifi_set_mode(WIFI_MODE_STA);
    esp_wifi_set_config(WIFI_IF_STA, &wifi_config);
    esp_wifi_start();
    esp_wifi_connect();
    
    // Your application code
}
```

## Bluetooth Example

```c
#include "esp_bt.h"
#include "esp_bt_main.h"
#include "esp_gap_ble_api.h"

void app_main(void)
{
    // Initialize Bluetooth
    esp_bt_controller_config_t bt_cfg = BT_CONTROLLER_INIT_CONFIG_DEFAULT();
    esp_bt_controller_init(&bt_cfg);
    esp_bt_controller_enable(ESP_BT_MODE_BLE);
    esp_bluedroid_init();
    esp_bluedroid_enable();
    
    // Your BLE code
}
```

## Debugging

### Serial Debugging

Use `ESP_LOGI`, `ESP_LOGW`, `ESP_LOGE` for logging:

```c
#include "esp_log.h"

static const char *TAG = "my_component";

ESP_LOGI(TAG, "Info message: %d", value);
ESP_LOGW(TAG, "Warning message");
ESP_LOGE(TAG, "Error message");
```

### GDB Debugging

ESP-IDF supports GDB debugging:

```bash
idf.py openocd
# In another terminal
idf.py gdb
```

## VSCode/Cursor Integration

### ESP-IDF Extension

Install the ESP-IDF extension:
- **Extension ID**: `espressif.esp-idf-extension`
- Provides: Project creation, configuration, building, flashing, debugging

### Extension Features

- Project creation wizard
- `idf.py` command integration
- Configuration menu access
- Serial monitor
- Debugging support
- Component management

## Troubleshooting

### Port Not Found

```bash
# Check connected devices
lsusb
ls -la /dev/ttyUSB* /dev/ttyACM*

# Check permissions
groups | grep dialout
# If not in dialout group:
sudo usermod -a -G dialout $USER
# Then logout/login
```

### Build Errors

```bash
# Clean and rebuild
idf.py fullclean
idf.py build

# Check ESP-IDF version
cd ~/esp/esp-idf
git describe --tags
```

### Flash Errors

```bash
# Try bootloader mode (hold BOOT button during flash)
idf.py -p /dev/ttyUSB0 flash

# Erase flash and retry
idf.py erase-flash
idf.py flash
```

## Migration from Arduino

### Key Differences

1. **Entry Point**: `app_main()` instead of `setup()`/`loop()`
2. **Build System**: CMake instead of Arduino build
3. **Commands**: `idf.py` instead of `arduino-cli`
4. **Structure**: Components instead of libraries
5. **Multi-tasking**: FreeRTOS tasks instead of single loop

### Converting Arduino Code

Arduino code needs significant restructuring:
- Replace `setup()` with initialization in `app_main()`
- Replace `loop()` with FreeRTOS tasks
- Replace Arduino libraries with ESP-IDF components
- Use ESP-IDF APIs instead of Arduino functions

## Resources

### Official Documentation
- [ESP-IDF Programming Guide](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/)
- [ESP-IDF API Reference](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/api-reference/)
- [ESP32-S3 Datasheet](https://www.espressif.com/sites/default/files/documentation/esp32-s3_datasheet_en.pdf)
- [ESP32-S3 Technical Reference Manual](https://www.espressif.com/sites/default/files/documentation/esp32-s3_technical_reference_manual_en.pdf)

### Examples
- ESP-IDF examples: `~/esp/esp-idf/examples/`
- GitHub: https://github.com/espressif/esp-idf

### Community
- ESP32 Forum: https://esp32.com/
- ESP-IDF Issues: https://github.com/espressif/esp-idf/issues

## Next Steps

1. **Run bootstrap script** to install ESP-IDF
2. **Create hello_world project** to test setup
3. **Explore examples** in `~/esp/esp-idf/examples/`
4. **Read ESP-IDF docs** for your use case
5. **Start building** your project!

---

**Last Updated**: 2024-11-19

