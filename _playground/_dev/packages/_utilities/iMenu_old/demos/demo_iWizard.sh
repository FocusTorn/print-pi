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
    "--preselect" "0"
)

step2=(
    "confirm"
    "ℹ️  Do it?"
    
    "--initial" "true"
)

step3=(
    "confirm"
    "ℹ️  You sure?"
    
)

# step2=(
#     "select"
#     "ℹ️  Which installation method would you like to use?"
#     "Standalone MQTT"
#     "HA MQTT Receipt"
#     "HA Custom Integration"
# )

# step3=(
#     "text"
#     "ℹ️  Enter MQTT broker address:"
#     "--initial" "localhost:1883"
# )

# step4=(
#     "number"
#     "ℹ️  Enter MQTT port:"
#     "1883"
#     "--min" "1"
#     "--max" "65535"
# )

# step5=(
#     "toggle"
#     "ℹ️  Enable debug logging?"
#     "false"
# )

# step6=(
#     "confirm"
#     "ℹ️  Ready to proceed with installation?"
#     "false"
# )

# Run the wizard
# printf '\n' >&2
# echo -e "${CYAN}Starting iWizard Demo...${NC}" >&2
# printf '\n' >&2

# Capture step info to a file
wizard_step_info_file=$(mktemp)
export IMENU_STEP_INFO_FILE="$wizard_step_info_file"
wizard_output=$(iwizard_run "Service Installation Wizard" step1 step2 step3)
wizard_exit=$?
unset IMENU_STEP_INFO_FILE

if [ $wizard_exit -eq 0 ]; then
    printf '\n' >&2
    echo -e "${GREEN}✅ Wizard completed successfully!${NC}" >&2
    printf '\n' >&2
    
    # Parse step info from file
    declare -A step_info_map
    if [ -f "$wizard_step_info_file" ]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^IMENU_STEP_INFO:([0-9]+):([^:]+):([^:]+):([^:]+):([^|]+)\|(.+)$ ]]; then
                step_idx="${BASH_REMATCH[1]}"
                step_type="${BASH_REMATCH[2]}"
                step_message="${BASH_REMATCH[3]}"
                step_options="${BASH_REMATCH[4]}"
                step_default="${BASH_REMATCH[5]}"
                step_result="${BASH_REMATCH[6]}"
                step_info_map["$step_idx"]="$step_type|$step_message|$step_options|$step_default|$step_result"
            fi
        done < "$wizard_step_info_file"
    fi
    
    # Display all steps with formatted results
    step_idx=0
    while [ $step_idx -lt 3 ]; do
        if [ -n "${step_info_map[$step_idx]:-}" ]; then
            IFS='|' read -r step_type step_message step_options step_default step_result <<< "${step_info_map[$step_idx]}"
            
            # Display message
            printf '%b%s%b' "${BLUE}" "$step_message" "${NC}" >&2
            
            # Format result based on type
            if [ "$step_type" = "multiselect" ]; then
                # Parse result (space-separated indices)
                read -ra selected_indices <<< "$step_result"
                # Parse options (unit separator delimited)
                IFS=$'\x1F' read -ra options_array <<< "$step_options"
                # Display selected options with bullets (no blank line before)
                for idx in "${selected_indices[@]}"; do
                    if [ -n "$idx" ] && [ "$idx" -ge 0 ] && [ "$idx" -lt ${#options_array[@]} ]; then
                        printf '\n    %b●%b %s' "${GREEN}" "${NC}" "${options_array[$idx]}" >&2
                    fi
                done
                printf '\n' >&2  # Newline after all options
            elif [ "$step_type" = "select" ]; then
                # Parse result (single index)
                selected_idx="$step_result"
                # Parse options (unit separator delimited)
                IFS=$'\x1F' read -ra options_array <<< "$step_options"
                # Display selected option with bullet (no blank line before)
                if [ -n "$selected_idx" ] && [ "$selected_idx" -ge 0 ] && [ "$selected_idx" -lt ${#options_array[@]} ]; then
                    printf '\n    %b●%b %s\n' "${GREEN}" "${NC}" "${options_array[$selected_idx]}" >&2
                fi
            elif [ "$step_type" = "confirm" ]; then
                # Display result inline with hint based on default (not result)
                # Determine hint based on default value
                default_bool=false
                if [ "$step_default" = "true" ] || [ "$step_default" = "Y" ] || [ "$step_default" = "y" ] || [ "$step_default" = "1" ]; then
                    default_bool=true
                fi
                # Show hint based on default
                if [ "$default_bool" = "true" ]; then
                    printf ' %b(Y/n)%b ? ' "${GRAY}" "${NC}" >&2
                else
                    printf ' %b(y/N)%b ? ' "${GRAY}" "${NC}" >&2
                fi
                # Show result (lowercase)
                if [ "$step_result" = "true" ]; then
                    printf '%by%b\n' "${DIM}" "${NC}" >&2
                else
                    printf '%bn%b\n' "${DIM}" "${NC}" >&2
                fi
            else
                # Other types - just show result inline
                printf ' %s\n' "$step_result" >&2
            fi
        fi
        ((step_idx++))
    done
    
    printf '\n' >&2
    rm -f "$wizard_step_info_file"
    
    # Parse wizard output - responses are in format "step_response:key=value"
    # Last line is the final result
    final_result=""
    has_responses=false
    
    # Debug: show raw output if empty
    if [ -z "$wizard_output" ]; then
        echo "Warning: Wizard output is empty" >&2
    fi
    
    # Process each line of wizard output
    # Use a temporary file to capture results from subshell
    temp_file=$(mktemp)
    echo "$wizard_output" | while IFS= read -r line; do
        if [ -z "$line" ]; then
            continue
        fi
        if [[ "$line" =~ ^step_response:(.+)=(.+)$ ]]; then
            # This is a step response
            step_key="${BASH_REMATCH[1]}"
            step_value="${BASH_REMATCH[2]}"
            echo "RESPONSE:$step_key=$step_value" >> "$temp_file"
        else
            # This is the final result (last line)
            echo "FINAL:$line" >> "$temp_file"
        fi
    done
    
    # Read results from temp file
    if [ -f "$temp_file" ]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^RESPONSE:(.+)=(.+)$ ]]; then
                step_key="${BASH_REMATCH[1]}"
                step_value="${BASH_REMATCH[2]}"
                if [ "$has_responses" = false ]; then
                    echo "All responses from wizard steps:" >&2
                    has_responses=true
                fi
                echo "  $step_key: $step_value" >&2
            elif [[ "$line" =~ ^FINAL:(.+)$ ]]; then
                final_result="${BASH_REMATCH[1]}"
            fi
        done < "$temp_file"
        rm -f "$temp_file"
    fi
    
    # Show final result after processing all responses
    if [ -n "$final_result" ]; then
        if [ "$has_responses" = true ]; then
            printf '\n' >&2
        fi
        echo "Final result from last step:" >&2
        echo "  $final_result" >&2
    fi
else
    printf '\n' >&2
    echo -e "${YELLOW}⚠️  Wizard cancelled${NC}" >&2
fi
