#!/usr/bin/env bash
# Bootstrap Rust/Cargo installation for system restore
# Installs Rust toolchain using rustup

set -e

echo "🦀 Bootstrapping Rust installation..."

# Check if Rust is already installed
if command -v rustc &> /dev/null && command -v cargo &> /dev/null; then
    RUST_VERSION=$(rustc --version)
    CARGO_VERSION=$(cargo --version)
    echo "✅ Rust is already installed:"
    echo "   $RUST_VERSION"
    echo "   $CARGO_VERSION"
    
    read -p "Reinstall anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Installation cancelled"
        exit 0
    fi
fi

# Create downloads directory if it doesn't exist
mkdir -p /home/pi/Downloads/curls

# Download rustup installer
echo "📥 Downloading rustup installer..."
curl -o /home/pi/Downloads/curls/rustup-init.sh https://sh.rustup.rs

# Run installer (non-interactive)
echo "📦 Installing Rust toolchain..."
bash /home/pi/Downloads/curls/rustup-init.sh -y

# Source cargo environment
echo "🔄 Loading Rust environment..."
source "$HOME/.cargo/env"

# Verify installation
echo ""
echo "✅ Rust installation complete!"
rustc --version
cargo --version

echo ""
echo "📝 Note: Add the following to your ~/.zshrc or ~/.bashrc if not already present:"
echo "   source \"\$HOME/.cargo/env\""
echo ""
echo "🔄 Restart your shell or run: source ~/.cargo/env"

