# Migration from _scripts/detour to _dev/packages/detour

## Overview

This guide covers migrating from the old `_scripts/detour` location to the new structured `_dev/packages/detour` package.

## What Changed

### Old Structure
```
_playground/_scripts/detour/
├── file-detour.sh       # Monolithic script
├── detour.conf          # Config file
├── file-detour.log      # Log file
├── install.sh
└── uninstall.sh
```

### New Structure
```
_playground/_dev/packages/detour/
├── bin/
│   └── detour           # Executable wrapper
├── lib/
│   └── detour-core.sh   # Core logic (was file-detour.sh)
├── src/
│   ├── main.rs          # Future Rust TUI
│   ├── lib.rs
│   ├── config.rs
│   ├── detour.rs
│   ├── include.rs
│   └── service.rs
├── examples/
│   └── detour.conf.example
├── docs/
│   └── MIGRATION.md     # This file
├── Cargo.toml
├── README.md
├── ARCHITECTURE.md
├── install.sh
└── uninstall.sh
```

## Migration Steps

### 1. No Active Detours (Recommended)

If you **don't have active detours** yet:

```bash
# 1. Remove old installation (if installed)
~/.local/bin/detour remove  # Remove any active detours
rm ~/.local/bin/detour      # Remove old symlink

# 2. Install from new location
cd /home/pi/_playground/_dev/packages/detour
./install.sh

# 3. Verify
detour --help

# 4. Clean up old directory (optional)
# Keep for reference or delete after confirming new version works
rm -rf /home/pi/_playground/_scripts/detour
```

### 2. With Active Detours

If you **have active detours**:

```bash
# 1. Save your current config
cp ~/.detour.conf ~/.detour.conf.backup

# 2. Check current status
detour status

# 3. Remove all detours (they'll be in the config)
detour remove

# 4. Remove old installation
rm ~/.local/bin/detour

# 5. Install new version
cd /home/pi/_playground/_dev/packages/detour
./install.sh

# 6. Restore your config
cp ~/.detour.conf.backup ~/.detour.conf

# 7. Reapply detours
detour apply

# 8. Verify
detour status
```

### 3. Config File Location

**No change required** - Config remains at `~/.detour.conf`

The new version uses the same config format, so your existing detour rules will work without modification.

## Differences Between Versions

### Functionally Identical

Both versions support:
- ✅ File detours (bind mounts)
- ✅ Include directives
- ✅ Service management
- ✅ Same config format
- ✅ Same commands

### New Features (Coming Soon)

The new structure enables:
- 🚧 Rust TUI (in development)
- 🚧 Better performance
- 🚧 Enhanced validation
- 🚧 Profile management
- 🚧 Rollback functionality

## Troubleshooting

### "command not found: detour"

```bash
# Check if symlink exists
ls -l ~/.local/bin/detour

# Reinstall
cd /home/pi/_playground/_dev/packages/detour
./install.sh

# Ensure ~/.local/bin is in PATH
echo $PATH | grep .local/bin
```

### Old detours still active

```bash
# List active mounts
mount | grep detour

# Manually unmount if needed
sudo umount /path/to/mount
```

### Config file issues

```bash
# Use example as template
cp /home/pi/_playground/_dev/packages/detour/examples/detour.conf.example ~/.detour.conf

# Validate config
detour validate
```

## Rollback (If Needed)

If you need to revert to the old version:

```bash
# 1. Remove new version
rm ~/.local/bin/detour
rm -rf ~/.local/share/detour

# 2. Reinstall old version
cd /home/pi/_playground/_scripts/detour
./install.sh
```

## What to Do With Old Directory

### Option 1: Keep as Backup (Recommended)
```bash
# Rename for clarity
mv /home/pi/_playground/_scripts/detour \
   /home/pi/_playground/_scripts/detour.old
```

### Option 2: Delete After Verification
```bash
# After confirming new version works (wait a week or so)
rm -rf /home/pi/_playground/_scripts/detour
```

## Next Steps

1. ✅ Migrate to new structure
2. ✅ Test basic functionality
3. 🔄 Start using new features (as they're developed)
4. 🚧 Eventually migrate to Rust TUI

## Support

- Read: `README.md` for usage
- Read: `ARCHITECTURE.md` for technical details
- Check: `examples/` for config examples

---

**Migration Status:** Backwards Compatible  
**Breaking Changes:** None  
**Recommended Action:** Migrate at your convenience


