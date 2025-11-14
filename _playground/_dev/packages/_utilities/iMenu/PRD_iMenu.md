# Product Requirements Document: iMenu

## Overview

iMenu is a comprehensive, modular terminal-based interactive menu and prompt system for bash. It provides clean, user-friendly interfaces for single prompts and multi-step wizards, with a focus on separation of concerns, maintainability, and extensibility.

## Architecture

iMenu follows a modular architecture with clear separation between:

- **`core/`** - Shared utilities used across all modules
- **`_prompts/`** - Internal prompt implementations (not directly callable)
- **`iPrompt/`** - Public wrapper for single prompts
- **`iWizard/`** - Multi-step wizard orchestrator

## Directory Structure

```
iMenu/
├── core/                    # Shared utilities
│   ├── colors.sh            # Color definitions
│   ├── terminal.sh          # Terminal control functions
│   ├── utils.sh             # Utility functions
│   ├── state.sh             # State management
│   └── header.sh            # Header printing and keybindings
├── _prompts/               # Internal prompt library
│   ├── confirm.sh
│   ├── text.sh
│   ├── multiselect.sh
│   ├── select.sh
│   ├── number.sh
│   ├── list.sh
│   ├── toggle.sh
│   ├── password.sh
│   ├── invisible.sh
│   ├── autocomplete.sh
│   └── date.sh
├── iPrompt/                # Single prompt wrapper
│   ├── iPrompt.sh          # Main entry point
│   ├── core/
│   │   └── prompt-dispatcher.sh
│   └── tests/
├── iWizard/                # Multi-step wizard
│   ├── iWizard.sh          # Main entry point
│   ├── core/
│   │   ├── wizard-data.sh   # Response data manager
│   │   ├── wizard-display.sh # Clear and sent section drawing
│   │   └── wizard-orchestrator.sh # Main orchestrator logic
│   └── tests/
├── demos/
│   ├── wizard_demo.sh
│   └── wizard_input.json
├── iMenu.sh                # Main loader
└── tests/
    └── run_bats.sh         # Test runner
```

## Core Module (`core/`)

### Purpose

Provides shared utilities used across all iMenu modules. These are foundational functions that handle terminal control, color management, state tracking, and common utilities.

### Components

**`colors.sh`**
- Defines color constants: `GREEN`, `BLUE`, `CYAN`, `YELLOW`, `RED`, `DIM`, `GRAY`, `NC`
- Used for consistent styling across all prompts

**`terminal.sh`**
- `_imenu_hide_cursor()` - Hide terminal cursor
- `_imenu_show_cursor()` - Show terminal cursor
- `_imenu_clear_menu(lines)` - Clear specified number of lines
- `_imenu_clear_line()` - Clear current line
- `_imenu_read_char()` - Read single character (raw mode)
- `_imenu_read_escape()` - Read escape sequences (arrow keys)
- `_imenu_save_cursor()` / `_imenu_restore_cursor()` - Cursor position management

**`utils.sh`**
- `_imenu_is_function(name)` - Check if value is a function
- `_imenu_eval_prop(prop, prev, values, prompt_obj)` - Evaluate dynamic properties
- `_imenu_get_prompt_prop(prompt_ref, prop_name, prev, values)` - Get property from prompt object
- `_imenu_should_skip_prompt(prompt_ref, prev, values)` - Check if prompt should be skipped
- `_imenu_parse_flags(choices_array, preselect_var, message_var, parsed_array_var)` - Parse flags from array

**`state.sh`**
- Global state variables:
  - `_IMENU_RESPONSES` - Array of responses
  - `_IMENU_RESPONSES_MAP` - Associative array of named responses
  - `_IMENU_CANCELED` - Cancel flag
  - `_IMENU_OVERRIDE_VALUES` - Override values map
  - `_IMENU_STDIN` / `_IMENU_STDOUT` - Terminal streams

**`header.sh`**
- `_imenu_print_header(title)` - Print banner header (lines 1-5)
- `_imenu_get_keybindings(prompt_type, has_back)` - Generate keybindings string

## Prompt Library (`_prompts/`)

### Purpose

Internal prompt implementations. These functions are prefixed with `_prompt_` and are NOT directly callable. They can only be used through `iPrompt` or `iWizard`.

### Design Principles

1. **Execution Prevention**: Each prompt file prevents direct execution
2. **No Header/Clearing**: Prompts don't print headers or clear content (handled by wizard)
3. **Focused Responsibility**: Prompts only handle:
   - Drawing their own UI
   - Reading input
   - Returning result on stdout
   - Returning exit code (0=success, 1=cancel, 2=back)

### Function Naming

All prompt functions use `_prompt_` prefix:
- `_prompt_confirm()`
- `_prompt_text()`
- `_prompt_multiselect()`
- `_prompt_select()`
- etc.

### Supported Prompt Types

1. **confirm** - Yes/No confirmation
2. **text** - Free text input
3. **multiselect** - Multiple selection from options
4. **select** - Single selection from options
5. **number** - Numeric input with min/max
6. **list** - Comma-separated list input
7. **toggle** - Toggle between two states
8. **password** - Password input (masked)
9. **invisible** - Invisible input (no display)
10. **autocomplete** - Autocomplete selection
11. **date** - Date input with format

### Common Function Signature

```bash
_prompt_<type>(name, message, [initial], [options...])
```

**Parameters:**
- `name` - Name for storing result
- `message` - Prompt message/question
- `initial` - Initial/default value (optional)
- `options` - Type-specific options (choices, flags, etc.)

**Returns:**
- Result value on stdout
- Exit code: 0=success, 1=cancel, 2=back

## iPrompt Module (`iPrompt/`)

### Purpose

Public wrapper for running single prompts. Provides a clean, unified API for all prompt types while keeping actual implementations internal.

### API

**Main Function: `iprompt_run()`**

```bash
iprompt_run([name] type message [options...] [flags...])
```

**Usage Examples:**

```bash
# Basic confirm
result=$(iprompt_run "confirm" "Do you agree?" "--initial" "true")

# Multiselect with options
result=$(iprompt_run "multiselect" "Choose:" "Option 1" "Option 2" "--preselect" "0")

# Text with initial value
result=$(iprompt_run "text" "Enter name:" "--initial" "John")
```

**Flag Parsing:**
- `--initial <value>` - Initial/default value
- `--preselect <indices>` - Preselected indices (multiselect/select)
- `--min <value>` - Minimum value (number)
- `--max <value>` - Maximum value (number)
- `--separator <char>` - Separator character (list)
- `--format <format>` - Date format (date)

**Configuration Presets:**
- Input prompts (text, password, invisible, number, list, date): No blank line after message, inline input
- Selection prompts (multiselect, select, confirm, toggle, autocomplete): Blank line after message, gap before options

### Implementation

**`iPrompt.sh`** - Main entry point, sources core and _prompts

**`core/prompt-dispatcher.sh`** - Handles:
- Flag extraction and parsing
- Configuration preset application
- Function routing to appropriate `_prompt_*()` function
- Result formatting

## iWizard Module (`iWizard/`)

### Purpose

Multi-step wizard orchestrator. Manages wizard state, displays completed steps, and coordinates multiple prompts in sequence.

### API

**Main Function: `iwizard_run_json()`**

```bash
results=$(iwizard_run_json "wizard_input.json")
exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo "$results" | jq .
fi
```

**Returns:**
- JSON string on stdout with all step results
- Exit code: 0=success, 1=cancel

### JSON Configuration Format

Supports comments (both `//` and `/* */` style) which are automatically stripped before parsing:

```json
{
    "title": "Service Installation Wizard",
    "steps": [
        {
            "type": "confirm",
            "message": "ℹ️  Proceed?",
            "initial": true
        },
        // This is a single-line comment
        {
            "type": "multiselect",
            "message": "ℹ️  Which services?",
            "options": [
                "Sensor readings",
                "IAQ (Air quality calculation)",
                "Heat soak detection"
            ],
            "preselect": [0]
        }
        /* This is a
           multi-line comment */
    ]
}
```

### JSON Output Format

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
    }
}
```

### Visual Flow

**Title Banner (Lines 1-5) - Static, Never Cleared:**
```
═══════════════════════════════════════
  Service Installation Wizard
═══════════════════════════════════════

```

**Sent Section (Completed Steps) - Dimmed:**
```
ℹ️  Proceed? Yes
ℹ️  Which services would you like to install?
    ● Sensor readings
    ● IAQ (Air quality calculation)

```

**Active Prompt (Current Step) - Normal Colors:**
```
ℹ️  Finish it? (Y/n) ? y

```

### Step Flow

For each step:
1. Clear everything from line 6 down
2. Draw sent section (all previous steps, dimmed)
3. Debug pause if `IWIZARD_DEBUG=true`
4. Draw active prompt (via iPrompt)
5. Get result from prompt
6. Store in data manager
7. Handle back/cancel

After last step:
1. Clear everything from line 6 down
2. Draw all sent steps (including last)
3. Return JSON results

### Navigation

**Back Navigation:**
- Press 'b' or 'B' to go back to previous step
- Removes last step from data manager
- Redraws sent section without last step
- Shows previous step as active prompt

**Cancel:**
- Press ESC to cancel wizard
- Returns exit code 1
- No results returned

### Implementation Components

**`iWizard.sh`** - Main entry point, sources all wizard modules

**`core/wizard-display.sh`**:
- `_wizard_display_print_header(title)` - Print banner (lines 1-5, static)
- `_wizard_display_clear_content()` - Clear from line 6 down, cursor to line 6
- `_wizard_display_draw_sent_section()` - Draw all completed steps (dimmed)
  - Format: message + result inline for confirm/text/number/list
  - Format: message, then indented selections for multiselect/select
  - Always ends with blank line
  - Cursor positioned on line below blank line

**`core/wizard-data.sh`**:
- `_wizard_data_init()` - Initialize data structures
- `_wizard_data_store(step_index, type, message, result)` - Store step result
- `_wizard_data_format_result(type, result, options)` - Format result for display
- `_wizard_data_get_all()` - Get all stored data (for sent section)
- `_wizard_data_get_json()` - Generate JSON output
- `_wizard_data_remove_last()` - Remove last step (back navigation)

**`core/wizard-orchestrator.sh`**:
- `iwizard_run_json(json_file_path)` - Main entry point
  - Validates `jq` is installed (error if not)
  - Strips comments from JSON using `_wizard_strip_json_comments()`
  - Parses JSON config using `jq` on cleaned JSON
  - Calls orchestrator with parsed steps
- `_wizard_strip_json_comments(json_file_path)` - Comment stripper
  - Removes `//` single-line comments
  - Removes `/* */` multi-line comments
  - Preserves JSON structure and string content
  - Returns cleaned JSON to temp file for `jq` parsing
- `_wizard_orchestrate_steps(title, steps_array)` - Main loop
  - Prints header once (static)
  - For each step: clear, draw sent section, debug pause, call prompt, store result
  - After last step: clear, draw all sent steps, return JSON

### Debug Mode

Set `IWIZARD_DEBUG=true` to enable debug pauses:
- Pauses before drawing active prompt
- Allows inspection of cursor position after sent section
- Useful for debugging display issues

## Main Loader (`iMenu.sh`)

### Purpose

Main entry point that sources all modules and sets up the iMenu environment.

### Implementation

```bash
# Get directory of this script
_IMENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source core modules
source "${_IMENU_DIR}/core/colors.sh"
source "${_IMENU_DIR}/core/terminal.sh"
source "${_IMENU_DIR}/core/utils.sh"
source "${_IMENU_DIR}/core/state.sh"
source "${_IMENU_DIR}/core/header.sh"

# Source prompt library
source "${_IMENU_DIR}/_prompts/confirm.sh"
source "${_IMENU_DIR}/_prompts/text.sh"
# ... (all other prompts)

# Source public modules
source "${_IMENU_DIR}/iPrompt/iPrompt.sh"
source "${_IMENU_DIR}/iWizard/iWizard.sh"
```

### Usage

```bash
source "/path/to/iMenu.sh"

# Use iPrompt
result=$(iprompt_run "confirm" "Do you agree?" "--initial" "true")

# Use iWizard
results=$(iwizard_run_json "wizard_input.json")
```

## Dependencies

### Required

- **bash** 4.0+ (for associative arrays)
- **jq** - Required for JSON parsing in iWizard (error shown if not found)
- **BATS** - For testing framework (development only)

### Optional

- Terminal with ANSI color support
- Terminal with cursor control support

## Testing

### Test Structure

Tests mirror the code structure:
- `iPrompt/tests/` - Test single prompts via iPrompt
- `iWizard/tests/` - Test wizard functionality
- `_prompts/tests/` - Test prompt internals (if needed)

### Test Runner

**`tests/run_bats.sh`** supports:
- Single test file: `./tests/run_bats.sh tests/prompts_text.bats`
- Directory: `./tests/run_bats.sh tests/iWizard/`
- Nested directories: `./tests/run_bats.sh tests/` (recursive)

Uses BATS framework with colorized output (`TERM=xterm-256color`).

### Test Coverage

**Foundational Tests:**
- Clear and sent section drawing
- Data management (store, format, JSON generation)
- Each prompt type via iPrompt
- Full wizard flows
- Back navigation
- Cancel handling
- JSON parsing and output

## Key Design Principles

1. **Separation of Concerns**: Clear boundaries between modules
2. **Internal vs Public**: `_prompts/` is internal, `iPrompt/` and `iWizard/` are public APIs
3. **Wizard Orchestration**: Wizard handles all positioning, clearing, and state management
4. **Prompt Focus**: Prompts only draw UI and handle input
5. **JSON Configuration**: Simple, comment-enabled JSON for wizard configuration
6. **Modularity**: Each component can be tested and developed independently

## Usage Examples

### Single Prompt

```bash
source "iMenu.sh"

# Confirm prompt
result=$(iprompt_run "confirm" "Proceed with installation?" "--initial" "true")
if [ "$result" = "true" ]; then
    echo "User confirmed"
fi

# Text prompt
name=$(iprompt_run "text" "Enter your name:" "--initial" "John")
echo "Hello, $name!"
```

### Multi-Step Wizard

```bash
source "iMenu.sh"

# Run wizard from JSON config
results=$(iwizard_run_json "demos/wizard_input.json")

if [ $? -eq 0 ]; then
    # Parse results
    step0_result=$(echo "$results" | jq -r '.step0.result')
    step1_result=$(echo "$results" | jq -r '.step1.result')
    
    echo "Step 0: $step0_result"
    echo "Step 1: $step1_result"
fi
```

## Future Enhancements

- Conditional steps (skip based on previous results)
- Step validation
- Custom formatting per step
- Progress indicators
- Step branching logic
- Custom prompt types
- Theme support
- Internationalization

## Migration from iMenu_old

Key changes:
- Function names: `imenu_*()` → `_prompt_*()` (internal) or use `iprompt_run()` / `iwizard_run_json()`
- Module structure: Flat → Modular (`core/`, `_prompts/`, `iPrompt/`, `iWizard/`)
- Wizard API: Array-based → JSON-based (with `iwizard_run_json()`)
- Prompt access: Direct → Via `iPrompt` wrapper

## Summary

iMenu provides a clean, modular, and extensible framework for building interactive terminal interfaces. It separates concerns clearly, provides both single-prompt and multi-step wizard capabilities, and supports JSON-based configuration with comment support. The architecture is designed for maintainability, testability, and ease of use.

