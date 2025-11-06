#!/usr/bin/env bash
# iMenu Core - Utility Functions

# Check if value is a function
_imenu_is_function() {
    local func_name="$1"
    [ -z "$func_name" ] && return 1
    type "$func_name" 2>/dev/null | grep -q "function\|is a function" || [ "$(type -t "$func_name")" = "function" ]
}

# Evaluate dynamic property (function or value)
_imenu_eval_prop() {
    local prop="$1"
    local prev="$2"
    local values="$3"
    local prompt_obj="$4"
    
    if _imenu_is_function "$prop"; then
        # Call function with (prev, values, prompt_obj)
        "$prop" "$prev" "$values" "$prompt_obj"
    else
        echo -n "$prop"
    fi
}

# Get property from prompt object (associative array)
_imenu_get_prompt_prop() {
    local prompt_ref="$1"
    local prop_name="$2"
    local prev="$3"
    local values="$4"
    
    # Get value from associative array
    local prop_value
    eval "prop_value=\${${prompt_ref}[${prop_name}]}"
    
    # Evaluate if it's a function
    _imenu_eval_prop "$prop_value" "$prev" "$values" "$prompt_ref"
}

# Check if prompt should be skipped (type is falsy)
_imenu_should_skip_prompt() {
    local prompt_ref="$1"
    local prev="$2"
    local values="$3"
    
    local type_val
    type_val=$(_imenu_get_prompt_prop "$prompt_ref" "type" "$prev" "$values")
    
    [ -z "$type_val" ] || [ "$type_val" = "null" ] || [ "$type_val" = "false" ] || [ "$type_val" = "0" ]
}

# Parse flags from array (--preselect, --message)
# Usage: _imenu_parse_flags choices_array preselect_var message_var parsed_array_var
# Note: This uses eval to work around nameref limitations in older bash
_imenu_parse_flags() {
    local choices_array_name="$1"
    local preselect_var="$2"
    local message_var="$3"
    local parsed_var="$4"
    
    local skip_indices=()
    local i
    
    # Get array length
    eval "local array_len=\${#${choices_array_name}[@]}"
    
    for ((i=0; i<array_len; i++)); do
        eval "local val=\${${choices_array_name}[$i]}"
        if [ "$val" = "--preselect" ]; then
            eval "${preselect_var}=\${${choices_array_name}[$((i+1))]}"
            skip_indices+=("$i" "$((i+1))")
            ((i++))
        elif [ "$val" = "--message" ]; then
            eval "${message_var}=\${${choices_array_name}[$((i+1))]}"
            skip_indices+=("$i" "$((i+1))")
            ((i++))
        fi
    done
    
    # Re-pack array excluding skipped indices
    eval "${parsed_var}=()"
    for ((i=0; i<array_len; i++)); do
        local should_skip=false
        for skip_idx in "${skip_indices[@]}"; do
            if [ "$i" -eq "$skip_idx" ]; then
                should_skip=true
                break
            fi
        done
        if [ "$should_skip" != true ]; then
            eval "local val=\${${choices_array_name}[$i]}"
            eval "${parsed_var}+=(\"\$val\")"
        fi
    done
}

