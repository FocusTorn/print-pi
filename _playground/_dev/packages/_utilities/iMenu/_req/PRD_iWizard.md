# Product Requirements Document: iWizard Module

## Overview

iWizard is the public interface for running multi-step wizard flows. It orchestrates multiple prompts in sequence, manages wizard state, displays completed steps, and returns results as JSON.

## Goals

1. **Clean Orchestration**: Simple orchestrator that coordinates prompts
2. **State Management**: Track all step results and metadata
3. **Visual Flow**: Display sent section (completed steps) and active prompt
4. **Navigation**: Support back navigation between steps
5. **JSON Output**: Return structured JSON results

## API Design

### Primary Function: `iwizard_run_json()`

```bash
# Simple usage with JSON config
results=$(iwizard_run_json "wizard_config.json")
exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo "$results" | jq .
fi
```

### Alternative Function: `iwizard_run()`

```bash
# Programmatic usage with step arrays
step1=("confirm" "Proceed?" "--initial" "true")
step2=("multiselect" "Choose services:" "Service A" "Service B")
step3=("text" "Enter name:")

results=$(iwizard_run "My Wizard" step1 step2 step3)
```

### Function Signatures

```bash
iwizard_run_json(json_file_path)
iwizard_run(title step1 step2 ...)
```

**Returns**:
- JSON string on stdout with all step results
- Exit code: 0 = success, 1 = cancel

## JSON Configuration Format

```json
{
    "title": "Service Installation Wizard",
    "steps": [
        {
            "type": "confirm",
            "message": "ℹ️  Proceed?",
            "initial": true
        },
        {
            "type": "multiselect",
            "message": "ℹ️  Which services?",
            "options": [
                "Service A",
                "Service B",
                "Service C"
            ],
            "preselect": [0]
        },
        {
            "type": "text",
            "message": "ℹ️  Enter name:",
            "initial": "John"
        }
    ]
}
```

## JSON Output Format

```json
{
    "step0": {
        "type": "confirm",
        "message": "ℹ️  Proceed?",
        "result": "true"
    },
    "step1": {
        "type": "multiselect",
        "message": "ℹ️  Which services?",
        "result": "0 1"
    },
    "step2": {
        "type": "text",
        "message": "ℹ️  Enter name:",
        "result": "John Doe"
    }
}
```

## Visual Flow

### Title Banner (Lines 1-5)
```
═══════════════════════════════════════
  Service Installation Wizard
═══════════════════════════════════════

```
**Static**: Never cleared, always visible

### Sent Section
Displays all completed steps (dimmed):
```
ℹ️  Proceed? Yes
ℹ️  Which services?
    ● Service A
    ● Service B
ℹ️  Enter name: John

```
**Format**:
- Confirm/text/number/list: message + result inline
- Multiselect/select: message, then indented selections
- All text dimmed (grey)
- Blank line after last sent step

### Active Prompt
Current step being displayed (normal colors):
```
ℹ️  Finish installation? (Y/n) ? y

```
**Position**: Cursor naturally positioned after sent section

## Step Flow

### For Each Step:
1. Clear everything from line 6 down
2. Draw sent section (all previous steps, dimmed)
3. Debug pause (if `IWIZARD_DEBUG=true`)
4. Draw active prompt (via _prompts library)
5. Get result from prompt
6. Store in data manager
7. Handle back/cancel

### After Last Step:
1. Clear everything from line 6 down
2. Draw all sent steps (including last)
3. Return JSON results

## Navigation

### Back Navigation
- Press 'b' or 'B' to go back to previous step
- Removes last step from data manager
- Redraws sent section without last step
- Shows previous step as active prompt

### Cancel
- Press ESC to cancel wizard
- Returns exit code 1
- No results returned

## Implementation

### Core Components

**File**: `iWizard/iWizard.sh`
- Main entry point
- Sources _shared/, _prompts/, and wizard modules
- Provides `iwizard_run()` and `iwizard_run_json()` functions

**File**: `iWizard/core/wizard-data.sh`
- Data management functions
- Store/retrieve step results
- Format results for display
- Generate JSON output
- Handle back navigation (remove last step)

**File**: `iWizard/core/wizard-display.sh`
- Display functions
- Print header (banner)
- Clear content (line 6 down)
- Draw sent section (completed steps)

**File**: `iWizard/core/wizard-orchestrator.sh`
- Main orchestrator logic
- Step loop management
- Navigation handling
- JSON parsing and generation

### Function Responsibilities

**Data Manager**:
- `_wizard_data_init()` - Initialize data structures
- `_wizard_data_store()` - Store step result
- `_wizard_data_format_result()` - Format result for display
- `_wizard_data_get_all()` - Get all stored data
- `_wizard_data_get_json()` - Generate JSON output
- `_wizard_data_remove_last()` - Remove last step (back navigation)

**Display Functions**:
- `_wizard_display_print_header()` - Print banner
- `_wizard_display_clear_content()` - Clear from line 6 down
- `_wizard_display_draw_sent_section()` - Draw completed steps

**Orchestrator**:
- `iwizard_run()` - Main orchestrator (step arrays)
- `iwizard_run_json()` - JSON file parser and orchestrator

## Debug Mode

Set `IWIZARD_DEBUG=true` to enable debug pauses:
- Pauses before drawing active prompt
- Allows inspection of cursor position
- Useful for debugging display issues

## Testing

### Test Coverage
- Foundational functions (clear, sent section drawing)
- Data management (store, format, JSON generation)
- Each prompt type in wizard context
- Full wizard flows
- Back navigation
- Cancel handling
- JSON parsing and output

### Test Files
- `iWizard/tests/test_foundational.bats` - Clear and display functions
- `iWizard/tests/test_data_manager.bats` - Data management
- `iWizard/tests/test_prompts_integration.bats` - Prompt integration
- `iWizard/tests/test_wizard_flow.bats` - Full flows

## Dependencies

- **Requires**: _shared/ (core utilities)
- **Requires**: _prompts/ (internal prompt library)
- **Provides**: Public API for multi-step wizards

## Key Principles

1. **Prompts Only Draw**: Prompts handle drawing and input, nothing else
2. **Wizard Orchestrates**: iWizard handles all positioning, clearing, state
3. **Sent Section Positions**: Sent section naturally leaves cursor in correct position
4. **No Manual Positioning**: No cursor movement needed before calling prompt
5. **Clean Separation**: Clear boundaries between components

## Future Enhancements

- Conditional steps (skip based on previous results)
- Step validation
- Custom formatting per step
- Progress indicators
- Step branching logic

