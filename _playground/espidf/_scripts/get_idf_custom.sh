#!/bin/bash
# Custom get_idf that works with only Xtensa toolchain (ESP32-S3 only)
# This bypasses RISC-V and clang toolchain validation

# This script should be sourced, not executed
if [ "${BASH_SOURCE[0]}" = "${0}" ] && [ -z "${ZSH_VERSION-}" ]; then
    echo "This script should be sourced, not executed:"
    echo ". ${BASH_SOURCE[0]}"
    exit 1
fi

IDF_PATH="$HOME/esp/esp-idf"

if [ ! -d "$IDF_PATH" ]; then
    echo "❌ ESP-IDF not found at $IDF_PATH"
    return 1 2>/dev/null || exit 1
fi

# Set basic ESP-IDF environment variables
export IDF_PATH
export ESP_IDF_VERSION="6.1-dev"
export IDF_PYTHON_ENV_PATH="$HOME/.espressif/python_env/idf6.1_py3.13_env"

# Activate Python virtual environment (sets VIRTUAL_ENV for prompt)
if [ -f "$IDF_PYTHON_ENV_PATH/bin/activate" ]; then
    # Source the activate script to properly activate the venv
    # This sets VIRTUAL_ENV which zsh uses to show venv in prompt
    . "$IDF_PYTHON_ENV_PATH/bin/activate"
    # Set a custom prompt label for the venv
    export VIRTUAL_ENV_PROMPT="ESP-IDF"
else
    # Fallback: manually set VIRTUAL_ENV if activate script not found
    export VIRTUAL_ENV="$IDF_PYTHON_ENV_PATH"
    export VIRTUAL_ENV_PROMPT="ESP-IDF"
    export PATH="$IDF_PYTHON_ENV_PATH/bin:$PATH"
fi

# Add Xtensa toolchain to PATH
export PATH="$HOME/.espressif/tools/xtensa-esp-elf/esp-15.2.0_20250929/xtensa-esp-elf/bin:$PATH"
export PATH="$HOME/.espressif/tools/xtensa-esp-elf-gdb/16.3_20250913/xtensa-esp-elf-gdb/bin:$PATH"

# Add ESP-IDF component paths
export PATH="$IDF_PATH/components/espcoredump:$PATH"
export PATH="$IDF_PATH/components/partition_table:$PATH"
export PATH="$IDF_PATH/components/app_update:$PATH"

# Add ESP-IDF tools to PATH
export PATH="$IDF_PATH/tools:$PATH"

echo "✅ ESP-IDF environment activated (Xtensa only - ESP32-S3)"
echo "   IDF_PATH: $IDF_PATH"
echo "   Note: RISC-V and clang tools not installed (not needed for ESP32-S3)"

