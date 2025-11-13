#!/usr/bin/env bash
# iMenu - Main Loader
# Sources all core modules and prompt types

# Get directory of this script
_IMENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source core modules
source "${_IMENU_DIR}/config.sh"
source "${_IMENU_DIR}/core/colors.sh"
source "${_IMENU_DIR}/core/state.sh"
source "${_IMENU_DIR}/core/terminal.sh"
source "${_IMENU_DIR}/core/utils.sh"
source "${_IMENU_DIR}/core/header.sh"

# Source prompt types
source "${_IMENU_DIR}/prompts/multiselect.sh"
source "${_IMENU_DIR}/prompts/select.sh"
source "${_IMENU_DIR}/prompts/toggle.sh"
source "${_IMENU_DIR}/prompts/text.sh"
source "${_IMENU_DIR}/prompts/password.sh"
source "${_IMENU_DIR}/prompts/invisible.sh"
source "${_IMENU_DIR}/prompts/number.sh"
source "${_IMENU_DIR}/prompts/confirm.sh"
source "${_IMENU_DIR}/prompts/list.sh"
source "${_IMENU_DIR}/prompts/autocomplete.sh"
source "${_IMENU_DIR}/prompts/date.sh"

# Source iPrompt if it exists
if [ -f "${_IMENU_DIR}/modules/iPrompt.sh" ]; then
    source "${_IMENU_DIR}/modules/iPrompt.sh"
fi

# Source iWizard if it exists
if [ -f "${_IMENU_DIR}/modules/iWizard.sh" ]; then
    source "${_IMENU_DIR}/modules/iWizard.sh"
fi

# Clean up temporary variable
unset _IMENU_DIR
