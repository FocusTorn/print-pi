#!/usr/bin/env bash
# Bootstrap Snake Pit Python ecosystem for system restore
# Installs uv package manager and sets up snake-pit environment

set -e

echo "🐍 Bootstrapping Snake Pit Python ecosystem..."

# Check if uv is already installed
if command -v uv &> /dev/null; then
    UV_VERSION=$(uv --version)
    echo "✅ uv is already installed: $UV_VERSION"
    
    read -p "Reinstall anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Installation cancelled"
        exit 0
    fi
fi

# Check if snake-pit directory exists
SNAKE_PIT_DIR="${HOME}/_playground/snake-pit"
if [ ! -d "$SNAKE_PIT_DIR" ]; then
    echo "❌ snake-pit directory not found at: $SNAKE_PIT_DIR"
    echo "   Please ensure _playground repository is cloned first"
    exit 1
fi

# Create downloads directory if it doesn't exist
mkdir -p /home/pi/Downloads/curls

# Download uv installer
echo "📥 Downloading uv installer..."
curl -o /home/pi/Downloads/curls/uv-install.sh -LsSf https://astral.sh/uv/install.sh

# Run installer (non-interactive)
echo "📦 Installing uv..."
bash /home/pi/Downloads/curls/uv-install.sh

# Source uv environment if it exists
if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi

# Verify uv is in PATH
if ! command -v uv &> /dev/null; then
    echo "⚠️  uv not in PATH. Adding to ~/.cargo/env..."
    source "$HOME/.cargo/env" 2>/dev/null || true
fi

# Verify installation
echo ""
echo "✅ uv installation complete!"
uv --version

# Navigate to snake-pit
cd "$SNAKE_PIT_DIR"

# Create virtual environment if it doesn't exist
if [ ! -d ".venv" ]; then
    echo "🐍 Creating snake-pit virtual environment..."
    uv venv
fi

# Check for requirements.txt
if [ -f "requirements.txt" ]; then
    echo "📦 Installing requirements from requirements.txt..."
    uv pip install -r requirements.txt
fi

echo ""
echo "✅ Snake Pit setup complete!"
echo ""
echo "📍 Location: $SNAKE_PIT_DIR"
echo "🐍 Virtual environment: $SNAKE_PIT_DIR/.venv"
echo ""
echo "🚀 Quick start:"
echo "   cd $SNAKE_PIT_DIR"
echo "   uv run python projects/bme680-monitor/monitor.py"
echo ""
echo "📝 To add packages:"
echo "   cd $SNAKE_PIT_DIR"
echo "   uv pip install <package>"
echo "   uv pip freeze > requirements.txt"

