#!/usr/bin/env bash
# iPrompt - Single prompt wrapper
# Provides a unified interface for running individual prompts
# Used by iWizard and can be used directly for single prompts

# Get directory of this script
_IPROMPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_IMENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source core modules
source "${_IMENU_DIR}/core/colors.sh"
source "${_IMENU_DIR}/core/terminal.sh"
source "${_IMENU_DIR}/core/utils.sh"
source "${_IMENU_DIR}/core/state.sh"
source "${_IMENU_DIR}/core/header.sh"

# Source prompt library
source "${_IMENU_DIR}/_prompts/confirm.sh"
source "${_IMENU_DIR}/_prompts/text.sh"
source "${_IMENU_DIR}/_prompts/multiselect.sh"
source "${_IMENU_DIR}/_prompts/select.sh"
source "${_IMENU_DIR}/_prompts/number.sh"
source "${_IMENU_DIR}/_prompts/list.sh"
source "${_IMENU_DIR}/_prompts/toggle.sh"
source "${_IMENU_DIR}/_prompts/password.sh"
source "${_IMENU_DIR}/_prompts/invisible.sh"
source "${_IMENU_DIR}/_prompts/autocomplete.sh"
source "${_IMENU_DIR}/_prompts/date.sh"

# Source dispatcher
source "${_IPROMPT_DIR}/core/prompt-dispatcher.sh"

# Clean up temporary variables (keep _IMENU_DIR for iWizard)
unset _IPROMPT_DIR

