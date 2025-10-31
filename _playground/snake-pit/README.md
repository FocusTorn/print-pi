# Snake Pit - Python Script Ecosystem

Central repository for all Python scripts and projects.

## Quick Start

**Fresh install (bootstrap):**
```bash
_playground/_scripts/bootstraps/bootstrap-snake-pit.sh
```

This installs `uv`, creates virtual environment, and installs requirements.

## Structure

```
snake-pit/
├── .venv/                 # Main shared environment
├── README.md              # This file
├── .gitignore             # Git ignores
├── requirements.txt       # Shared dependencies
└── projects/              # Individual projects
    ├── bme680-monitor/   # BME680 sensor monitoring
    │   ├── venv/         # Project-specific venv (if needed)
    │   └── requirements.txt
    └── [future projects]  # More projects as needed
```

## Environment Strategy

**Two-tier approach:**

1. **Main `.venv/`**: Shared dependencies used by multiple projects
   - Common libraries (e.g., `requests`, `click`, `rich`)
   - Shared utilities

2. **Project `.venv/`**: Project-specific dependencies
   - Hardware-specific (e.g., `adafruit-circuitpython-bme680`)
   - Containing conflicting versions
   - Completely isolated environments

## Setup

### Main Environment

```bash
cd /home/pi/_playground/snake-pit
source .venv/bin/activate  # or just: uv run <command>
uv pip install <shared-package>
```

### Creating a New Project

**Option 1: Use shared venv only**
```bash
# Add to shared dependencies
cd /home/pi/_playground/snake-pit
uv pip install <package>

# Create project
mkdir -p projects/my-project
touch projects/my-project/app.py
```

**Option 2: Project-specific venv**
```bash
# Create isolated environment for conflicting dependencies
cd /home/pi/_playground/snake-pit/projects/my-project
uv venv
source venv/bin/activate
uv pip install <package>
```

## Running Projects

**From main venv:**
```bash
cd /home/pi/_playground/snake-pit
uv run python projects/my-project/app.py
```

**From project venv:**
```bash
cd /home/pi/_playground/snake-pit/projects/my-project
source venv/bin/activate
python app.py
```

## Using uv

**Main commands:**
- `uv venv` - Create virtual environment
- `uv pip install <package>` - Install package
- `uv pip list` - List installed packages
- `uv pip freeze > requirements.txt` - Export requirements
- `uv run <command>` - Run command in venv without activating
- `uv python list` - List available Python versions

**Examples:**
```bash
# Install to main venv
cd /home/pi/_playground/snake-pit
uv pip install requests

# Install to project venv
cd projects/bme680-monitor
uv venv
uv pip install adafruit-circuitpython-bme680
```

## Cursor AI Rules

**⚠️ Reference:** See `~/.cursor/rules/workspace-architecture.mdc` for workspace-wide detour/bootstrap principles.

Project-specific rules guide Cursor's AI assistance:
- `python-standards.mdc` - PEP 8, type hints, docstrings
- `project-structure.mdc` - Monorepo layout and organization
- `hardware-raspberry-pi.mdc` - GPIO/I2C/SPI integration patterns

Rules are automatically applied when editing Python files in snake-pit.

