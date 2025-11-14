#!/usr/bin/env bash
# iPrompt Core - Prompt Dispatcher
# Handles flag parsing, configuration presets, and function routing

# Run a single prompt
# Arguments: [name] type message [options...] [flags...]
iprompt_run() {
    local name=""
    local step_type=""
    local step_message=""
    local step_options=()
    
    # Parse arguments
    if [ $# -eq 0 ]; then
        echo "Error: iprompt_run requires at least a prompt type" >&2
        return 1
    fi
    
    # Check if first argument is a known prompt type or a name
    local first_arg="$1"
    case "$first_arg" in
        confirm|text|multiselect|select|number|list|toggle|password|invisible|autocomplete|date)
            # First arg is prompt type, no name provided
            step_type="$first_arg"
            shift
            ;;
        *)
            # First arg might be a name, second should be type
            if [ $# -lt 2 ]; then
                echo "Error: Invalid arguments to iprompt_run" >&2
                return 1
            fi
            name="$first_arg"
            step_type="$2"
            shift 2
            ;;
    esac
    
    # Get message (required)
    if [ $# -eq 0 ]; then
        echo "Error: iprompt_run requires a message" >&2
        return 1
    fi
    step_message="$1"
    shift
    
    # Remaining arguments are options/flags
    step_options=("$@")
    
    # Extract flags from options
    local preselect_indices=""
    local initial_value=""
    local min_value=""
    local max_value=""
    local limit_value=""
    local separator_value=""
    local format_value=""
    local parsed_options=()
    local i
    local skip_indices=()
    
    for ((i=0; i<${#step_options[@]}; i++)); do
        if [ "${step_options[i]}" = "--preselect" ]; then
            preselect_indices="${step_options[i+1]}"
            skip_indices+=("$i" "$((i+1))")
            ((i++))
        elif [ "${step_options[i]}" = "--initial" ]; then
            initial_value="${step_options[i+1]}"
            skip_indices+=("$i" "$((i+1))")
            ((i++))
        elif [ "${step_options[i]}" = "--min" ]; then
            min_value="${step_options[i+1]}"
            skip_indices+=("$i" "$((i+1))")
            ((i++))
        elif [ "${step_options[i]}" = "--max" ]; then
            max_value="${step_options[i+1]}"
            skip_indices+=("$i" "$((i+1))")
            ((i++))
        elif [ "${step_options[i]}" = "--limit" ]; then
            limit_value="${step_options[i+1]}"
            skip_indices+=("$i" "$((i+1))")
            ((i++))
        elif [ "${step_options[i]}" = "--separator" ]; then
            separator_value="${step_options[i+1]}"
            skip_indices+=("$i" "$((i+1))")
            ((i++))
        elif [ "${step_options[i]}" = "--format" ]; then
            format_value="${step_options[i+1]}"
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
    
    # Set environment variables for flags
    if [ -n "$preselect_indices" ]; then
        export IMENU_INITIAL="$preselect_indices"
    elif [ -n "$initial_value" ]; then
        export IMENU_INITIAL="$initial_value"
    fi
    
    if [ -n "$min_value" ]; then
        export IMENU_MIN="$min_value"
    fi
    
    if [ -n "$max_value" ]; then
        export IMENU_MAX="$max_value"
    fi
    
    if [ -n "$limit_value" ]; then
        export IMENU_LIMIT="$limit_value"
    fi
    
    # Get prompt name (use step type if not provided)
    local prompt_name="${name:-${step_type}}"
    
    # Apply preset configuration based on prompt type
    case "$step_type" in
        text|password|invisible|number|list|date)
            # Input prompts: no blank after message, inline input
            export IMENU_NO_MESSAGE_BLANK="true"
            export IMENU_INPUT_INLINE="true"
            ;;
        multiselect|select|confirm|toggle|autocomplete)
            # Selection prompts: blank after message, gap before options
            export IMENU_NO_MESSAGE_BLANK="false"
            export IMENU_MESSAGE_OPTIONS_GAP="true"
            ;;
    esac
    
    # Call appropriate prompt function based on type
    local result=""
    local exit_code=0
    
    case "$step_type" in
        text)
            result=$(_prompt_text "$prompt_name" "$step_message" "${step_options[0]:-}" "${step_options[1]:-default}" "${step_options[2]:-}" "${step_options[3]:-}")
            exit_code=$?
            ;;
        password)
            result=$(_prompt_password "$prompt_name" "$step_message" "${step_options[0]:-}" "${step_options[1]:-}" "${step_options[2]:-}")
            exit_code=$?
            ;;
        invisible)
            result=$(_prompt_invisible "$prompt_name" "$step_message" "${step_options[0]:-}" "${step_options[1]:-}" "${step_options[2]:-}")
            exit_code=$?
            ;;
        number)
            result=$(_prompt_number "$prompt_name" "$step_message" "${step_options[0]:-}" "${step_options[1]:-}" "${step_options[2]:-}" "${step_options[3]:-}" "${step_options[4]:-}" "${step_options[5]:-}")
            exit_code=$?
            ;;
        confirm)
            result=$(_prompt_confirm "$prompt_name" "$step_message" "${step_options[0]:-false}" "${step_options[1]:-}")
            exit_code=$?
            ;;
        list)
            result=$(_prompt_list "$prompt_name" "$step_message" "${step_options[0]:-}" "${step_options[1]:-,}" "${step_options[2]:-}")
            exit_code=$?
            ;;
        toggle)
            result=$(_prompt_toggle "$prompt_name" "$step_message" "${step_options[0]:-false}" "${step_options[1]:-Yes}" "${step_options[2]:-No}")
            exit_code=$?
            ;;
        select)
            result=$(_prompt_select "$prompt_name" "$step_message" "${step_options[@]}")
            exit_code=$?
            ;;
        multiselect)
            result=$(_prompt_multiselect "$prompt_name" "$step_message" "${step_options[@]}")
            exit_code=$?
            ;;
        autocomplete)
            result=$(_prompt_autocomplete "$prompt_name" "$step_message" "${step_options[@]}")
            exit_code=$?
            ;;
        date)
            result=$(_prompt_date "$prompt_name" "$step_message" "${step_options[0]:-}" "${step_options[1]:-YYYY-MM-DD HH:mm:ss}" "${step_options[2]:-}" "${step_options[3]:-}")
            exit_code=$?
            ;;
        *)
            echo "Error: Unknown prompt type: $step_type" >&2
            return 1
            ;;
    esac
    
    # Clean up environment variables
    unset IMENU_INITIAL IMENU_LIMIT IMENU_MIN IMENU_MAX
    unset IMENU_NO_MESSAGE_BLANK IMENU_MESSAGE_OPTIONS_GAP IMENU_INPUT_INLINE
    
    # Return result
    if [ $exit_code -eq 0 ]; then
        echo "$result"
        return 0
    else
        return $exit_code
    fi
}

