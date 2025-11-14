#!/usr/bin/env bash
# iWizard - Multi-step wizard system
# Main entry point for wizard functionality

# Get directory of this script
_IWIZARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_IMENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source core modules
source "${_IMENU_DIR}/core/colors.sh"
source "${_IMENU_DIR}/core/terminal.sh"
source "${_IMENU_DIR}/core/utils.sh"
source "${_IMENU_DIR}/core/state.sh"
source "${_IMENU_DIR}/core/header.sh"

# Source iPrompt (which sources _prompts)
source "${_IMENU_DIR}/iPrompt/iPrompt.sh"

# Source wizard core modules
source "${_IWIZARD_DIR}/core/wizard-display.sh"
source "${_IWIZARD_DIR}/core/wizard-data.sh"
source "${_IWIZARD_DIR}/core/wizard-orchestrator.sh"

# Convenience function for inline JSON configuration
# Usage: iwizard_run_inline '{"title": "...", "steps": [...]}'
# Or with a variable:
#   local config='{"title": "...", "steps": [...]}'
#   results=$(iwizard_run_inline "$config")
# 
# This function handles ESC and Ctrl+C exits the same way as iwizard_run_json
iwizard_run_inline() {
    local json_string="$1"
    if [ -z "$json_string" ]; then
        echo "Error: JSON string is required" >&2
        return 1
    fi
    # Call iwizard_run_json with the JSON string
    # This will handle all signal trapping, cleanup, and exit codes properly
    iwizard_run_json "$json_string"
    return $?  # Explicitly return the exit code
}

# Clean up temporary variables (keep _IMENU_DIR for cleanup in iMenu.sh)
unset _IWIZARD_DIR

