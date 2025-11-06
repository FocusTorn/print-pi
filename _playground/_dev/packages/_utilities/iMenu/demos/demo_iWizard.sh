#!/usr/bin/env bash
# Demo script showcasing iWizard - Multi-step wizard system
# Demonstrates dynamic message accumulation and step transitions

source "$(dirname "$0")/../iMenu.sh"

# Define wizard steps
step1=(
    "multiselect"
    "ℹ️  Which services would you like to install?"
    "Sensor readings"
    "IAQ (Air quality calculation, Safe to open flag)"
    "Heat soak detection (Current enclosure temp, target enclosure temp, Rate of change)"
)

step2=(
    "select"
    "ℹ️  Which installation method would you like to use?"
    "Standalone MQTT"
    "HA MQTT Receipt"
    "HA Custom Integration"
)

step3=(
    "text"
    "ℹ️  Enter MQTT broker address:"
    "--initial" "localhost:1883"
)

step4=(
    "number"
    "ℹ️  Enter MQTT port:"
    "1883"
    "--min" "1"
    "--max" "65535"
)

step5=(
    "toggle"
    "ℹ️  Enable debug logging?"
    "false"
)

step6=(
    "confirm"
    "ℹ️  Ready to proceed with installation?"
    "false"
)

# Run the wizard
printf '\n' >&2
echo -e "${CYAN}Starting iWizard Demo...${NC}" >&2
printf '\n' >&2

final_result=$(iwizard_run "Service Installation Wizard" step1 step2 step3 step4 step5 step6)
wizard_exit=$?

if [ $wizard_exit -eq 0 ]; then
    printf '\n' >&2
    echo -e "${GREEN}✅ Wizard completed successfully!${NC}" >&2
    printf '\n' >&2
    echo "Final result from last step:" >&2
    echo "  $final_result" >&2
    printf '\n' >&2
    echo "All responses are stored in _IMENU_RESPONSES_MAP:" >&2
    for key in "${!_IMENU_RESPONSES_MAP[@]}"; do
        echo "  $key: ${_IMENU_RESPONSES_MAP[$key]}" >&2
    done
else
    printf '\n' >&2
    echo -e "${YELLOW}⚠️  Wizard cancelled${NC}" >&2
fi
