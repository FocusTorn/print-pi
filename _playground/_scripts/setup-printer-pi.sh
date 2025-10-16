#!/bin/bash

# setup-printer-pi.sh
# Setup script for Cursor IDE access on Raspberry Pi
# Fixes permissions and creates necessary symlinks for remote SSH access

set -e  # Exit on any error

echo "🔧 Setting up Cursor IDE access for Raspberry Pi..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#-->> Print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

#----<<
#-->> Check if running as pi user
if [[ "$(whoami)" != "pi" ]]; then
    print_error "This script must be run as the 'pi' user"
    exit 1
fi

#----<<

srm() {
    sudo rm -rf "$@" 2>/dev/null
}

linkAndVerify() {
    local srcPath="$1"
    local destPath="$2"
    
    srm "$destPath"
    
    sudo ln -sf "$srcPath" "$destPath"
    
    if [[ -L "$destPath" ]]; then
        if [[ -r "$destPath" && -w "$destPath" ]]; then
            print_success "$srcPath --> $destPath symlink is working and writable"
        else
            print_error "$srcPath --> $destPath symlink exists but is not writable"
        fi
    else
        print_error "$srcPath --> $destPath symlink was not created"
    fi
}




# print_status "Running as user: $(whoami)"

#-->> Fix permissions for .cursor directories 

if [[ -d "/home/pi/.cursor" ]]; then
    chmod -R 755 /home/pi/.cursor
    print_success "Fixed permissions for /home/pi/.cursor"
else
    print_warning "/home/pi/.cursor directory not found"
fi

if [[ -d "/home/pi/.cursor-server" ]]; then
    chmod -R 755 /home/pi/.cursor-server
    print_success "Fixed permissions for /home/pi/.cursor-server"
else
    print_warning "/home/pi/.cursor-server directory not found"
fi

#----<<




# Step 2: Create symlinks at root level
print_status "Creating symlinks at root level for Cursor access..."

# Remove existing symlinks if they exist
if [[ -L "/.cursor" ]]; then
    srm /.cursor
fi

if [[ -L "/.cursor-server" ]]; then
    srm /.cursor-server
fi

# Create new symlinks
if [[ -d "/home/pi/.cursor" ]]; then
    sudo ln -sf /home/pi/.cursor /.cursor
    print_success "Created /.cursor -> /home/pi/.cursor symlink"
else
    print_warning "Cannot create /.cursor symlink - source directory doesn't exist"
fi

if [[ -d "/home/pi/.cursor-server" ]]; then
    sudo ln -sf /home/pi/.cursor-server /.cursor-server
    print_success "Created /.cursor-server -> /home/pi/.cursor-server symlink"
else
    print_warning "Cannot create /.cursor-server symlink - source directory doesn't exist"
fi








# Step 3: Verify setup
print_status "Verifying setup..."

if [[ -L "/.cursor" ]]; then
    if [[ -r "/.cursor" && -w "/.cursor" ]]; then
        print_success "/.cursor symlink is working and writable"
    else
        print_error "/.cursor symlink exists but is not writable"
    fi
else
    print_error "/.cursor symlink was not created"
fi

if [[ -L "/.cursor-server" ]]; then
    if [[ -r "/.cursor-server" && -w "/.cursor-server" ]]; then
        print_success "/.cursor-server symlink is working and writable"
    else
        print_error "/.cursor-server symlink exists but is not writable"
    fi
else
    print_error "/.cursor-server symlink was not created"
fi

# Step 4: Test write access
print_status "Testing write access..."

if touch /.cursor/test-write.md 2>/dev/null; then
    rm /.cursor/test-write.md
    print_success "Write test to /.cursor successful"
else
    print_error "Write test to /.cursor failed"
fi

echo ""
print_success "🎉 Cursor IDE setup complete!"
echo ""
echo "Summary:"
echo "  ✓ Fixed permissions for .cursor directories"
echo "  ✓ Created root-level symlinks for remote SSH access"
echo "  ✓ Verified write access"
echo ""
echo "Cursor should now have full read/write access to:"
echo "  • /.cursor (points to /home/pi/.cursor)"
echo "  • /.cursor-server (points to /home/pi/.cursor-server)"
echo ""
print_status "You can now create command files and use Cursor features without permission errors!"








# symlink .vscode to /
# symlink .cusor to /
# symlink .cusor-server to /

# Install ohmyzsh

# curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o /home/pi/Downloads/curls/ohmyzsh-install.sh
# sudo apt update && sudo apt install -y zsh


# git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
# git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
# chsh -s $(which zsh)


# /home/pi/_playground/zsh_custom



# cd ~/.local/share/kiauh && git clone https://github.com/th33xitus/kiauh.git .
# ln -s ~/.local/share/kiauh/kiauh.sh ~/.local/bin/kiauh
# chmod +x ~/.local/share/kiauh/kiauh.sh && chmod +x ~/.local/bin/kiauh

# echo Install Klipper Moonraker and Mainsail



# Init git
# git config --global user.name "FocusTorn"
# git config --global user.email "FocusTorn@gmail.com"
# git config --global --list | grep user