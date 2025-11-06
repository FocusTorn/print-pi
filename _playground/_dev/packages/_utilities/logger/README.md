# Logger Utility

Bash/zsh logging library inspired by TypeScript/JavaScript logger patterns.

## Installation / Import

### Method 1: Using import.sh (Recommended)

The cleanest way, similar to JS/TS imports:

```bash
source "/home/pi/_playground/_dev/packages/_utilities/logger/import.sh"
```

Or from a package script using relative path:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utilities/logger/import.sh"
```

### Method 2: Direct source

```bash
source "/home/pi/_playground/_dev/packages/_utilities/logger/logger.sh"
```

### Method 3: Package Helper Function

For packages in `_dev/packages/`, you can create a reusable helper:

```bash
_import_logger() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local utilities_dir="${script_dir}/../_utilities/logger"
    if [ -f "${utilities_dir}/import.sh" ]; then
        source "${utilities_dir}/import.sh"
        return 0
    else
        echo "ERROR: Logger not found at ${utilities_dir}/import.sh" >&2
        return 1
    fi
}

# Use it
_import_logger || exit 1
logger_init "my-package"
```
