#!/bin/bash

# Network connectivity LED blinker - ONE-TIME BOOT INDICATOR
# Alternates between ACT and PWR LEDs 10 times, then exits

ACT_LED="/sys/class/leds/ACT"
PWR_LED="/sys/class/leds/PWR"

# Save the original LED triggers
ACT_ORIGINAL_TRIGGER=$(cat "$ACT_LED/trigger" | grep -o '\[.*\]' | tr -d '[]')
PWR_ORIGINAL_TRIGGER=$(cat "$PWR_LED/trigger" | grep -o '\[.*\]' | tr -d '[]')

# Function to restore LEDs to normal operation
restore_leds() {
    echo "$ACT_ORIGINAL_TRIGGER" > "$ACT_LED/trigger"
    echo "$PWR_ORIGINAL_TRIGGER" > "$PWR_LED/trigger"
    echo "LEDs restored to normal operation"
    echo "  ACT trigger: $ACT_ORIGINAL_TRIGGER"
    echo "  PWR trigger: $PWR_ORIGINAL_TRIGGER"
}

# Function to alternating blink both LEDs
alternating_blink() {
    local times=$1
    local duration=$2
    
    # Take control of both LEDs
    echo none > "$ACT_LED/trigger"
    echo none > "$PWR_LED/trigger"
    
    for ((i=1; i<=times; i++)); do
        # ACT on, PWR off
        echo 1 > "$ACT_LED/brightness"
        echo 0 > "$PWR_LED/brightness"
        sleep "$duration"
        
        # ACT off, PWR on
        echo 0 > "$ACT_LED/brightness"
        echo 1 > "$PWR_LED/brightness"
        sleep "$duration"
    done
    
    # Turn both off at the end
    echo 0 > "$ACT_LED/brightness"
    echo 0 > "$PWR_LED/brightness"
}

# Function to check internet connectivity
check_internet() {
    # Try multiple methods for better reliability
    if ping -c 1 -W 3 8.8.8.8 &> /dev/null || \
       ping -c 1 -W 3 1.1.1.1 &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Main execution - check every second until internet found
echo "Waiting for internet connectivity..."
while true; do
    if check_internet; then
        # Internet verified - alternating blink 10 times
        echo "Internet verified - alternating ACT/PWR LEDs 10 times"
        alternating_blink 10 0.25
        
        # Restore both LEDs to normal operation
        restore_leds
        
        # Exit - job done!
        echo "Network-blink service complete. Exiting."
        exit 0
    else
        # No internet yet - wait 1 second and try again
        sleep 1
    fi
done
