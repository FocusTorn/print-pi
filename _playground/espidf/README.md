# ESP-IDF Development Directory

This directory contains ESP-IDF (Espressif IoT Development Framework) projects, documentation, and helper scripts.

## Directory Structure

```
espidf/
├── _docs/          # Documentation and guides
├── _scripts/       # Helper scripts for ESP-IDF development
└── projects/       # ESP-IDF projects
```

## Quick Start

### 1. Bootstrap ESP-IDF

First, install ESP-IDF using the bootstrap script:

```bash
_playground/_scripts/bootstraps/bootstrap-esp-idf.sh
```

This will:
- Install ESP-IDF framework to `~/esp/esp-idf`
- Set up the development environment
- Create project templates

### 2. Activate ESP-IDF Environment

```bash
get_idf
```

### 3. Create a New Project

```bash
# Copy template
cp -r ~/_playground/espidf/projects/hello_world_template my_project

# Or use helper script (if available)
cd ~/_playground/espidf
./_scripts/new-project.sh my_project
```

### 4. Build and Flash

```bash
cd my_project
idf.py set-target esp32s3
idf.py build
idf.py -p /dev/ttyUSB0 flash
idf.py -p /dev/ttyUSB0 monitor
```

## Helper Scripts

See `_scripts/` directory for ESP-IDF-specific helper scripts.

## Documentation

See `_docs/` directory for detailed guides and documentation.

## Related

- **Arduino Development**: `~/_playground/arduino/` - Arduino IDE projects
- **Bootstrap Script**: `~/_playground/_scripts/bootstraps/bootstrap-esp-idf.sh`


