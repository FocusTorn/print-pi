#!/usr/bin/env bash
# iWizard - Multi-step wizard system for iMenu
# Handles dynamic message accumulation and step transitions
# Uses iPrompt internally for consistent prompt handling

# Usage:
#   local step1=("multiselect" "ℹ️  Which services?" "Option 1" "Option 2")
#   local step2=("select" "ℹ️  Which installation?" "Option A" "Option B")
#   iwizard_run "Wizard Title" step1 step2

# Run a wizard with multiple steps
# Arguments: title step1 step2 step3 ...
iwizard_run() {
    local title="$1"
    shift
    local step_refs=("$@")
    
    # Print header once at the start
    printf '\n' >&2
    printf '%b════════════════════════════════════════%b\n' "${CYAN}" "${NC}" >&2
    printf '%b  %s%b\n' "${CYAN}" "$title" "${NC}" >&2
    printf '%b════════════════════════════════════════%b\n' "${CYAN}" "${NC}" >&2
    printf '\n' >&2
    
    # Set flag to skip header printing in prompt calls
    export IMENU_TITLE=""
    
    # Accumulated messages for dynamic display
    local accumulated_messages=()
    
    local step_idx=0
    while [ $step_idx -lt ${#step_refs[@]} ]; do
        local step_ref="${step_refs[$step_idx]}"
        
        # Get the step array (indirect reference)
        local step_array
        eval "step_array=(\"\${${step_ref}[@]}\")"
        
        # Step format: [type] [message] [options...] [--preselect "idx"]
        local step_type="${step_array[0]}"
        local step_message="${step_array[1]}"
        
        # For step 2+, only display the current step's message
        # Previous messages are already visible on screen (they persist)
        # For step 1, display the message as-is
        if [ $step_idx -eq 0 ]; then
            # First step - display message normally
            step_array[1]="$step_message"
        else
            # Subsequent steps - only display current message
            # Previous messages are already visible, so don't duplicate them
            step_array[1]="$step_message"
        fi
        
        # Store this message for next step (for potential future use)
        accumulated_messages+=("$step_message")
        
        # Check if this is a substep (has back button)
        local has_back="false"
        if [ $step_idx -gt 0 ]; then
            has_back="true"
        fi
        
        # Set environment for iMenu
        export IMENU_HAS_BACK="$has_back"
        export IMENU_CLEAR_PREVIOUS="${IMENU_LAST_LINES:-0}"
        # Apply wizard preset: messages butted up, no gap by default
        imenu_config_preset "wizard"
        
        # Use iPrompt to handle the prompt
        local result=""
        local exit_code=0
        
        result=$(iprompt_run "step$step_idx" "${step_array[@]}")
        exit_code=$?
        
        # Handle exit codes
        if [ $exit_code -eq 1 ]; then
            # Cancel
            return 1
        elif [ $exit_code -eq 2 ]; then
            # Back - go to previous step
            if [ $step_idx -gt 0 ]; then
                # Remove last message from accumulation
                unset 'accumulated_messages[-1]'
                step_idx=$((step_idx - 1))  # Go back to previous step
                continue
            else
                return 1
            fi
        fi
        
        # Store result for next step or return
        if [ $step_idx -lt $((${#step_refs[@]} - 1)) ]; then
            # Not last step, continue
            unset IMENU_CLEAR_PREVIOUS
            ((step_idx++))
        else
            # Last step - return all results
            echo "$result"
            return 0
        fi
    done
}

