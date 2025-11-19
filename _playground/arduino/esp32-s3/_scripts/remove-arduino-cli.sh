#!/bin/bash
# Remove Arduino CLI installation

set -e

echo "🗑️  Removing Arduino CLI..."

# Remove binary
if [ -f ~/.local/bin/arduino-cli ]; then
    rm ~/.local/bin/arduino-cli
    echo "✅ Removed arduino-cli binary"
else
    echo "ℹ️  arduino-cli binary not found"
fi

# Remove data directory
if [ -d ~/.arduino15 ]; then
    SIZE=$(du -sh ~/.arduino15 | cut -f1)
    echo "⚠️  Removing ~/.arduino15 ($SIZE)"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf ~/.arduino15
        echo "✅ Removed ~/.arduino15"
    else
        echo "⏭️  Skipped"
    fi
else
    echo "ℹ️  ~/.arduino15 not found"
fi

echo ""
echo "✅ Arduino CLI removal complete!"
echo ""
echo "Note: Shell aliases in ~/.zshrc were not removed."
echo "      Edit ~/.zshrc manually if you want to remove them."
echo ""
echo "Note: Arduino projects in ~/_playground/arduino/ were not removed."
echo "      Remove them manually if desired."

