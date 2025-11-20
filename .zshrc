
##> Path to your Oh My Zsh installation.
 #
 # If you come from bash you might have to change your $PATH.
 # export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
 #<
export ZSH="$HOME/.oh-my-zsh" 

# ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
# │                                             THEME                                              │
# └────────────────────────────────────────────────────────────────────────────────────────────────┘

##> Set name of the theme to load
 #
 # If set to "random", it will load a random theme each time Oh My Zsh is loaded
 # To know which specific one was loaded, run: echo $RANDOM_THEME
 # 
 # See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
 #<
ZSH_THEME="focused"

##> Set list of themes to pick from when loading at random 
 #
 # Setting this variable when ZSH_THEME=random will cause zsh to load
 # a theme from this variable instead of looking in $ZSH/themes/
 # If set to an empty array, this variable will have no effect.
 #
 #<
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
# │                                           COMPLETION                                           │
# └────────────────────────────────────────────────────────────────────────────────────────────────┘

# CASE_SENSITIVE="true" # case-sensitive completion 

##>
 # Uncomment the following line to use hyphen-insensitive completion.
 # Case-sensitive completion must be off. _ and - will be interchangeable.
 #<
# HYPHEN_INSENSITIVE="true"




# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

##> Change the command execution time stamp shown in the history command output.
 #
 # You can set one of the optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
 # 
 # or set a custom format using the strftime function format specifications,
 # see 'man strftime' for details.
 ##<
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

##>
 # Which plugins would you like to load?
 # Standard plugins can be found in $ZSH/plugins/
 # Custom plugins may be added to $ZSH_CUSTOM/plugins/
 # Example format: plugins=(rails git textmate ruby lighthouse)
 # Add wisely, as too many plugins slow down shell startup.
 #<
plugins=( #>
  aliases
  debian
  git
  git-prompt
  python
  pip
  pyenv
  virtualenv
  sudo
  colored-man-pages
  command-not-found
  extract
  copypath
  zsh-autosuggestions
  zsh-syntax-highlighting
) #<

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
# │                                        ARDUINO ALIASES                                          │
# └────────────────────────────────────────────────────────────────────────────────────────────────┘

# ESP32-S3 helper scripts directory
ESP32_SCRIPTS="$HOME/_playground/arduino/esp32-s3/_scripts"

# Fast Arduino compilation (uses all CPU cores)
alias arduino-compile-fast='arduino-cli compile -j $(nproc)'

# ESP32-S3 shortcuts
alias esp32-build='$ESP32_SCRIPTS/esp32-build.sh'
alias esp32-compile='arduino-cli compile -j $(nproc) --fqbn esp32:esp32:esp32s3'
alias esp32-upload='$ESP32_SCRIPTS/esp32-build.sh .'
alias esp32-monitor='arduino-cli monitor -p $($ESP32_SCRIPTS/esp32-detect-port.sh) --config baudrate=115200'
alias esp32-new='$ESP32_SCRIPTS/esp32-new-project.sh'
alias esp32-port='$ESP32_SCRIPTS/esp32-detect-port.sh'

# ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
# │                                            USB COMMAND                                          │
# └────────────────────────────────────────────────────────────────────────────────────────────────┘

# USB Command
# Unified USB management command with subcommands
# Usage: usb <command>
#   reset   - Reset all USB ports
#   monitor - Monitor USB devices and serial ports
#   list    - List current USB devices
#   status  - Show USB system status
#   help    - Show this help message
usb() {
    local cmd="${1:-help}"
    
    case "$cmd" in
        reset)
            echo "🔄 Resetting USB subsystem..."
            
            # Check if running as root (needed for USB port control)
            if [[ $EUID -ne 0 ]]; then
                echo "⚠️  This function requires sudo privileges"
                echo "   Disabling USB ports..."
                for port in /sys/bus/usb/devices/usb*/authorized; do
                    echo 0 | sudo tee "$port" > /dev/null 2>&1
                done
                
                echo "   Waiting 2 seconds..."
                sleep 2
                
                echo "   Re-enabling USB ports..."
                for port in /sys/bus/usb/devices/usb*/authorized; do
                    echo 1 | sudo tee "$port" > /dev/null 2>&1
                done
                
                sleep 2
            else
                # If running as root (not recommended, but handle it)
                for port in /sys/bus/usb/devices/usb*/authorized; do
                    echo 0 > "$port" 2>/dev/null
                done
                sleep 2
                for port in /sys/bus/usb/devices/usb*/authorized; do
                    echo 1 > "$port" 2>/dev/null
                done
                sleep 2
            fi
            
            echo "✅ USB ports reset complete"
            echo ""
            echo "Current USB devices:"
            lsusb
            echo ""
            echo "💡 Tip: Plug in your device now and check with: usb list"
            ;;
            
        monitor)
            echo "📡 Starting USB monitoring (Press Ctrl+C to stop)..."
            echo ""
            while true; do
                clear
                echo "=== USB Device Monitor ==="
                echo "Time: $(date '+%H:%M:%S')"
                echo ""
                echo "USB Devices:"
                lsusb
                echo ""
                echo "Serial Devices (all types):"
                # Check all common serial device types
                local serial_devices=""
                local old_nullglob=$(setopt | grep -q "nullglob" && echo "on" || echo "off")
                setopt nullglob  # Don't error on unmatched globs
                for pattern in /dev/ttyUSB* /dev/ttyACM* /dev/ttyS* /dev/ttyAMA*; do
                    if [[ -e "$pattern" ]]; then
                        serial_devices="$serial_devices $pattern"
                    fi
                done
                [[ "$old_nullglob" == "off" ]] && unsetopt nullglob  # Restore original setting
                if [[ -n "$serial_devices" ]]; then
                    ls -la $serial_devices 2>/dev/null
                else
                    echo "  No serial devices found"
                fi
                echo ""
                echo "USB Serial Devices (from sysfs):"
                if [[ -d /sys/bus/usb-serial/devices ]]; then
                    ls -la /sys/bus/usb-serial/devices/ 2>/dev/null | grep -v "^total" || echo "  No USB serial devices in sysfs"
                else
                    echo "  /sys/bus/usb-serial/devices not found"
                fi
                echo ""
                echo "All TTY Devices (USB-related):"
                for tty_dir in /sys/class/tty/*; do
                    if [[ -L "$tty_dir/device" ]]; then
                        device_link=$(readlink "$tty_dir/device" 2>/dev/null)
                        if echo "$device_link" | grep -qi usb; then
                            tty_name=$(basename "$tty_dir")
                            echo "  /dev/$tty_name -> $device_link"
                        fi
                    fi
                done | head -10 || echo "  No USB TTY devices found"
                echo ""
                echo "Recent USB Events (last 5):"
                dmesg | tail -20 | grep -i "usb\|tty\|cdc\|acm\|ch340\|ch341" | tail -5 || echo "  No recent USB events"
                echo ""
                echo "Press Ctrl+C to stop monitoring"
                sleep 2
            done
            ;;
            
        list)
            echo "=== USB Devices ==="
            lsusb
            echo ""
            echo "=== Serial Devices (all types) ==="
            local serial_devices=""
            local old_nullglob=$(setopt | grep -q "nullglob" && echo "on" || echo "off")
            setopt nullglob  # Don't error on unmatched globs
            for pattern in /dev/ttyUSB* /dev/ttyACM* /dev/ttyS* /dev/ttyAMA*; do
                if [[ -e "$pattern" ]]; then
                    serial_devices="$serial_devices $pattern"
                fi
            done
            [[ "$old_nullglob" == "off" ]] && unsetopt nullglob  # Restore original setting
            if [[ -n "$serial_devices" ]]; then
                ls -la $serial_devices 2>/dev/null
            else
                echo "No serial devices found"
            fi
            echo ""
            echo "=== USB Serial Devices (sysfs) ==="
            if [[ -d /sys/bus/usb-serial/devices ]]; then
                ls -la /sys/bus/usb-serial/devices/ 2>/dev/null | grep -v "^total" || echo "No USB serial devices in sysfs"
            else
                echo "/sys/bus/usb-serial/devices not found"
            fi
            ;;
            
        status)
            echo "=== USB System Status ==="
            echo ""
            echo "USB Devices:"
            lsusb
            echo ""
            echo "Loaded USB Drivers:"
            lsmod | grep -E "usb|cdc|acm|ch340|ch341" | head -10
            echo ""
            echo "Serial Devices (all types):"
            local serial_devices=""
            local old_nullglob=$(setopt | grep -q "nullglob" && echo "on" || echo "off")
            setopt nullglob  # Don't error on unmatched globs
            for pattern in /dev/ttyUSB* /dev/ttyACM* /dev/ttyS* /dev/ttyAMA*; do
                if [[ -e "$pattern" ]]; then
                    serial_devices="$serial_devices $pattern"
                fi
            done
            [[ "$old_nullglob" == "off" ]] && unsetopt nullglob  # Restore original setting
            if [[ -n "$serial_devices" ]]; then
                ls -la $serial_devices 2>/dev/null
            else
                echo "No serial devices found"
            fi
            echo ""
            echo "USB Serial Devices (sysfs):"
            if [[ -d /sys/bus/usb-serial/devices ]]; then
                ls -la /sys/bus/usb-serial/devices/ 2>/dev/null | grep -v "^total" || echo "No USB serial devices in sysfs"
            fi
            echo ""
            echo "Recent USB Events:"
            dmesg | tail -10 | grep -i "usb\|tty\|cdc\|acm\|ch340\|ch341" || echo "No recent USB events"
            ;;
            
        help|--help|-h)
            echo "USB Management Command"
            echo ""
            echo "Usage: usb <command>"
            echo ""
            echo "Commands:"
            echo "  reset    Reset all USB ports (clears stuck states)"
            echo "  monitor  Continuously monitor USB devices and serial ports"
            echo "  list     List current USB devices and serial ports"
            echo "  status   Show USB system status (devices, drivers, events)"
            echo "  help     Show this help message"
            echo ""
            echo "Examples:"
            echo "  usb reset      - Reset USB ports"
            echo "  usb monitor    - Start monitoring"
            echo "  usb list       - List devices"
            echo "  usb status     - Show system status"
            ;;
            
        *)
            echo "❌ Unknown command: $cmd"
            echo ""
            echo "Run 'usb help' for usage information"
            return 1
            ;;
    esac
}

# ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
# │                                        ESP-IDF SETUP                                            │
# └────────────────────────────────────────────────────────────────────────────────────────────────┘

# ESP-IDF environment
if [ -f "$HOME/esp/esp-idf/export.sh" ]; then
    alias get_idf='. $HOME/esp/esp-idf/export.sh'
    # Uncomment the line below to auto-load ESP-IDF in every shell (slower startup)
    # . $HOME/esp/esp-idf/export.sh
fi

# ESP-IDF Development Menu (ed) - Function wrapper to allow sourcing
ed() {
    local ed_script="$HOME/_playground/espidf/_scripts/_ed-bin.sh"
    if [ -f "$ed_script" ]; then
        # Source the script so it can modify the current shell environment
        source "$ed_script" "$@"
    else
        # Fallback to script execution if function version not found
        "$HOME/.local/bin/ed" "$@"
    fi
}
