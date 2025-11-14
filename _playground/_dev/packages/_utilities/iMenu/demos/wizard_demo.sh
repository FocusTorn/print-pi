#!/usr/bin/env bash
# Demo script showcasing iWizard - JSON-based wizard system
# Demonstrates simple usage: results = iwizard_run_json("wizard_input.json")

# Get directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMENU_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source iMenu
source "$IMENU_DIR/iMenu.sh"

# Enable debug mode if IWIZARD_DEBUG is set
# Debug mode pauses after each step clear for inspection
if [ "${IWIZARD_DEBUG:-false}" != "false" ]; then
    echo "Debug mode enabled (IWIZARD_DEBUG=$IWIZARD_DEBUG)" >&2
    echo "Wizard will pause after each step clear - press any key to continue" >&2
    printf '\n' >&2
fi

# Run the wizard from JSON config
echo "Starting wizard..." >&2
results=$(iwizard_run_json "$SCRIPT_DIR/wizard_input.json")
exit_code=$?

if [ $exit_code -eq 0 ]; then
    printf '\n' >&2
    echo -e "${GREEN}✅ Wizard completed successfully!${NC}" >&2
    printf '\n' >&2
    
    # Display results using jq if available
    if command -v jq >/dev/null 2>&1; then
        echo "Results:" >&2
        echo "$results" | jq . >&2
    else
        echo "Results (raw JSON):" >&2
        echo "$results" >&2
    fi
    
    # Example: Parse specific results
    if command -v jq >/dev/null 2>&1; then
        printf '\n' >&2
        echo "Parsed results:" >&2
        step0_result=$(echo "$results" | jq -r '.step0.result // "N/A"')
        step1_result=$(echo "$results" | jq -r '.step1.result // "N/A"')
        echo "  Step 0 result: $step0_result" >&2
        echo "  Step 1 result: $step1_result" >&2
    fi
else
    printf '\n' >&2
    echo -e "${YELLOW}⚠️  Wizard cancelled${NC}" >&2
fi

# Return the results on stdout (for programmatic use)
echo "$results"

exit $exit_code

