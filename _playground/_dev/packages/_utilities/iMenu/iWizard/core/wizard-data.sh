#!/usr/bin/env bash
# iWizard Core - Data Management
# Handles storing, formatting, and retrieving wizard step data

# Global arrays for wizard data
declare -a _WIZARD_MESSAGES=()
declare -a _WIZARD_RESULTS=()
declare -a _WIZARD_TYPES=()
declare -a _WIZARD_OPTIONS=()
declare -a _WIZARD_RAW_RESULTS=()

# Persistent variables (associative array for key-value storage)
# Stores metadata and state that persists across all steps
declare -A _WIZARD_PERSISTENT=()

# Initialize data structures
_wizard_data_init() {
    _WIZARD_MESSAGES=()
    _WIZARD_RESULTS=()
    _WIZARD_TYPES=()
    _WIZARD_OPTIONS=()
    _WIZARD_RAW_RESULTS=()
    # Note: _WIZARD_PERSISTENT is NOT cleared - it persists across wizard runs
    # Use _wizard_data_clear_persistent() to explicitly clear if needed
}

# Store step result
# Arguments: step_index type message result options
_wizard_data_store() {
    local step_index="$1"
    local step_type="$2"
    local step_message="$3"
    local step_result="$4"
    local step_options="${5:-}"
    
    _WIZARD_MESSAGES[$step_index]="$step_message"
    _WIZARD_RAW_RESULTS[$step_index]="$step_result"
    _WIZARD_TYPES[$step_index]="$step_type"
    _WIZARD_OPTIONS[$step_index]="$step_options"
    
    # Format result for display
    local formatted_result
    formatted_result=$(_wizard_data_format_result "$step_type" "$step_result" "$step_options")
    _WIZARD_RESULTS[$step_index]="$formatted_result"
}

# Format result for display based on type
# Arguments: type result options
_wizard_data_format_result() {
    local step_type="$1"
    local step_result="$2"
    local step_options="${3:-}"
    
    local formatted_result=""
    
    case "$step_type" in
        confirm)
            # Format as "Yes" or "No"
            if [ "$step_result" = "true" ]; then
                formatted_result=" Yes"
            else
                formatted_result=" No"
            fi
            ;;
        text|number|list)
            # Format inline with space prefix
            formatted_result=" $step_result"
            ;;
        multiselect)
            # Parse result (space-separated indices) and format with bullets
            if [ -n "$step_result" ]; then
                read -ra selected_indices <<< "$step_result"
                # Parse options (unit separator delimited)
                local IFS=$'\x1F'
                local options_array=()
                if [ -n "$step_options" ]; then
                    IFS=$'\x1F' read -ra options_array <<< "$step_options"
                fi
                # Build formatted result with bullets, each on separate line (no blank lines)
                local first=true
                for idx in "${selected_indices[@]}"; do
                    if [ -n "$idx" ] && [ "$idx" -ge 0 ] && [ ${#options_array[@]} -gt 0 ] && [ "$idx" -lt ${#options_array[@]} ]; then
                        if [ "$first" = true ]; then
                            formatted_result=$'\n    ● '"${options_array[$idx]}"
                            first=false
                        else
                            formatted_result="$formatted_result"$'\n    ● '"${options_array[$idx]}"
                        fi
                    fi
                done
                # No trailing newline - next step will handle spacing
            fi
            ;;
        select)
            # Parse result (single index) and format inline (no bullet, single line)
            if [ -n "$step_result" ]; then
                local selected_idx="$step_result"
                # Parse options (unit separator delimited)
                local IFS=$'\x1F'
                local options_array=()
                if [ -n "$step_options" ]; then
                    IFS=$'\x1F' read -ra options_array <<< "$step_options"
                fi
                # Build formatted result inline (no bullet, single line)
                if [ -n "$selected_idx" ] && [ "$selected_idx" -ge 0 ] && [ ${#options_array[@]} -gt 0 ] && [ "$selected_idx" -lt ${#options_array[@]} ]; then
                    formatted_result=" ${options_array[$selected_idx]}"
                else
                    formatted_result=" $step_result"
                fi
            fi
            ;;
        *)
            # For other types, format inline
            formatted_result=" $step_result"
            ;;
    esac
    
    echo "$formatted_result"
}

# Get all stored data (for sent section)
# Returns: step_count
_wizard_data_get_all() {
    echo ${#_WIZARD_MESSAGES[@]}
}

# Generate JSON output
_wizard_data_get_json() {
    # Use jq to build the JSON object properly (handles all escaping automatically)
    # This ensures all control characters and special characters are properly escaped
    local json_obj="{}"
    local i
    local use_jq=true
    
    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        use_jq=false
    fi
    
    for ((i=0; i<${#_WIZARD_MESSAGES[@]}; i++)); do
        local step_key="step$i"
        local step_type="${_WIZARD_TYPES[$i]}"
        local step_message="${_WIZARD_MESSAGES[$i]}"
        local step_result="${_WIZARD_RAW_RESULTS[$i]}"
        
        if [ "$use_jq" = true ]; then
            # Build step object using jq (properly escapes all values)
            local step_obj
            step_obj=$(jq -n \
                --arg type "$step_type" \
                --arg message "$step_message" \
                --arg result "$step_result" \
                '{type: $type, message: $message, result: $result}' 2>/dev/null)
            
            if [ $? -eq 0 ] && [ -n "$step_obj" ]; then
                # Add step to main object using jq
                json_obj=$(echo "$json_obj" | jq --arg key "$step_key" --argjson step "$step_obj" '. + {($key): $step}' 2>/dev/null)
                if [ $? -ne 0 ]; then
                    use_jq=false
                    # Fall through to manual construction
                fi
            else
                use_jq=false
                # Fall through to manual construction
            fi
        fi
        
        if [ "$use_jq" = false ]; then
            # Fallback to manual construction if jq fails or unavailable
            local escaped_type
            local escaped_message
            local escaped_result
            escaped_type=$(printf '"%s"' "$(echo -n "$step_type" | sed 's/\\/\\\\/g; s/"/\\"/g')")
            escaped_message=$(printf '"%s"' "$(echo -n "$step_message" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g; s/\r/\\r/g; s/\t/\\t/g')")
            escaped_result=$(printf '"%s"' "$(echo -n "$step_result" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g; s/\r/\\r/g; s/\t/\\t/g')")
            
            # Manual JSON construction (fallback)
            if [ "$i" -eq 0 ]; then
                json_obj="{"
            else
                json_obj="$json_obj,"
            fi
            json_obj="$json_obj\"$step_key\":{"
            json_obj="$json_obj\"type\":$escaped_type,"
            json_obj="$json_obj\"message\":$escaped_message,"
            json_obj="$json_obj\"result\":$escaped_result"
            json_obj="$json_obj}"
        fi
    done
    
    # If we used manual construction, close the object
    if [ "$use_jq" = false ] && [[ "$json_obj" != "{}" ]] && [[ ! "$json_obj" =~ \}$ ]]; then
        json_obj="$json_obj}"
    fi
    
    echo "$json_obj"
}

# Remove last step (for back navigation)
_wizard_data_remove_last() {
    local count=${#_WIZARD_MESSAGES[@]}
    if [ "$count" -gt 0 ]; then
        unset "_WIZARD_MESSAGES[$((count-1))]"
        unset "_WIZARD_RESULTS[$((count-1))]"
        unset "_WIZARD_TYPES[$((count-1))]"
        unset "_WIZARD_OPTIONS[$((count-1))]"
        unset "_WIZARD_RAW_RESULTS[$((count-1))]"
    fi
}

# Set a persistent variable
# Arguments: key value
_wizard_data_set_persistent() {
    local key="$1"
    local value="$2"
    _WIZARD_PERSISTENT["$key"]="$value"
}

# Get a persistent variable
# Arguments: key
# Returns: value (empty string if not set)
_wizard_data_get_persistent() {
    local key="$1"
    echo "${_WIZARD_PERSISTENT[$key]:-}"
}

# Clear all persistent variables
_wizard_data_clear_persistent() {
    _WIZARD_PERSISTENT=()
}

# Check if a persistent variable exists
# Arguments: key
# Returns: 0 if exists, 1 if not
_wizard_data_has_persistent() {
    local key="$1"
    [ -n "${_WIZARD_PERSISTENT[$key]+x}" ]
}

