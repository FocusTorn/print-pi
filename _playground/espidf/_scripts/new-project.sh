#!/bin/bash
# Create new ESP-IDF project with proper structure
# Usage: new-project.sh <project_name> [target]

set -e

if [[ $# -eq 0 ]]; then
    echo "Usage: new-project.sh <project_name> [target]"
    echo "  target: esp32s3 (default), esp32, esp32c3, esp32c6"
    exit 1
fi

PROJECT_NAME="$1"
TARGET="${2:-esp32s3}"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$BASE_DIR/projects/$PROJECT_NAME"

if [[ -d "$PROJECT_DIR" ]]; then
    echo "Error: Project directory already exists: $PROJECT_DIR" >&2
    exit 1
fi

echo "Creating ESP-IDF project: $PROJECT_NAME (target: $TARGET)"
mkdir -p "$PROJECT_DIR/main"

# Create main CMakeLists.txt
cat > "$PROJECT_DIR/CMakeLists.txt" << 'CMAKE_EOF'
cmake_minimum_required(VERSION 3.16)

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(PROJECT_NAME)
CMAKE_EOF

# Replace PROJECT_NAME placeholder
sed -i "s/PROJECT_NAME/$PROJECT_NAME/g" "$PROJECT_DIR/CMakeLists.txt"

# Create main/CMakeLists.txt
cat > "$PROJECT_DIR/main/CMakeLists.txt" << 'CMAKE_EOF'
idf_component_register(SRCS "main.c"
                    INCLUDE_DIRS ".")
CMAKE_EOF

# Create main/main.c
cat > "$PROJECT_DIR/main/main.c" << 'C_EOF'
#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"

static const char *TAG = "main";

void app_main(void)
{
    ESP_LOGI(TAG, "Hello from ESP-IDF!");
    
    int count = 0;
    while (1) {
        ESP_LOGI(TAG, "Count: %d", count++);
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}
C_EOF

# Create README.md
cat > "$PROJECT_DIR/README.md" << README_EOF
# $PROJECT_NAME

ESP-IDF project for $TARGET.

## Setup

1. Activate ESP-IDF environment:
   \`\`\`bash
   get_idf
   \`\`\`

2. Set target:
   \`\`\`bash
   cd $PROJECT_DIR
   idf.py set-target $TARGET
   \`\`\`

3. Build:
   \`\`\`bash
   idf.py build
   \`\`\`

4. Flash:
   \`\`\`bash
   idf.py -p /dev/ttyUSB0 flash
   \`\`\`

5. Monitor:
   \`\`\`bash
   idf.py -p /dev/ttyUSB0 monitor
   \`\`\`

## Project Structure

- \`main/main.c\` - Main application code
- \`CMakeLists.txt\` - Project build configuration
- \`main/CMakeLists.txt\` - Component build configuration
README_EOF

echo "✅ Project created: $PROJECT_DIR"
echo ""
echo "Next steps:"
echo "  1. cd $PROJECT_DIR"
echo "  2. get_idf"
echo "  3. idf.py set-target $TARGET"
echo "  4. idf.py build"
echo "  5. idf.py -p /dev/ttyUSB0 flash monitor"


