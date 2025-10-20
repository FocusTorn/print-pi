# Formatting Library

A reusable bash formatting library with beautiful box-drawing characters and color support.

## Installation

The library is located at:
```bash
/home/pi/_playground/_scripts/lib/formatting.sh
```

## Usage

### Basic Setup

Add this to the top of your script:

```bash
#!/bin/bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the formatting library
source "${SCRIPT_DIR}/lib/formatting.sh"
```

If your script is in the same directory as the `lib/` folder, use:
```bash
source "$(dirname "${BASH_SOURCE[0]}")/lib/formatting.sh"
```

If your script is already in the `lib/` directory, use:
```bash
source "$(dirname "${BASH_SOURCE[0]}")/formatting.sh"
```

### Available Functions

#### `fmt.header "Title Text"`

Creates a large centered header box with dynamic borders.

```bash
fmt.header "SYSTEM INFORMATION GATHERER v1.0"
```

Output:
```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                                                                                             ┃
┃                           SYSTEM INFORMATION GATHERER v1.0                                  ┃
┃                                                                                             ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

#### `fmt.section "Section Title"`

Creates a medium section header with dynamic width adjustment.

```bash
fmt.section "1. SYSTEM IDENTITY"
```

Output:
```
┌─────────────────────────────────────────────────────────────────────────────┐
│  1. SYSTEM IDENTITY                                                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### `fmt.subsection "Subsection Title"` or `fmt.subsection.COLOR "Title"`

Creates a small subsection header with optional color.

```bash
fmt.subsection "Network Configuration"              # Default blue
fmt.subsection.red "Errors Found"                   # Red
fmt.subsection.green "Success"                      # Green
fmt.subsection.yellow "Warnings"                    # Yellow
fmt.subsection.cyan "Info"                          # Cyan
fmt.subsection.magenta "Notes"                      # Magenta
```

Available colors: `red`, `green`, `yellow`, `blue` (default), `cyan`, `magenta`

Output:
```
┌── Network Configuration
```

The color variants provide visual categorization for different types of information.

#### `fmt.info "Label" "Value"`

Displays labeled information with consistent formatting.

```bash
fmt.info "Hostname" "MyP"
fmt.info "IP Address" "192.168.1.159"
```

Output:
```
│  Hostname: MyP
│  IP Address: 192.168.1.159
```

#### `fmt.check_cmd "command" "[flag]"`

Checks if a command exists and displays its version.

```bash
fmt.check_cmd "python3" "--version"
fmt.check_cmd "git" "--version"
fmt.check_cmd "nodejs" "--version"  # Shows "Not installed" if missing
```

Output:
```
✓ python3: Python 3.13.5
✓ git: git version 2.47.3
✗ nodejs: Not installed
```

Default flag is `--version` if not specified.

## Example Script

See `formatting-example.sh` for a complete working example:

```bash
bash /home/pi/_playground/_scripts/lib/formatting-example.sh
```

## Colors Available

The library defines these color variables:
- `BOLD` - Bold text
- `NC` - No color (reset)
- `RED` - Red text
- `GREEN` - Green text
- `YELLOW` - Yellow text
- `BLUE` - Blue text
- `CYAN` - Cyan text

Use them directly in your scripts:
```bash
echo -e "${GREEN}Success!${NC}"
echo -e "${RED}Error!${NC}"
```

## Namespace Style

Functions use the `fmt.` prefix to avoid naming conflicts with other scripts. This creates a clean namespace:
- `fmt.header`
- `fmt.section`
- `fmt.subsection`
- `fmt.info`
- `fmt.check_cmd`

## Customization

### Changing Box Width

Edit the `box_width` variable in `fmt.header()`:

```bash
fmt.header() { #>
    local text="$1"
    local box_width=120  # Change from 95 to 120 for wider boxes
    ...
}
```

### Adding New Functions

Add new functions following the naming convention:

```bash
fmt.error() { #>
    echo -e "${RED}✗ ERROR:${NC} $1"
} #<
```

## Script Integration

### New Scripts

For new scripts, use the `fmt.*` functions directly:

```bash
source "$(dirname "${BASH_SOURCE[0]}")/lib/formatting.sh"

fmt.header "My Script"
fmt.section "Configuration"
fmt.info "Status" "Ready"
```

### Existing Scripts (Backward Compatibility)

For existing scripts, you can create aliases:

```bash
source "$(dirname "${BASH_SOURCE[0]}")/lib/formatting.sh"

# Legacy aliases
alias header='fmt.header'
alias section='fmt.section'
alias info='fmt.info'

# Old code still works
header "My Script"
section "Configuration"
```

## Benefits

✅ **Reusable** - One library, many scripts
✅ **Consistent** - Same formatting across all tools
✅ **Maintainable** - Update once, affects all scripts
✅ **Namespace-safe** - `fmt.*` prefix prevents conflicts
✅ **Dynamic** - Box widths adjust automatically
✅ **Beautiful** - Clean box-drawing characters and colors

## Files

- `formatting.sh` - Main library file
- `formatting-example.sh` - Example usage script
- `README.md` - This documentation

