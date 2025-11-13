#!/usr/bin/env bash
# Demo script showcasing iPrompt - Single prompt abstraction layer
# Allows user to select which prompt type to try out

source "$(dirname "$0")/../iMenu.sh"

# Header
printf '\n' >&2
printf '%b════════════════════════════════════════%b\n' "${CYAN}" "${NC}" >&2
printf '%b  iPrompt Demo%b\n' "${CYAN}" "${NC}" >&2
printf '%b════════════════════════════════════════%b\n' "${CYAN}" "${NC}" >&2
printf '\n' >&2

# Prompt selection menu
prompt_menu=(
    "select"
    "ℹ️  Which prompt type would you like to try?"
    "text"
    "password"
    "invisible"
    "number"
    "confirm"
    "list" # Bad
    "toggle" # Bad
    "select"
    "multiselect"
    "autocomplete" # Bad
    "date" # Bad
)

# Get user selection
selected_indices=$(iprompt_run "prompt_selection" "${prompt_menu[@]}")
exit_code=$?

if [ $exit_code -ne 0 ] || [ -z "$selected_indices" ]; then
    echo -e "${BLUE}ℹ️  Demo cancelled${NC}" >&2
    exit 0
fi

# Process each selected prompt type
for idx in $selected_indices; do
    prompt_type="${prompt_menu[$((idx+2))]}"
    
    printf '\n' >&2
    printf '%b────────────────────────────────────────%b\n' "${CYAN}" "${NC}" >&2
    printf '%b  Trying: %s%b\n' "${CYAN}" "$prompt_type" "${NC}" >&2
    printf '%b────────────────────────────────────────%b\n' "${CYAN}" "${NC}" >&2
    printf '\n' >&2
    
    # Set title for this prompt
    export IMENU_TITLE="iPrompt Demo: $prompt_type"
    
    case "$prompt_type" in
        text)
            step=(
                "text"
                "ℹ️  Enter your name:"
                "--initial" "John Doe"
            )
            result=$(iprompt_run "text_result" "${step[@]}")
            ;;
        password)
            step=(
                "password"
                "ℹ️  Enter your password:"
            )
            result=$(iprompt_run "password_result" "${step[@]}")
            ;;
        invisible)
            step=(
                "invisible"
                "ℹ️  Enter a secret (invisible):"
            )
            result=$(iprompt_run "invisible_result" "${step[@]}")
            ;;
        number)
            step=(
                "number"
                "ℹ️  Enter your age:"
                "--min" "1"
                "--max" "120"
            )
            result=$(iprompt_run "number_result" "${step[@]}")
            ;;
        confirm)
            step=(
                "confirm"
                "ℹ️  Do you agree to the terms?"
                "false"
            )
            result=$(iprompt_run "confirm_result" "${step[@]}")
            ;;
        list)
            step=(
                "list"
                "ℹ️  Enter tags (comma-separated):"
                "--initial" "tag1, tag2, tag3"
            )
            result=$(iprompt_run "list_result" "${step[@]}")
            ;;
        toggle)
            step=(
                "toggle"
                "ℹ️  Enable notifications?"
                "true"
            )
            result=$(iprompt_run "toggle_result" "${step[@]}")
            ;;
        select)
            step=(
                "select"
                "ℹ️  Pick your favorite color:"
                "Red"
                "Green"
                "Blue"
                "Yellow"
                "Purple"
            )
            result=$(iprompt_run "select_result" "${step[@]}")
            ;;
        multiselect)
            step=(
                "multiselect"
                "ℹ️  Select your favorite colors:"
                "Red"
                "Green"
                "Blue"
                "Yellow"
                "Purple"
                "--preselect" "0 1"
            )
            result=$(iprompt_run "multiselect_result" "${step[@]}")
            ;;
        autocomplete)
            step=(
                "autocomplete"
                "ℹ️  Search for a country:"
                "United States"
                "United Kingdom"
                "Canada"
                "Australia"
                "Germany"
                "France"
                "Japan"
                "China"
                "India"
                "Brazil"
                "--limit" "5"
            )
            result=$(iprompt_run "autocomplete_result" "${step[@]}")
            ;;
        date)
            step=(
                "date"
                "ℹ️  Enter a date (YYYY-MM-DD HH:mm:ss):"
                "--initial" "$(date '+%Y-%m-%d %H:%M:%S')"
            )
            result=$(iprompt_run "date_result" "${step[@]}")
            ;;
    esac
    
    prompt_exit=$?
    
    if [ $prompt_exit -eq 0 ]; then
        printf '\n' >&2
        echo -e "${GREEN}✅ Result:${NC}" >&2
        echo "  $result" >&2
    else
        printf '\n' >&2
        echo -e "${YELLOW}⚠️  Prompt cancelled${NC}" >&2
    fi
    
    # Clean up
    unset IMENU_TITLE
    
    # Pause between prompts (if multiple selected)
    if [ $(echo "$selected_indices" | wc -w) -gt 1 ]; then
        sleep 1
    fi
done

printf '\n' >&2
echo -e "${GREEN}✅ Demo complete!${NC}" >&2
