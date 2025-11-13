#!/usr/bin/env bash

# Enable debug mode by setting IMENU_WIZARD_DEBUG=true before running
# Example: IMENU_WIZARD_DEBUG=true ./demo_iWizard2.sh
# Or: export IMENU_WIZARD_DEBUG=true && ./demo_iWizard2.sh
# Or uncomment the line below to always enable debug mode:
export IMENU_WIZARD_DEBUG=true

source "$(dirname "$0")/../iMenu.sh"

JSON_FILE="$(dirname "$0")/wizard_input.json"

# Run the wizard - it handles all display logic internally
wizard_output=$(iwizard_run_json "$JSON_FILE")
wizard_exit=$?

if [ $wizard_exit -eq 0 ]; then
    printf '\n' >&2
    echo -e "${GREEN}✅ Wizard completed successfully!${NC}" >&2
    printf '\n' >&2
    
    # Parse wizard output for responses and final result
    final_result=""
    has_responses=false
    
    while IFS= read -r line; do
        if [ -z "$line" ]; then
            continue
        fi
        if [[ "$line" =~ ^step_response:(.+)=(.+)$ ]]; then
                step_key="${BASH_REMATCH[1]}"
                step_value="${BASH_REMATCH[2]}"
                if [ "$has_responses" = false ]; then
                    echo "All responses from wizard steps:" >&2
                    has_responses=true
                fi
                echo "  $step_key: $step_value" >&2
        else
            final_result="$line"
            fi
    done <<< "$wizard_output"
    
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
