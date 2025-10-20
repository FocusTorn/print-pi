# Compare to Clean

A comprehensive tool for comparing your current system against a clean reference image, helping identify exactly what has changed since Day 0.

## Location

```bash
/home/pi/_playground/_scripts/compare-to-clean/
```

## Files

- `compare-to-clean.sh` - Main comparison script
- `exclusion-rules.conf` - Configuration file for automatic file classification
- `README.md` - This documentation

## Quick Start

### Basic Usage

Compare a directory against the clean-pi reference:

```bash
cd /home/pi/_playground/_scripts/compare-to-clean
bash compare-to-clean.sh /etc
```

### With Classification

Show whether files were modified by the system or by you:

```bash
bash compare-to-clean.sh -s /etc
```

### Show Only User Changes

Exclude automatic system modifications:

```bash
bash compare-to-clean.sh -e /etc
```

### Detailed Exclusion Report

See what was excluded and why:

```bash
bash compare-to-clean.sh -r /etc
```

## Features

### Automatic File Classification

The script automatically classifies files into three categories:

- **SYSTEM**: Files modified automatically by the system (package updates, caches, etc.)
- **USER**: Files likely modified by user actions (configs, customizations)
- **UNKNOWN**: Files that don't match known patterns

### Smart Exclusion Rules

Built-in rules automatically identify and optionally exclude:

- CUPS printer system files
- Package management caches
- System service auto-generated files
- Network auto-configuration
- Temporary files and caches

### Day 0 Cutoff

Only shows files created or modified after the initial Day 0 timestamp, filtering out all pre-existing system files.

## Command Options

```
-c, --cutoff DATETIME          Override Day 0 cutoff
-v, --verbose                  Show detailed file comparison
-d, --diff                     Show content differences
-e, --exclude-system           Exclude system-modified files
-s, --show-classification      Show file classifications
-r, --exclusion-report         Show detailed exclusion report
-h, --help                     Show help
```

## Common Use Cases

### Find All User Modifications

```bash
# Show only files you intentionally modified
bash compare-to-clean.sh -e -s /etc
```

### Track Configuration Changes

```bash
# See what changed in your home directory
bash compare-to-clean.sh -s /home/pi
```

### Audit System Changes

```bash
# Full report with classifications
bash compare-to-clean.sh -r -s /etc
```

### See Actual Differences

```bash
# Show file content diffs with classifications
bash compare-to-clean.sh -d -s /etc/fstab
```

## Output Format

The script uses the shared formatting library for consistent, beautiful output:

- **Header**: Centered title box
- **Sections**: Organized comparison results
- **Subsections**: Categorized file lists
- **Info Lines**: Key-value parameter display
- **Color Coding**: Visual distinction between file types

## Exclusion Configuration

Edit `exclusion-rules.conf` to customize:

- System file patterns
- User file patterns
- Content-based classification rules
- Exclusion behavior

The configuration file is automatically created with sensible defaults on first run.

## Requirements

- Clean-pi reference image mounted at:
  - `/media/pi/clean-pi/rootfs` (root filesystem)
  - `/media/pi/clean-pi/bootfs` (boot partition)
- Bash 4.0+
- Standard Unix utilities (find, diff, etc.)

## Integration

This script uses the shared formatting library located at:

```bash
/home/pi/_playground/_scripts/lib/formatting.sh
```

Any script can use the same beautiful formatting by sourcing this library.

## Tips

1. **Mount Clean-Pi First**: Ensure your clean reference image is mounted before running
2. **Start with `/etc`**: Good first directory to check for system configuration changes
3. **Use Classifications**: The `-s` flag helps identify intentional vs automatic changes
4. **Exclude System Files**: Use `-e` to focus on what you actually changed
5. **Review Exclusions**: Use `-r` to ensure nothing important is being filtered out

## Examples

### Example 1: Quick System Audit

```bash
# See what changed in /etc with classifications
bash compare-to-clean.sh -s /etc
```

Output shows files marked as (SYSTEM), (USER), or (UNKNOWN)

### Example 2: User Changes Only

```bash
# Focus on intentional modifications
bash compare-to-clean.sh -e -s /etc
```

Filters out automatic system changes

### Example 3: Home Directory Changes

```bash
# Track user environment changes
bash compare-to-clean.sh /home/pi
```

Shows all new/modified files in your home directory

### Example 4: Boot Configuration

```bash
# Check boot partition changes
bash compare-to-clean.sh /boot/firmware
```

Compares against clean boot files

## Customization

### Adding New System Patterns

Edit `exclusion-rules.conf` and add to `SYSTEM_PATTERNS`:

```bash
SYSTEM_PATTERNS+=(
    "/your/pattern/*"
    "/another/specific/file"
)
```

### Adding New User Patterns

Add to `USER_PATTERNS` for files you know are user-modified:

```bash
USER_PATTERNS+=(
    "/etc/your-custom-config"
    "/home/pi/.your-rc-file"
)
```

## Output Example

```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                                                                     ┃
┃                        COMPARE TO CLEAN                             ┃
┃                                                                     ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

┌── Comparison Parameters
│  Comparing: /etc
│  Against: /media/pi/clean-pi/rootfs/etc
│  Cutoff: 2025-09-30 19:17:09
│  Active modes: Showing file classifications

┌─────────────────────────────────────────────────────────────────────┐
│  COMPARISON SUMMARY                                                 │
└─────────────────────────────────────────────────────────────────────┘

┌── File Classifications
│  System files: 1
│  User files: 8
│  Unknown files: 14
│  Excluded files: 1

┌── Modified files (13)
  /fstab (USER)
  /passwd (USER)
  /group (USER)
  ...

┌── Totals
│  Total changes: 16
│  Total excluded: 1
```

## Notes

- The script uses `-xdev` to avoid crossing filesystem boundaries
- Binary files are detected and marked appropriately
- Symbolic links are followed for comparison
- Deleted files (in clean-pi but not in system) are tracked separately

