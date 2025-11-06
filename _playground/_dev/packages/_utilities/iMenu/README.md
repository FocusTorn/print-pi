# iMenu - Interactive Menu Library for Bash

Bash implementation of an interactive menu system inspired by the `prompts` npm library. Provides a comprehensive set of interactive prompt types for building CLI applications with a consistent, user-friendly interface.


## Not implemented
1. Prompt chains (array of prompts) — The JS library accepts an array of prompt objects and processes them sequentially. Currently only individual function calls are supported.

<!-- 2. Object-based API — The JS library uses prompt objects like {type: 'text', name: 'username', message: '...'}, while this uses function calls like imenu_text name message. -->

3. Dynamic prompts — Properties can be functions evaluated based on previous answers. Partially supported via function parameters, but not as seamless.

4. onSubmit callback — Called after each prompt submission; can return true to quit early.

5. onCancel callback — Called on cancel; can return true to prevent aborting.

6. override() function — Pre-answer questions from command-line args or other sources (partially started, not functional).

<!-- 7. inject() function — For testing; inject responses programmatically (partially started, not functional). -->

8. onRender callback — Called when prompt is rendered (for custom rendering).

9. onState callback — Called when prompt state changes (for custom behavior).

<!-- 10. autocompleteMultiselect — Separate type from regular multiselect (both are searchable multiselects in JS). -->













## Features

- **Multiple prompt types**: 
  - `text` - Free text input
  - `password` - Masked password input
  - `invisible` - Invisible input (like sudo)
  - `number` - Numeric input with min/max validation
  - `confirm` - Yes/No confirmation
  - `list` - List input that returns an array
  - `toggle` - Interactive toggle/switch
  - `select` - Single-select menu with arrow navigation
  - `multiselect` - Multi-select menu with space to toggle
  - `autocomplete` - Searchable autocomplete prompt
  - `date` - Date input prompt
- **Consistent styling**: Uses color scheme matching other interactive menus in the project
- **Terminal-aware**: Properly handles cursor control, colors, and escape sequences
- **Flexible API**: Function-based API that's natural for bash
- **Validation support**: Optional validation functions for input
- **Formatting support**: Optional formatting functions for output

## Quick Start

```bash
# Import the library
source "/home/pi/_playground/_dev/packages/_utilities/iMenu/import.sh"

# Use prompts
username=$(imenu_text "username" "What is your GitHub username?")
age=$(imenu_number "age" "How old are you?" 0)
confirmed=$(imenu_confirm "confirm" "Can you confirm?" true)
```

## Installation

The library is already available in the `_utilities` directory. Simply source it:

```bash
source "/home/pi/_playground/_dev/packages/_utilities/iMenu/import.sh"
```

Or use a relative path from your script:

```bash
source "$(dirname "$0")/../_utilities/iMenu/import.sh"
```

## Prompt Types

### Text Prompt

Basic text input prompt.

```bash
imenu_text name message [initial] [style] [validate_func] [format_func]
```

**Parameters:**
- `name`: Response key name
- `message`: Prompt message
- `initial`: Default value (optional)
- `style`: `default`, `password`, or `invisible` (optional)
- `validate_func`: Validation function name (optional)
- `format_func`: Formatting function name (optional)

**Example:**
```bash
username=$(imenu_text "username" "What is your GitHub username?")
about=$(imenu_text "about" "Tell something about yourself" "Why should I?")
```

### Password Prompt

Password input with masked characters.

```bash
imenu_password name message [initial] [validate_func] [format_func]
```

**Example:**
```bash
password=$(imenu_password "password" "Enter password")
```

### Invisible Prompt

Invisible input (like sudo password).

```bash
imenu_invisible name message [initial] [validate_func] [format_func]
```

**Example:**
```bash
secret=$(imenu_invisible "secret" "Enter secret")
```

### Number Prompt

Numeric input with optional min/max validation.

```bash
imenu_number name message [initial] [min] [max] [validate_func] [format_func]
```

**Example:**
```bash
age=$(imenu_number "age" "How old are you?" 0 0 120)
price=$(imenu_number "price" "Enter price" 0 0)
```

### Confirm Prompt

Yes/No confirmation prompt.

```bash
imenu_confirm name message [initial] [format_func]
```

**Parameters:**
- `initial`: `true` or `false` (default: `false`)

**Example:**
```bash
confirmed=$(imenu_confirm "confirm" "Can you confirm?" true)
if [ "$confirmed" = "true" ]; then
    echo "Confirmed!"
fi
```

### List Prompt

List input that returns an array (space-separated).

```bash
imenu_list name message [initial] [separator] [format_func]
```

**Parameters:**
- `separator`: Separator character (default: `,`)

**Example:**
```bash
keywords=$(imenu_list "keywords" "Enter keywords" "" ",")
# Returns: "keyword1 keyword2 keyword3"
```

### Toggle Prompt

Interactive toggle/switch prompt.

```bash
imenu_toggle name message [initial] [active] [inactive] [format_func]
```

**Parameters:**
- `initial`: `true` or `false` (default: `false`)
- `active`: Text for active state (default: `on`)
- `inactive`: Text for inactive state (default: `off`)

**Example:**
```bash
enabled=$(imenu_toggle "enabled" "Enable feature?" false "yes" "no")
```

### Select Prompt

Single-select menu with arrow key navigation.

```bash
imenu_select name message choice1 choice2 ... [options]
```

**Options (via environment variables):**
- `IMENU_INITIAL`: Initial selection index (default: 0)
- `IMENU_HINT`: Hint text to display
- `IMENU_FORMAT`: Formatting function name

**Example:**
```bash
IMENU_INITIAL=1
color_idx=$(imenu_select "color" "Pick a color" "Red" "Green" "Blue")
# Returns: index (0, 1, or 2)
```

### Multiselect Prompt

Multi-select menu with space to toggle, 'a' to select all.

```bash
imenu_multiselect name message choice1 choice2 ... [options]
```

**Options (via environment variables):**
- `IMENU_MAX`: Maximum selections allowed
- `IMENU_MIN`: Minimum selections required
- `IMENU_HINT`: Hint text to display
- `IMENU_FORMAT`: Formatting function name

**Example:**
```bash
IMENU_MAX=2
IMENU_HINT="Space to select. Return to submit"
selected=$(imenu_multiselect "colors" "Pick colors" "Red" "Green" "Blue")
# Returns: space-separated indices (e.g., "0 2")
```

**Controls:**
- `↑/↓`: Navigate
- `Space`: Toggle selection
- `a`: Select all / Deselect all
- `Enter`: Submit
- `q`/`ESC`: Cancel

### Autocomplete Prompt

Searchable autocomplete prompt.

```bash
imenu_autocomplete name message choice1 choice2 ... [options]
```

**Options (via environment variables):**
- `IMENU_INITIAL`: Initial search string
- `IMENU_LIMIT`: Maximum results to show (default: 10)
- `IMENU_FORMAT`: Formatting function name

**Example:**
```bash
IMENU_INITIAL=""
IMENU_LIMIT=5
actor=$(imenu_autocomplete "actor" "Pick your favorite actor" \
    "Cage" "Clooney" "Gyllenhaal" "Gibson" "Grant")
```

**Controls:**
- Type to filter
- `↑/↓`: Navigate filtered results
- `Enter`: Select highlighted item
- `Backspace`: Delete character
- `q`/`ESC`: Cancel

### Date Prompt

Date input prompt (simplified implementation).

```bash
imenu_date name message [initial] [mask] [validate_func] [format_func]
```

**Parameters:**
- `mask`: Date format mask (default: `%Y-%m-%d %H:%M:%S`)

**Example:**
```bash
birthday=$(imenu_date "birthday" "Pick a date" "" "%Y-%m-%d")
```

## Validation Functions

You can provide validation functions that return `true` for valid input or an error message string for invalid input.

```bash
validate_age() {
    local age="$1"
    if [ "$age" -lt 18 ]; then
        echo "Must be 18 or older"
        return 1
    fi
    echo "true"
}

age=$(imenu_number "age" "How old are you?" 0 0 120 "validate_age")
```

## Formatting Functions

You can provide formatting functions to transform the input before storing.

```bash
format_currency() {
    local value="$1"
    printf "$%.2f" "$value"
}

price=$(imenu_number "price" "Enter price" 0 0 "" "format_currency")
```

## Response Management

### Get Response by Name

```bash
username=$(imenu_get_response "username")
```

### Get All Responses

```bash
imenu_get_all_responses
# Outputs: name=value pairs
```

## Styling

The library uses the following color scheme (matching project standards):
- `CYAN`: Prompt indicator (`?`)
- `GREEN`: Success/selected items
- `YELLOW`: Warnings/default negative
- `RED`: Errors
- `DIM`: Hints/default values

## Prompt Chains

Process multiple prompts sequentially with dynamic evaluation:

```bash
#!/bin/bash
source "/home/pi/_playground/_dev/packages/_utilities/iMenu/import.sh"

# Create prompt objects
prompt1=$(imenu_prompt "text" "username" "What is your GitHub username?")
prompt2=$(imenu_prompt "number" "age" "How old are you?" "initial=0")
prompt3=$(imenu_prompt "text" "about" "Tell something about yourself" "initial=Why should I?")

# Create array of prompts
prompts=("$prompt1" "$prompt2" "$prompt3")

# Process chain
imenu prompts

# Get responses
username=$(imenu_get_response "username")
age=$(imenu_get_response "age")
about=$(imenu_get_response "about")
```

## Dynamic Prompts

Prompt properties can be functions that are evaluated based on previous answers:

```bash
#!/bin/bash
source "/home/pi/_playground/_dev/packages/_utilities/iMenu/import.sh"

# Dynamic type function
dynamic_type() {
    local prev="$1"
    if [ "$prev" = "pizza" ]; then
        echo "text"
    else
        echo ""  # Skip this prompt
    fi
}

# Create prompts
prompt1=$(imenu_prompt "text" "dish" "Do you like pizza?")
prompt2=$(imenu_prompt "text" "topping" "Name a topping" "type=dynamic_type")

prompts=("$prompt1" "$prompt2")
imenu prompts
```

## Callbacks

### onSubmit Callback

Called after each prompt submission. Return `true` to quit the chain early:

```bash
#!/bin/bash
source "/home/pi/_playground/_dev/packages/_utilities/iMenu/import.sh"

# Callback function
on_submit() {
    local prompt_ref="$1"
    local answer="$2"
    local values_ref="$3"
    
    echo "Got answer: $answer" >&2
    
    # Quit early if age is 0
    if [ "$answer" = "0" ]; then
        echo "true"  # Quit chain
    else
        echo "false"  # Continue
    fi
}

prompt1=$(imenu_prompt "number" "age" "How old are you?" "initial=0")
prompts=("$prompt1")
imenu prompts "on_submit"
```

### onCancel Callback

Called when user cancels. Return `true` to prevent aborting:

```bash
#!/bin/bash
source "/home/pi/_playground/_dev/packages/_utilities/iMenu/import.sh"

# Callback function
on_cancel() {
    local prompt_ref="$1"
    local values_ref="$2"
    
    echo "Never stop prompting!" >&2
    echo "true"  # Continue despite cancel
}

prompt1=$(imenu_prompt "text" "username" "What is your GitHub username?")
prompts=("$prompt1")
imenu prompts "" "on_cancel"
```

## Override Function

Pre-answer questions from command-line args or other sources:

```bash
#!/bin/bash
source "/home/pi/_playground/_dev/packages/_utilities/iMenu/import.sh"

# Override with key=value pairs
imenu_override "username=terkelg" "age=30"

# Or use an associative array
declare -A overrides=([username]="terkelg" [age]="30")
imenu_override overrides

# Now prompts will use these values
prompt1=$(imenu_prompt "text" "username" "What is your GitHub username?")
prompt2=$(imenu_prompt "number" "age" "How old are you?")
prompts=("$prompt1" "$prompt2")
imenu prompts

# Responses will be the overridden values
```

## Inject Function

For testing - programmatically inject responses:

```bash
#!/bin/bash
source "/home/pi/_playground/_dev/packages/_utilities/iMenu/import.sh"

# Inject values (will be used in order)
imenu_inject "@terkelg" "30"

prompt1=$(imenu_prompt "text" "twitter" "What's your twitter handle?")
prompt2=$(imenu_prompt "number" "age" "How old are you?")
prompts=("$prompt1" "$prompt2")
imenu prompts

# Responses will be the injected values
```

## Complete Form Example

```bash
#!/bin/bash
source "/home/pi/_playground/_dev/packages/_utilities/iMenu/import.sh"

# Prompt chain
prompt1=$(imenu_prompt "text" "username" "What is your GitHub username?")
prompt2=$(imenu_prompt "number" "age" "How old are you?" "initial=0")
prompt3=$(imenu_prompt "confirm" "confirm" "Can you confirm?" "initial=false")

prompts=("$prompt1" "$prompt2" "$prompt3")
imenu prompts

# Get responses
username=$(imenu_get_response "username")
age=$(imenu_get_response "age")
confirmed=$(imenu_get_response "confirm")

if [ "$confirmed" = "true" ]; then
    echo "Username: $username"
    echo "Age: $age"
fi
```

## Advanced: Select Menu with Choices

```bash
#!/bin/bash
source "/home/pi/_playground/_dev/packages/_utilities/iMenu/import.sh"

# Create prompt with choices
choices=$(imenu_choices "Red" "Green" "Blue" "Yellow")
prompt1=$(imenu_prompt "select" "color" "Pick a color" "choices=$choices" "initial=1")

prompts=("$prompt1")
imenu prompts

color_idx=$(imenu_get_response "color")
colors=("Red" "Green" "Blue" "Yellow")
echo "Selected: ${colors[$color_idx]}"
```

## Examples

```bash
#!/bin/bash
source "/home/pi/_playground/_dev/packages/_utilities/iMenu/import.sh"

# Prompt chain
username=$(imenu_text "username" "What is your GitHub username?")
age=$(imenu_number "age" "How old are you?" 0 0 120)
confirmed=$(imenu_confirm "confirm" "Can you confirm?" false)

if [ "$confirmed" = "true" ]; then
    echo "Username: $username"
    echo "Age: $age"
fi
```

### Select Menu Example

```bash
#!/bin/bash
source "/home/pi/_playground/_dev/packages/_utilities/iMenu/import.sh"

IMENU_INITIAL=1
color_idx=$(imenu_select "color" "Pick a color" \
    "Red" "Green" "Blue" "Yellow")

colors=("Red" "Green" "Blue" "Yellow")
echo "Selected: ${colors[$color_idx]}"
```

### Multiselect Example

```bash
#!/bin/bash
source "/home/pi/_playground/_dev/packages/_utilities/iMenu/import.sh"

IMENU_MAX=3
IMENU_MIN=1
selected=$(imenu_multiselect "features" "Select features" \
    "Feature A" "Feature B" "Feature C" "Feature D")

features=("Feature A" "Feature B" "Feature C" "Feature D")
for idx in $selected; do
    echo "Selected: ${features[$idx]}"
done
```

## Keyboard Controls

### Common Controls
- `Enter`: Submit/Confirm
- `ESC`: Cancel
- `q`: Quit/Cancel
- `↑/↓`: Navigate (in select menus)
- `Space`: Toggle (in multiselect/toggle)

### Multiselect Specific
- `a`: Select all / Deselect all
- `Space`: Toggle current item

### Autocomplete Specific
- Type to filter
- `Backspace`: Delete character
- `↑/↓`: Navigate filtered results

## Notes

- All display output goes to `stderr` so prompts remain visible even when stdout is captured
- Responses are stored in an associative array and can be retrieved via `imenu_get_response()`
- The library automatically cleans up cursor state on exit
- Terminal colors are automatically disabled when output is not a TTY

## Compatibility

- Requires bash 4.0+ (for associative arrays)
- Uses `tput` for terminal control (falls back to ANSI escapes)
- Compatible with zsh (tested)

## See Also

- Reference implementation: `/home/pi/_playground/_dev/packages/bme680-service/scripts/interactive-menu.sh`
- JavaScript inspiration: `prompts` npm library

