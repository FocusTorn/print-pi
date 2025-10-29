#!/bin/bash
# Quick launcher for Detour TUI during development

cd "$(dirname "$0")"

echo "Building Detour TUI..."
cargo build

if [ $? -eq 0 ]; then
    echo ""
    echo "Launching TUI..."
    echo "Press 'q' to quit"
    echo ""
    sleep 1
    ./target/debug/detour
else
    echo "Build failed!"
    exit 1
fi


