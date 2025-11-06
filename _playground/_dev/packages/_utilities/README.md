# Utilities

Shared utility packages for `_dev/packages/` ecosystem.

## Structure

Utilities are self-contained packages that can be imported by other packages, similar to npm packages in JavaScript/TypeScript projects.

```
_utilities/
├── logger/           # Logging library
│   ├── logger.sh     # Main logger script
│   ├── import.sh     # Import helper
│   └── README.md     # Documentation
└── [other-utils]/    # Other utilities
```

## Available Utilities

### Logger (`logger/`)

Bash/zsh logging library with scope, debug mode, and loading indicators.

**Quick Import:**
```bash
source "/home/pi/_playground/_dev/packages/_utilities/logger/import.sh"
```

See [logger/README.md](./logger/README.md) for full documentation.

## Usage Pattern

### From a Package Script

```bash
#!/bin/bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Import utility
source "${SCRIPT_DIR}/../_utilities/logger/import.sh"

# Use it
logger_init "my-package"
logger_info "Hello from utility!"
```

### Helper Function Pattern

For packages that import multiple utilities, create a helper:

```bash
_import_utility() {
    local util_name="$1"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local util_path="${script_dir}/../_utilities/${util_name}/import.sh"
    
    if [ -f "$util_path" ]; then
        source "$util_path"
        return 0
    else
        echo "ERROR: Utility '${util_name}' not found at ${util_path}" >&2
        return 1
    fi
}

# Use it
_import_utility "logger" || exit 1
logger_init "my-package"
```

## Adding New Utilities

1. Create directory: `_utilities/my-utility/`
2. Add main script(s)
3. Create `import.sh` if needed (for cleaner imports)
4. Add `README.md` with documentation
5. Update this README to list the new utility

## Design Principles

- **Self-contained**: Each utility should work independently
- **Importable**: Use `import.sh` pattern for clean imports
- **Documented**: Always include README with usage examples
- **Namespaced**: Prefix functions/variables to avoid conflicts (e.g., `logger_*`, `_LOGGER_*`)
