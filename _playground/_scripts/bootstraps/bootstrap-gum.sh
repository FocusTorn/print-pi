#!/usr/bin/env bash
# Bootstrap GUM (Charm) installation for system restore
# Installs GUM interactive shell tool via APT repository
# https://github.com/charmbracelet/gum

set -e

echo "💄 Bootstrapping GUM (Charm) installation..."

# Check if GUM is already installed
GUM_INSTALLED=false
GUM_LOCATION=""
if command -v gum &> /dev/null; then
    GUM_LOCATION=$(which gum)
    GUM_VERSION=$(gum --version)
    
    # Check if installed via APT
    if dpkg -l | grep -q "^ii.*gum"; then
        echo "✅ GUM is already installed via APT: $GUM_VERSION"
        echo "   Location: $GUM_LOCATION"
        GUM_INSTALLED=true
    else
        # Manually installed (likely in ~/.local/bin/)
        echo "⚠️  GUM is installed manually: $GUM_VERSION"
        echo "   Location: $GUM_LOCATION"
        echo "   This appears to be a manual installation, not APT-managed"
        
        read -p "Remove manual installation and install via APT? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            echo "❌ Installation cancelled"
            exit 0
        fi
        
        # Remove manually installed GUM
        echo "🗑️  Removing manually installed GUM..."
        rm -f "$GUM_LOCATION"
        echo "✅ Removed: $GUM_LOCATION"
    fi
fi

# If already installed via APT, ask if user wants to reinstall
if [ "$GUM_INSTALLED" = true ]; then
    read -p "Reinstall anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Installation cancelled"
        exit 0
    fi
fi

# Check if Charm repository is already configured
CHARM_KEYRING="/etc/apt/keyrings/charm.gpg"
CHARM_SOURCE="/etc/apt/sources.list.d/charm.list"

if [ -f "$CHARM_KEYRING" ] && [ -f "$CHARM_SOURCE" ]; then
    echo "✅ Charm repository already configured"
else
    echo "📥 Setting up Charm APT repository..."
    
    # Create keyring directory
    sudo mkdir -p /etc/apt/keyrings
    
    # Download and add GPG key
    echo "🔑 Adding Charm GPG key..."
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o "$CHARM_KEYRING"
    
    # Add repository
    echo "📦 Adding Charm repository..."
    echo "deb [signed-by=$CHARM_KEYRING] https://repo.charm.sh/apt/ * *" | sudo tee "$CHARM_SOURCE" > /dev/null
    
    echo "✅ Charm repository configured"
fi

# Update package list
echo "🔄 Updating package list..."
sudo apt update

# Install GUM
echo "📦 Installing GUM..."
sudo apt install -y gum

# Verify installation
echo ""
echo "✅ GUM installation complete!"
echo ""

if command -v gum &> /dev/null; then
    GUM_VERSION=$(gum --version)
    echo "📊 Installed version: $GUM_VERSION"
    echo ""
    echo "🚀 Quick test:"
    echo "   gum style --foreground 212 --bold 'GUM is working!'"
    echo ""
    echo "📖 Usage examples:"
    echo "   # Interactive input"
    echo "   name=\$(gum input --placeholder 'Enter your name')"
    echo ""
    echo "   # Confirmation"
    echo "   gum confirm 'Continue?' && echo 'Yes!' || echo 'No'"
    echo ""
    echo "   # Choose from options"
    echo "   choice=\$(gum choose 'Option 1' 'Option 2' 'Option 3')"
    echo ""
    echo "   # Spinner"
    echo "   gum spin --spinner dot --title 'Loading...' -- sleep 5"
    echo ""
    echo "📚 Documentation: https://github.com/charmbracelet/gum"
    echo "📍 Binary location: $(which gum)"
    echo ""
    echo "🔄 Updates: GUM will be updated automatically via 'sudo apt upgrade'"
else
    echo "❌ GUM installation failed"
    exit 1
fi

