# Product Requirements Document: iPrompt Module

## Overview

iPrompt is the public interface for running single-use prompts. It provides a clean, unified API for all prompt types while keeping the actual prompt implementations internal in the _prompts library.

## Goals

1. **Simple API**: Easy-to-use interface for single prompts
2. **Type Routing**: Automatically route to correct prompt type
3. **Flag Parsing**: Handle all prompt-specific flags
4. **Configuration**: Apply appropriate presets based on prompt type
5. **Consistency**: Uniform interface across all prompt types

## API Design

### Primary Function: `iprompt_run()`

```bash
# Basic usage
result=$(iprompt_run "confirm" "Do you agree?" "--initial" "true")

# With options
result=$(iprompt_run "multiselect" "Choose options:" "Option 1" "Option 2" "--preselect" "0")

# With name for result storage
result=$(iprompt_run "my_choice" "select" "Choose one:" "A" "B" "C")
```

### Function Signature

```bash
iprompt_run([name] type message [options...] [flags...])
```

**Parameters**:
- `name` (optional): Name for storing result in response map
- `type`: Prompt type (confirm, text, multiselect, select, number, list, toggle, password, invisible, autocomplete, date)
- `message`: Prompt message/question
- `options`: Type-specific options (choices for select/multiselect, initial value, etc.)
- `flags`: Type-specific flags (--initial, --preselect, --min, --max, etc.)

**Returns**:
- Result value on stdout
- Exit code: 0 = success, 1 = cancel, 2 = back (if applicable)

## Supported Prompt Types

### confirm
```bash
iprompt_run "confirm" "Do you agree?" "--initial" "true"
```

### text
```bash
iprompt_run "text" "Enter your name:" "--initial" "John"
```

### multiselect
```bash
iprompt_run "multiselect" "Choose options:" "Option 1" "Option 2" "--preselect" "0"
```

### select
```bash
iprompt_run "select" "Choose one:" "Option A" "Option B" "Option C"
```

### number
```bash
iprompt_run "number" "Enter age:" "--initial" "25" "--min" "0" "--max" "120"
```

### list
```bash
iprompt_run "list" "Enter items:" "--initial" "item1,item2" "--separator" ","
```

### toggle
```bash
iprompt_run "toggle" "Enable feature?" "false" "Yes" "No"
```

### password
```bash
iprompt_run "password" "Enter password:"
```

### invisible
```bash
iprompt_run "invisible" "Enter secret:"
```

### autocomplete
```bash
iprompt_run "autocomplete" "Search:" "Option 1" "Option 2" "Option 3"
```

### date
```bash
iprompt_run "date" "Enter date:" "--format" "YYYY-MM-DD"
```

## Flag Parsing

### Common Flags
- `--initial <value>`: Initial/default value
- `--message <text>`: Override message (if provided as option)

### Type-Specific Flags

**multiselect**:
- `--preselect <indices>`: Space-separated indices to preselect

**number**:
- `--min <value>`: Minimum value
- `--max <value>`: Maximum value

**list**:
- `--separator <char>`: Separator character (default: ",")

**date**:
- `--format <format>`: Date format string

## Configuration Presets

iPrompt automatically applies appropriate presets based on prompt type:

**Input Prompts** (text, password, invisible, number, list, date):
- No blank line after message
- Inline input display

**Selection Prompts** (multiselect, select, confirm, toggle, autocomplete):
- Blank line after message
- Gap before options

## Implementation

### Core Components

**File**: `iPrompt/iPrompt.sh`
- Main entry point
- Sources _shared/ and _prompts/
- Provides `iprompt_run()` function

**File**: `iPrompt/core/prompt-dispatcher.sh`
- Routes to appropriate _prompts function
- Parses flags and options
- Applies configuration presets
- Handles result formatting

### Function Flow

1. Parse arguments (name, type, message, options, flags)
2. Extract flags from options array
3. Apply configuration preset based on type
4. Route to appropriate `_prompt_*()` function in _prompts/
5. Return result and exit code

## Error Handling

- Invalid prompt type → error message, exit code 1
- Missing required arguments → error message, exit code 1
- Invalid flag values → error message, exit code 1
- User cancellation (ESC) → exit code 1
- User back (if applicable) → exit code 2

## Testing

### Test Coverage
- Each prompt type via iPrompt
- Flag parsing for each type
- Configuration presets
- Error handling
- Result formatting

### Test Files
- `iPrompt/tests/test_prompts.bats` - Tests for each prompt type
- `iPrompt/tests/test_flags.bats` - Tests for flag parsing
- `iPrompt/tests/test_config.bats` - Tests for configuration presets

## Dependencies

- **Requires**: _shared/ (core utilities)
- **Requires**: _prompts/ (internal prompt library)
- **Provides**: Public API for single prompts

## Future Enhancements

- Custom formatting functions
- Validation callbacks
- Conditional prompts
- Dynamic option generation

