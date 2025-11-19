#!/bin/bash
# Wrapper for get_idf that works with only Xtensa toolchain (ESP32-S3 only)
# This bypasses RISC-V and clang toolchain validation

# Source the original export.sh but with prefer-system flag
# We'll manually set up the environment to skip missing tools

if [ -f "$HOME/esp/esp-idf/export.sh" ]; then
    # Temporarily set environment to prefer system tools
    export IDF_TOOLS_EXPORT_OPTS="--prefer-system"
    
    # Source the original export script
    . "$HOME/esp/esp-idf/export.sh"
    
    # The export.sh uses activate.py which calls idf_tools.py
    # We need to work around the validation
    
    # Actually, let's just manually export what we need
    export IDF_PATH="$HOME/esp/esp-idf"
    export PATH="$HOME/.espressif/tools/xtensa-esp-elf/esp-15.2.0_20250929/xtensa-esp-elf/bin:$PATH"
    export PATH="$HOME/.espressif/tools/xtensa-esp-elf-gdb/16.3_20250913/xtensa-esp-elf-gdb/bin:$PATH"
    export PATH="$HOME/.espressif/python_env/idf6.1_py3.13_env/bin:$PATH"
    
    echo "✅ ESP-IDF environment activated (Xtensa only - ESP32-S3)"
    echo "   IDF_PATH: $IDF_PATH"
    echo "   Note: RISC-V and clang tools not installed (not needed for ESP32-S3)"
else
    echo "❌ ESP-IDF not found at $HOME/esp/esp-idf"
    return 1
fi

