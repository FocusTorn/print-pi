# iMenu Test Suite

## Overview

The iMenu test suite provides unit testing for the iMenu library components.

## Test Structure

```
tests/
├── test_helper.bash      # Test utilities and helpers
├── config.bats           # BATS tests for config system
├── prompts_*.bats        # BATS tests for individual prompt types
└── run_tests.sh          # Simple test runner (no dependencies)
```

## Running Tests

### Option 1: BATS Framework (Recommended)

BATS provides colorized output by default when run in a terminal.

**Basic usage:**
```bash
bats tests/
```

**Colored checkmarks (recommended):**
```bash
# Use the helper script for colored checkmarks:
# ✔ (green, bold) for passing tests
# ✗ (red) for failing tests  
# 🞉 (yellow) for skipped tests
./tests/run_bats.sh tests/
```

**Note:** If you're not seeing colored output, your terminal might be detected as non-color-capable. Try:

```bash
# Set TERM to a color-capable terminal type
TERM=xterm-256color bats tests/

# Or use the helper script (automatically sets TERM and colors checkmarks)
./tests/run_bats.sh tests/
```

**Run specific test file:**
```bash
bats tests/prompts_text.bats
```

**Colorization Options:**

BATS automatically uses colored output when run in a terminal. You can control this behavior:

```bash
# Use pretty formatter (default, with colors)
bats --formatter pretty tests/

# Disable colors
NO_COLOR=1 bats tests/

# Use TAP format (no colors, machine-readable)
bats --formatter tap tests/

# Use TAP13 format
bats --formatter tap13 tests/

# Use JUnit XML format (for CI/CD)
bats --formatter junit tests/ > test-results.xml
```

**Other useful options:**
```bash
# Count tests without running
bats --count tests/

# Filter tests by name
bats --filter "text prompt" tests/

# Run only failed tests from last run
bats --filter-status failed tests/

# Verbose output (shows each test as it runs)
bats --verbose tests/
```

### Option 2: Simple Test Runner (No Dependencies)

```bash
bash tests/run_tests.sh
```

This runs basic tests without requiring any external dependencies, but without colorization.

## Writing Tests

### BATS Test

Create a `.bats` file:

```bash
#!/usr/bin/env bash
load 'test_helper'

@test "test description" {
    load_iMenu
    run imenu_config_get "NO_MESSAGE_BLANK"
    [ "$status" -eq 0 ]
    [ "$output" = "false" ]
}
```

## Test Coverage

Current test coverage:
- ✅ Config system (get, set, presets, reset)
- ✅ Text prompt (basic input, initial value, inline mode, cancel, **cursor positioning**)
- ✅ Number prompt (basic input, initial value, empty initial, cancel, **cursor positioning**)
- ✅ Password prompt (basic input, empty initial, cancel, back)
- ✅ Invisible prompt (basic input, empty initial, cancel, back)
- ✅ Select prompt (basic selection, initial selection, cancel, back)
- ✅ Multiselect prompt (basic selection, preselect, cancel, back)
- ✅ Toggle prompt (default values, y/n selection, cancel, back)
- ✅ Confirm prompt (default values, y/n selection, select option, cancel, back)
- ✅ List prompt (basic input, empty initial, custom separator, cancel, back, **cursor positioning**)
- ✅ Autocomplete prompt (basic selection, initial selection, cancel, back)
- ✅ Date prompt (basic input, empty initial, custom mask, cancel, back)
- ⏳ iPrompt abstraction layer (needs integration tests)
- ⏳ iWizard multi-step logic (needs integration tests)

### Cursor Position Tests

New cursor positioning tests verify:
- ✅ Cursor is positioned at the end of input text
- ✅ Cursor show/hide functions are called appropriately
- ✅ Cursor positioning works correctly for empty input
- ✅ Cursor positioning works correctly in inline mode

Test files:
- `prompts_text_cursor.bats` - 5 tests for text prompt cursor positioning
- `prompts_number_cursor.bats` - 3 tests for number prompt cursor positioning
- `prompts_list_cursor.bats` - 3 tests for list prompt cursor positioning
- `prompts_password_cursor.bats` - 3 tests for password prompt cursor positioning (newline mode)
- `prompts_date_cursor.bats` - 3 tests for date prompt cursor positioning (newline mode)

## Mocking Interactive Prompts

For testing interactive prompts, you'll need to:
1. Mock `_imenu_read_char` to return test input
2. Capture stderr output
3. Verify expected behavior

Example:
```bash
# Mock input
export TEST_INPUT="test"
load_iMenu

# Run prompt
result=$(imenu_text "test" "Enter:" "" 2>/dev/null)

# Verify
[ "$result" = "test" ]
```

## Future Enhancements

- [ ] Add more comprehensive prompt tests
- [ ] Integration tests for iWizard flows
- [ ] Performance benchmarks
- [ ] Visual regression tests
- [ ] CI/CD integration with JUnit XML output (screenshot comparison)

