#!/usr/bin/env bash
# iMenu Core - Header and Keybindings

# Generate keybindings string based on prompt type and context
_imenu_get_keybindings() {
    local prompt_type="$1"
    local has_back="${2:-false}"
    
    local bindings=()
    
    # Type-specific bindings first
    case "$prompt_type" in
        multiselect)
            bindings+=("[Space] Toggle")
            bindings+=("[a] Toggle All")
            bindings+=("[↕] Navigate")
            ;;
        select)
            bindings+=("[↕] Navigate")
            ;;
        confirm)
            bindings+=("[y] Yes")
            bindings+=("[n] No")
            ;;
        toggle)
            bindings+=("[Space] Toggle")
            bindings+=("[↕] Navigate")
            ;;
        autocomplete)
            bindings+=("[↕] Navigate")
            ;;
        text|password|invisible|number|list|date)
            # These types don't have special navigation bindings
            ;;
    esac
    
    # Common bindings for all types
    bindings+=("[Enter] Confirm")
    bindings+=("[Esc] Cancel")
    
    # Back button if in substep
    if [ "$has_back" = "true" ]; then
        bindings+=("[b] Back")
    fi
    
    # Join with separator
    local IFS=' 🞜 '
    echo "${bindings[*]}"
}

# Print header with title only (keybindings printed in loop)
_imenu_print_header() {
    local title="$1"
    
    if [ -n "$title" ]; then
        printf '\n' >&2
        printf '%b════════════════════════════════════════%b\n' "${CYAN}" "${NC}" >&2
        printf '%b  %s%b\n' "${CYAN}" "$title" "${NC}" >&2
        printf '%b════════════════════════════════════════%b\n' "${CYAN}" "${NC}" >&2
        printf '\n' >&2
    fi
}

