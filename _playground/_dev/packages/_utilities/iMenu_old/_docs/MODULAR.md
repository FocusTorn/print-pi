# iMenu Modular Structure

## Overview

iMenu has been refactored into a modular structure with four main layers:

```
iMenu/
├── core/                    # Shared utilities
│   ├── colors.sh           # Color definitions
│   ├── state.sh            # State management
│   ├── terminal.sh         # Terminal control functions
│   ├── utils.sh            # Utility functions
│   └── header.sh           # Header and keybindings
├── prompts/                 # Individual prompt types
│   ├── multiselect.sh      # Multi-select menu
│   ├── select.sh           # Single-select menu
│   ├── toggle.sh           # Toggle/confirm prompt
│   ├── text.sh             # Free text input
│   ├── password.sh         # Masked password input
│   ├── invisible.sh        # Invisible input (like sudo)
│   ├── number.sh           # Numeric input
│   ├── confirm.sh          # Yes/No confirmation
│   ├── list.sh             # List input (returns array)
│   ├── autocomplete.sh     # Searchable autocomplete
│   └── date.sh             # Date input
├── iPrompt.sh              # Single prompt abstraction layer
├── iWizard.sh              # Multi-step wizard system
├── iMenu.sh                # Main loader (sources all modules)
└── import.sh               # Import helper
```

## Architecture Layers

### 1. Core (`core/`)
Low-level utilities shared by all prompts:
- Colors, terminal control, state management
- Header and keybinding generation
- Utility functions

### 2. Prompts (`prompts/`)
Individual prompt type implementations:
- Each prompt type is self-contained
- Handles its own flag parsing, validation, display
- Exposes function: `imenu_<type>()`

### 3. iPrompt (`iPrompt.sh`)
**Single prompt abstraction layer:**
- Unified interface for running individual prompts
- Handles flag parsing (`--preselect`, `--message`, `--limit`, etc.)
- Routes to appropriate prompt function based on type
- Used by iWizard internally

**Usage:**
```bash
# From step array
local step=("multiselect" "Pick colors" "Red" "Green" "Blue" --preselect "0 1")
result=$(iprompt_run step)

# Direct call
result=$(iprompt_run "colors" "select" "Pick a color" "Red" "Green" "Blue")
```

### 4. iWizard (`iWizard.sh`)
**Multi-step wizard system:**
- Handles dynamic message accumulation
- Manages step transitions and back navigation
- Uses iPrompt internally for consistent prompt handling

**Usage:**
```bash
local step1=("multiselect" "ℹ️  Which services?" "Option 1" "Option 2")
local step2=("select" "ℹ️  Which installation?" "Option A" "Option B")
iwizard_run "Wizard Title" step1 step2
```

## Using iPrompt

The `iPrompt` layer provides a clean abstraction for single prompts:

```bash
source "$(dirname "$0")/import.sh"

# Define a step as an array
local step=(
    "multiselect"
    "ℹ️  Which services would you like to install?"
    "Sensor readings"
    "IAQ (Air quality calculation)"
    "Heat soak detection"
    "--preselect" "0 1 2"  # Optional flags
)

# Run the prompt
result=$(iprompt_run step)

# Or call directly
result=$(iprompt_run "services" "select" "Pick one" "Option A" "Option B")
```

### Supported Flags

- `--preselect` - Preselect indices (for select/multiselect)
- `--message` - Override message
- `--initial` - Set initial value
- `--limit` - Limit results (for autocomplete)
- `--min` - Minimum value (for number)
- `--max` - Maximum value (for number)

## Using iWizard

The `iWizard` system builds on `iPrompt` for multi-step flows:

```bash
source "$(dirname "$0")/import.sh"

# Define steps as arrays
local step1=(
    "multiselect"
    "ℹ️  Which services would you like to install?"
    "Sensor readings"
    "IAQ (Air quality calculation, Safe to open flag)"
    "Heat soak detection"
)

local step2=(
    "select"
    "ℹ️  Which installation(s) would you like to perform?"
    "Standalone MQTT"
    "HA MQTT Receipt"
    "HA Custom Integration"
)

local step3=(
    "toggle"
    "ℹ️  Install Mosquitto MQTT broker?"
    "true"  # Initial value (true/false or Y/N)
)

# Run the wizard
iwizard_run "BME680 Service Installation" step1 step2 step3
```

### Features

- **Dynamic message accumulation**: Each step shows all previous step messages
- **Back navigation**: Steps after the first have a `[b] Back` option
- **Preselection**: Can use `--preselect` flag in step arrays
- **Automatic line clearing**: Handles clearing previous steps automatically
- **Uses iPrompt internally**: Consistent prompt handling across all types

### Step Array Format

```
step_array=(
    "prompt_type"      # multiselect, select, toggle, confirm, text, number, etc.
    "message"          # Display message (can include emoji)
    "option1"          # First option (for select/multiselect)
    "option2"          # Second option
    ...
    "--preselect" "0 1 2"  # Optional: preselected indices
    "--initial" "value"    # Optional: initial value
    "--limit" "10"         # Optional: limit (for autocomplete)
)
```

## Prompt Types Available

All 11 prompt types from the original library are now implemented:

1. **text** - Free text input
2. **password** - Masked password input  
3. **invisible** - Invisible input (like sudo)
4. **number** - Numeric input with min/max validation
5. **confirm** - Yes/No confirmation
6. **list** - List input that returns an array
7. **toggle** - Interactive toggle/switch
8. **select** - Single-select menu with arrow navigation
9. **multiselect** - Multi-select menu with space to toggle
10. **autocomplete** - Searchable autocomplete prompt
11. **date** - Date input prompt

## Migration Path

The old monolithic `iMenu.sh` (1600+ lines) has been split into:
- **Core modules** (shared utilities) - ~100 lines each
- **Individual prompt files** (one per prompt type) - ~200-300 lines each
- **iPrompt** (single prompt abstraction) - ~150 lines
- **iWizard** (multi-step flows) - ~120 lines

All existing code using `imenu_multiselect`, `imenu_select`, etc. continues to work unchanged.

## Benefits

- **Modular**: Each prompt type is in its own file for easy maintenance
- **Layered architecture**: Clear separation between core, prompts, abstraction, and wizard
- **Smaller files**: Easier to understand and modify individual components
- **Consistent structure**: All prompts follow the same pattern
- **Dynamic messages**: iWizard accumulates messages from previous steps automatically
- **Cleaner API**: Define steps as arrays instead of complex function calls
- **Backward compatible**: Existing code continues to work
- **Unified abstraction**: iPrompt provides consistent interface for all prompt types

