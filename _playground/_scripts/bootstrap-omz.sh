#!/usr/bin/env bash
# Bootstrap Oh-My-Zsh installation for system restore
# This script installs OMZ from scratch and symlinks custom configs from _playground

set -e

CUSTOM_DIR="$HOME/_playground/zsh/custom"

echo "🚀 Bootstrapping Oh-My-Zsh installation..."

# Verify custom directory exists (should be in repo)
if [ ! -d "$CUSTOM_DIR" ]; then
    echo "❌ Error: Custom directory not found at $CUSTOM_DIR"
    echo "   Make sure you've cloned the restore repo properly!"
    exit 1
fi

# Check if OMZ is already installed
if [ -d "$HOME/.oh-my-zsh" ]; then
    echo "⚠️  Oh-My-Zsh already exists at ~/.oh-my-zsh"
    read -p "Remove and reinstall? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Removing existing installation..."
        rm -rf "$HOME/.oh-my-zsh"
    else
        echo "❌ Installation cancelled"
        exit 0
    fi
fi

# Install Oh-My-Zsh
echo "📥 Installing Oh-My-Zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Remove the default custom directory and replace with symlink
echo "🔗 Setting up custom directory symlink..."
rm -rf "$HOME/.oh-my-zsh/custom"
ln -s "$CUSTOM_DIR" "$HOME/.oh-my-zsh/custom"

# Remove git tracking and contributor cruft to keep it clean
echo "🧹 Cleaning up unnecessary files..."
rm -rf "$HOME/.oh-my-zsh/.git"
rm -rf "$HOME/.oh-my-zsh/.github"
rm -f "$HOME/.oh-my-zsh/"{CODE_OF_CONDUCT,CONTRIBUTING,SECURITY}.md
rm -f "$HOME/.oh-my-zsh/README.md"

# Verify setup
echo ""
echo "✅ Oh-My-Zsh installation complete!"
echo "📁 Custom directory: $CUSTOM_DIR"
echo "🔗 Symlink: ~/.oh-my-zsh/custom -> $CUSTOM_DIR"
ls -la "$HOME/.oh-my-zsh/custom"
echo ""
echo "⚙️  Make sure your .zshrc is properly configured"

