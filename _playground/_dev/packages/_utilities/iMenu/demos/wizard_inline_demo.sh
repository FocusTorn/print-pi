#!/usr/bin/env bash
# Demo script showcasing iWizard with inline JSON configuration
# Shows how to use iWizard in a one-off script without a separate JSON file

# Get directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMENU_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source iMenu
source "$IMENU_DIR/iMenu.sh"


# Method 1: Inline JSON string directly in the function call
echo "Method 1: Inline JSON string" >&2
results1=$(iwizard_run_inline '{
    "title": "Method 1",
    "steps": [
        {
            "type": "confirm",
            "message": "ℹ️  Proceed with setup?",
            "initial": true
        },
        {
            "type": "text",
            "message": "ℹ️  Enter your name:",
            "initial": "User"
        }
    ]
}')
exit_code1=$?

if [ $exit_code1 -eq 0 ]; then
    echo "Results (Method 1):" >&2
    echo "$results1" | jq . >&2
else
    echo "Wizard cancelled (Method 1)" >&2
fi

printf '\n' >&2

# Method 2: JSON string in a variable, then pass to function
echo "Method 2: JSON in variable" >&2
wizard_config='
{
    "title": "Service Configuration",
    "steps": [
        {
            "type": "select",
            "message": "ℹ️  Select service type:",
            "options": [
                "Web Server",
                "Database",
                "Cache"
            ]
        },
        {
            "type": "multiselect",
            "message": "ℹ️  Select features:",
            "options": [
                "SSL/TLS",
                "Monitoring",
                "Backup"
            ],
            "preselect": [0, 2]
        }
    ]
}
'

results2=$(iwizard_run_inline "$wizard_config")
exit_code2=$?

if [ $exit_code2 -eq 0 ]; then
    echo "Results (Method 2):" >&2
    
    echo "$results2" | jq . >&2
    # echo "$results2"
    
else
    echo "Wizard cancelled (Method 2)" >&2
fi

printf '\n' >&2

# # Method 3: Using iwizard_run_json directly (auto-detects file vs string)
# echo "Method 3: Direct call with JSON string" >&2
# results3=$(iwizard_run_json '{
#     "title": "Final Step",
#     "steps": [
#         {
#             "type": "confirm",
#             "message": "ℹ️  Complete setup?",
#             "initial": false
#         }
#     ]
# }')
# exit_code3=$?

# if [ $exit_code3 -eq 0 ]; then
#     echo "Results (Method 3):" >&2
#     echo "$results3" | jq . >&2
# else
#     echo "Wizard cancelled (Method 3)" >&2
# fi

# Note: You can still use file paths - iwizard_run_json auto-detects:
# results=$(iwizard_run_json "$SCRIPT_DIR/wizard_input.json")  # File path
# results=$(iwizard_run_json '{"title": "...", "steps": [...]}')  # JSON string

