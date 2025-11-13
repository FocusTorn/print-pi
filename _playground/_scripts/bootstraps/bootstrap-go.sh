#!/usr/bin/env bash
# Bootstrap Go installation for system restore
# Installs Go toolchain using official installer

set -e

echo "🐹 Bootstrapping Go installation..."

# Check if Go is already installed
if command -v go &> /dev/null; then
    GO_VERSION=$(go version)
    echo "✅ Go is already installed: $GO_VERSION"
    
    read -p "Reinstall anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Installation cancelled"
        exit 0
    fi
fi

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        GO_ARCH="amd64"
        ;;
    aarch64|arm64)
        GO_ARCH="arm64"
        ;;
    armv7l|armv6l)
        GO_ARCH="armv6l"
        ;;
    *)
        echo "❌ Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Detect OS
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

# Set Go version (latest stable)
GO_VERSION="1.23.4"
GO_TARBALL="go${GO_VERSION}.${OS}-${GO_ARCH}.tar.gz"
GO_URL="https://go.dev/dl/${GO_TARBALL}"

# Create downloads directory if it doesn't exist
mkdir -p /home/pi/Downloads/curls

# Download Go installer
echo "📥 Downloading Go ${GO_VERSION} for ${OS}-${GO_ARCH}..."
curl -o "/home/pi/Downloads/curls/${GO_TARBALL}" -L "${GO_URL}"

# Remove old Go installation if it exists
if [ -d "$HOME/go" ]; then
    echo "🗑️  Removing old Go installation..."
    rm -rf "$HOME/go"
fi

# Install Go
echo "📦 Installing Go to $HOME/go..."
tar -C "$HOME" -xzf "/home/pi/Downloads/curls/${GO_TARBALL}"

# Set up Go environment
GOROOT="$HOME/go"
GOPATH="$HOME/go-workspace"
GOBIN="$GOPATH/bin"

# Create GOPATH directories
mkdir -p "$GOPATH"/{bin,src,pkg}

# Add to PATH in shell config files
echo ""
echo "🔧 Configuring Go environment..."

# Check if already configured
if ! grep -q 'export GOROOT=' ~/.zshrc 2>/dev/null; then
    {
        echo ""
        echo "# Go environment"
        echo "export GOROOT=\"\$HOME/go\""
        echo "export GOPATH=\"\$HOME/go-workspace\""
        echo "export GOBIN=\"\$GOPATH/bin\""
        echo "export PATH=\"\$GOROOT/bin:\$GOBIN:\$PATH\""
    } >> ~/.zshrc
    echo "✅ Added Go configuration to ~/.zshrc"
fi

if ! grep -q 'export GOROOT=' ~/.bashrc 2>/dev/null; then
    {
        echo ""
        echo "# Go environment"
        echo "export GOROOT=\"\$HOME/go\""
        echo "export GOPATH=\"\$HOME/go-workspace\""
        echo "export GOBIN=\"\$GOPATH/bin\""
        echo "export PATH=\"\$GOROOT/bin:\$GOBIN:\$PATH\""
    } >> ~/.bashrc
    echo "✅ Added Go configuration to ~/.bashrc"
fi

# Source the environment for current session
export GOROOT="$HOME/go"
export GOPATH="$HOME/go-workspace"
export GOBIN="$GOPATH/bin"
export PATH="$GOROOT/bin:$GOBIN:$PATH"

# Verify installation
echo ""
echo "✅ Go installation complete!"
go version

echo ""
echo "📝 Go environment variables:"
echo "   GOROOT: $GOROOT"
echo "   GOPATH: $GOPATH"
echo "   GOBIN: $GOBIN"
echo ""
echo "🔄 Restart your shell or run:"
echo "   export GOROOT=\"\$HOME/go\""
echo "   export GOPATH=\"\$HOME/go-workspace\""
echo "   export GOBIN=\"\$GOPATH/bin\""
echo "   export PATH=\"\$GOROOT/bin:\$GOBIN:\$PATH\""

