#!/usr/bin/env bash
# iPrompt - Single prompt abstraction layer
# Provides a unified interface for running individual prompts
# Used by iWizard and can be used directly for single prompts

# Usage:
#   local step=("multiselect" "Message" "Option 1" "Option 2")
#   iprompt_run step
#
# Or with array directly:
#   iprompt_run "step_name" "multiselect" "Message" "Option 1" "Option 2"

# Run a single prompt from a step array
# Arguments: step_array_name OR name type message [options...]
iprompt_run() {
    local step_array
    local step_type
    local step_message
    local step_options
    
    # Check if first argument is an array name (reference) or prompt type
    if [ $# -eq 1 ]; then
        # Single argument - assume it's an array reference
        local step_ref="$1"
        eval "step_array=(\"\${${step_ref}[@]}\")"
        step_type="${step_array[0]}"
        step_message="${step_array[1]}"
        step_options=("${step_array[@]:2}")
    else
        # Multiple arguments - assume direct call: name type message options...
        local name="$1"
        shift
        step_type="$1"
        shift
        step_message="$1"
        shift
        step_options=("$@")
        # Use name as first element for result storage
        step_array=("$step_type" "$step_message" "${step_options[@]}")
    fi
    
    # Extract flags from options
    local preselect_indices=""
    local parsed_options=()
    local i
    local skip_indices=()
    
    for ((i=0; i<${#step_options[@]}; i++)); do
        if [ "${step_options[i]}" = "--preselect" ]; then
            preselect_indices="${step_options[i+1]}"
            skip_indices+=("$i" "$((i+1))")
            ((i++))
        elif [ "${step_options[i]}" = "--message" ]; then
            step_message="${step_options[i+1]}"
            skip_indices+=("$i" "$((i+1))")
            ((i++))
        elif [ "${step_options[i]}" = "--limit" ]; then
            export IMENU_LIMIT="${step_options[i+1]}"
            skip_indices+=("$i" "$((i+1))")
            ((i++))
        elif [ "${step_options[i]}" = "--initial" ]; then
            export IMENU_INITIAL="${step_options[i+1]}"
            skip_indices+=("$i" "$((i+1))")
            ((i++))
        elif [ "${step_options[i]}" = "--min" ]; then
            export IMENU_MIN="${step_options[i+1]}"
            skip_indices+=("$i" "$((i+1))")
            ((i++))
        elif [ "${step_options[i]}" = "--max" ]; then
            export IMENU_MAX="${step_options[i+1]}"
            skip_indices+=("$i" "$((i+1))")
            ((i++))
        fi
    done
    
    # Re-pack array excluding skipped indices
    for ((i=0; i<${#step_options[@]}; i++)); do
        local should_skip=false
        for skip_idx in "${skip_indices[@]}"; do
            if [ "$i" -eq "$skip_idx" ]; then
                should_skip=true
                break
            fi
        done
        if [ "$should_skip" != true ]; then
            parsed_options+=("${step_options[i]}")
        fi
    done
    step_options=("${parsed_options[@]}")
    
    # Apply preselection if provided
    if [ -n "$preselect_indices" ]; then
        export IMENU_INITIAL="$preselect_indices"
    fi
    
    # Get prompt name (use step type if not provided)
    local prompt_name="${name:-${step_type}}"
    
    # Apply preset configuration based on prompt type
    case "$step_type" in
        text|password|invisible|number|list|date)
            # Input prompts: no blank after message
            imenu_config_preset "input"
            ;;
        multiselect|select|confirm|toggle|autocomplete)
            # Selection prompts: blank after message, gap before options
            imenu_config_preset "selection"
            ;;
    esac
    
    # Call appropriate prompt function based on type
    local result=""
    local exit_code=0
    
    case "$step_type" in
        text)
            result=$(imenu_text "$prompt_name" "$step_message" "${step_options[0]:-}" "${step_options[1]:-}" "${step_options[2]:-}" "${step_options[3]:-}")
            exit_code=$?
            ;;
        password)
            result=$(imenu_password "$prompt_name" "$step_message" "${step_options[0]:-}" "${step_options[1]:-}" "${step_options[2]:-}")
            exit_code=$?
            ;;
        invisible)
            result=$(imenu_invisible "$prompt_name" "$step_message" "${step_options[0]:-}" "${step_options[1]:-}" "${step_options[2]:-}")
            exit_code=$?
            ;;
        number)
            # Use IMENU_INITIAL if set, otherwise use first option, otherwise empty
            local number_initial="${IMENU_INITIAL:-${step_options[0]:-}}"
            result=$(imenu_number "$prompt_name" "$step_message" "$number_initial" "${step_options[1]:-}" "${step_options[2]:-}" "${step_options[3]:-}" "${step_options[4]:-}")
            exit_code=$?
            ;;
        confirm)
            result=$(imenu_confirm "$prompt_name" "$step_message" "${step_options[0]:-false}" "${step_options[1]:-}")
            exit_code=$?
            ;;
        list)
            result=$(imenu_list "$prompt_name" "$step_message" "${step_options[0]:-}" "${step_options[1]:-,}" "${step_options[2]:-}")
            exit_code=$?
            ;;
        toggle)
            result=$(imenu_toggle "$prompt_name" "$step_message" "${step_options[0]:-false}" "${step_options[1]:-Yes}" "${step_options[2]:-No}")
            exit_code=$?
            ;;
        select)
            result=$(imenu_select "$prompt_name" "$step_message" "${step_options[@]}")
            exit_code=$?
            ;;
        multiselect)
            result=$(imenu_multiselect "$prompt_name" "$step_message" "${step_options[@]}")
            exit_code=$?
            ;;
        autocomplete)
            result=$(imenu_autocomplete "$prompt_name" "$step_message" "${step_options[@]}")
            exit_code=$?
            ;;
        date)
            result=$(imenu_date "$prompt_name" "$step_message" "${step_options[0]:-}" "${step_options[1]:-YYYY-MM-DD HH:mm:ss}" "${step_options[2]:-}" "${step_options[3]:-}")
            exit_code=$?
            ;;
        *)
            echo "Unknown prompt type: $step_type" >&2
            return 1
            ;;
    esac
    
    # Clean up environment variables
    unset IMENU_INITIAL IMENU_LIMIT IMENU_MIN IMENU_MAX
    
    # Reset only the spacing config flags that iPrompt sets
    # Don't reset HAS_BACK or CLEAR_PREVIOUS as they may be set by iWizard
    unset IMENU_NO_MESSAGE_BLANK IMENU_MESSAGE_OPTIONS_GAP
    
    # Return result
    if [ $exit_code -eq 0 ]; then
        echo "$result"
        return 0
    else
        return $exit_code
    fi
}

