#!/usr/bin/env bash
# Demo script showcasing iPrompt - Single prompt interface
# Uses a select prompt to allow choosing which prompt type to demo

# Get directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMENU_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source iMenu (which includes iPrompt)
source "$IMENU_DIR/iMenu.sh"

echo "iPrompt Demo - Select a prompt type to try"
echo "=========================================="
printf '\n'

# Main loop - allow user to try multiple prompts
while true; do
    # Select which prompt type to demo
    selection=$(iprompt_run "select" "Choose a prompt type to demo:" \
        "Confirm" \
        "Text" \
        "Select" \
        "Multiselect" \
        "Number" \
        "List" \
        "Toggle" \
        "Password" \
        "Invisible" \
        "Autocomplete" \
        "Date" \
        "Exit")
    
    exit_code=$?
    
    # Handle cancellation or exit
    if [ $exit_code -ne 0 ] || [ -z "$selection" ]; then
        echo "Exiting demo..." >&2
        break
    fi
    
    # Map selection index to prompt type
    case "$selection" in
        0)
            # Confirm prompt
            printf '\n' >&2
            echo "Demo: Confirm Prompt" >&2
            result=$(iprompt_run "confirm" "Do you agree to proceed?" "--initial" "true")
            echo "Result: $result" >&2
            ;;
        1)
            # Text prompt
            printf '\n' >&2
            echo "Demo: Text Prompt" >&2
            result=$(iprompt_run "text" "Enter your name:" "--initial" "John")
            echo "Result: $result" >&2
            ;;
        2)
            # Select prompt
            printf '\n' >&2
            echo "Demo: Select Prompt" >&2
            result=$(iprompt_run "select" "Choose an option:" "Option A" "Option B" "Option C")
            echo "Result: $result" >&2
            ;;
        3)
            # Multiselect prompt
            printf '\n' >&2
            echo "Demo: Multiselect Prompt" >&2
            result=$(iprompt_run "multiselect" "Choose multiple options:" "Option 1" "Option 2" "Option 3" "--preselect" "0")
            echo "Result: $result" >&2
            ;;
        4)
            # Number prompt
            printf '\n' >&2
            echo "Demo: Number Prompt" >&2
            result=$(iprompt_run "number" "Enter your age:" "--initial" "25" "--min" "0" "--max" "120")
            echo "Result: $result" >&2
            ;;
        5)
            # List prompt
            printf '\n' >&2
            echo "Demo: List Prompt" >&2
            result=$(iprompt_run "list" "Enter items (comma-separated):" "--initial" "item1,item2" "--separator" ",")
            echo "Result: $result" >&2
            ;;
        6)
            # Toggle prompt
            printf '\n' >&2
            echo "Demo: Toggle Prompt" >&2
            result=$(iprompt_run "toggle" "Enable feature?" "false" "Yes" "No")
            echo "Result: $result" >&2
            ;;
        7)
            # Password prompt
            printf '\n' >&2
            echo "Demo: Password Prompt" >&2
            result=$(iprompt_run "password" "Enter password:")
            echo "Result: [hidden]" >&2
            ;;
        8)
            # Invisible prompt
            printf '\n' >&2
            echo "Demo: Invisible Prompt" >&2
            result=$(iprompt_run "invisible" "Enter secret value:")
            echo "Result: [hidden]" >&2
            ;;
        9)
            # Autocomplete prompt
            printf '\n' >&2
            echo "Demo: Autocomplete Prompt" >&2
            result=$(iprompt_run "autocomplete" "Search:" "Apple" "Banana" "Cherry" "Date" "Elderberry")
            echo "Result: $result" >&2
            ;;
        10)
            # Date prompt
            printf '\n' >&2
            echo "Demo: Date Prompt" >&2
            result=$(iprompt_run "date" "Enter date:" "--format" "YYYY-MM-DD")
            echo "Result: $result" >&2
            ;;
        11)
            # Exit
            echo "Exiting demo..." >&2
            break
            ;;
        *)
            echo "Invalid selection" >&2
            ;;
    esac
    
    printf '\n' >&2
    echo "Press Enter to continue..." >&2
    read -r
    printf '\n' >&2
done

echo "Demo completed!" >&2

