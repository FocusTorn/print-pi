# System Analysis Tools

This directory contains tools for analyzing and documenting your Raspberry Pi system.

## 🔍 Available Tools

### 1. **system-info-gatherer.sh**
Comprehensive system information collector that gathers details about your entire Pi setup.

**Usage:**
```bash
/home/pi/_playground/_scripts/system-info-gatherer.sh
```

**What it collects:**
- System identity (OS, kernel, hardware)
- CPU, memory, and GPU info
- Storage and filesystem details
- Network configuration
- Development environment
- Installed services
- Overlay/redirection system status
- 3D printing setup
- User environment
- Performance metrics
- Modified system files (quick check)

**Output:**
Formatted terminal output with options to save to file

---

### 2. **detect-modified-system-files.sh**
Specialized tool for finding system files that have been modified from their original package versions.

**Usage:**
```bash
# Full system scan
/home/pi/_playground/_scripts/detect-modified-system-files.sh

# Config files only (faster)
/home/pi/_playground/_scripts/detect-modified-system-files.sh --config-only

# Save to file
/home/pi/_playground/_scripts/detect-modified-system-files.sh -o /tmp/modified-files.txt

# Verbose output
/home/pi/_playground/_scripts/detect-modified-system-files.sh -v
```

**Options:**
- `-o, --output FILE` - Save results to file
- `-v, --verbose` - Show detailed output (package, modification time, size)
- `-c, --config-only` - Only check /etc and /boot (much faster)
- `-h, --help` - Show help

**What it does:**
- Uses `debsums` to verify MD5 checksums of installed package files
- Compares current files against original package manifests
- Categorizes modifications by directory (/etc, /boot, /usr, etc.)
- Cross-references with your system-tracker
- Provides recommendations for tracking important changes

**How it works:**
Every Debian package includes MD5 checksums for its files in `/var/lib/dpkg/info/<package>.md5sums`. This tool uses the `debsums` utility to:
1. Read the original checksums from package manifests
2. Calculate current checksums of installed files
3. Report any mismatches

---

## 📋 Workflow for System Documentation

### Step 1: Gather Full System Info
```bash
/home/pi/_playground/_scripts/system-info-gatherer.sh | tee ~/system-info-$(date +%Y%m%d).txt
```

This gives you a complete snapshot of your system state.

### Step 2: Identify Modified Files
```bash
/home/pi/_playground/_scripts/detect-modified-system-files.sh --config-only -o ~/modified-files-$(date +%Y%m%d).txt
```

This shows which config files you've customized.

### Step 3: Track Important Modifications
For any critical modifications found, add them to your system tracker:
```bash
system-track add /etc/important-config.conf
```

### Step 4: Document in Overlay System
If modifications should be part of your overlay system:
```bash
overlay add /path/to/file
```

---

## 🎯 Understanding Modified Files

### Why Files Get Modified

**Expected modifications:**
- `/etc/*` - Configuration files you've customized
- `/boot/firmware/config.txt` - Boot configuration with include directives
- `/etc/systemd/system/*` - Custom service files

**Unexpected modifications:**
- System binaries in `/usr/bin` or `/bin`
- Libraries in `/lib` or `/usr/lib`
- Package-managed files outside /etc

### What to Do with Modified Files

1. **Configuration files** (`/etc`, `/boot`):
   - Review the changes
   - If intentional: Track with `system-track`
   - If critical: Add to overlay system

2. **System binaries/libraries**:
   - Investigate why they're modified
   - May indicate:
     - Corrupted files (reinstall package)
     - Manual edits (should be avoided)
     - System updates in progress

3. **Unknown modifications**:
   - Use `dpkg -S <file>` to find which package owns it
   - Check modification date: `stat <file>`
   - Review with: `diff <(dpkg --fsys-tarfile /var/cache/apt/archives/<package>.deb | tar x ./<file> -O) <file>`

---

## 💡 Pro Tips

### Quick Config File Check
```bash
# Just show modified /etc files
/home/pi/_playground/_scripts/detect-modified-system-files.sh -c | grep "^/etc"
```

### Find Package for a File
```bash
dpkg -S /path/to/file
```

### Restore Original File
```bash
# Get the package name
PACKAGE=$(dpkg -S /path/to/file | cut -d: -f1)

# Reinstall just that file
apt-get download $PACKAGE
dpkg --fsys-tarfile ${PACKAGE}_*.deb | tar x ./path/to/file -O > /path/to/file
```

### Compare Modified File to Original
```bash
# Download package
PACKAGE=$(dpkg -S /etc/file | cut -d: -f1)
apt-get download $PACKAGE

# Extract original
dpkg --fsys-tarfile ${PACKAGE}_*.deb | tar x ./etc/file -O > /tmp/original

# Compare
diff /tmp/original /etc/file
```

---

## 🔗 Integration with Your System

These tools integrate with your existing infrastructure:

- **system-tracker**: Cross-references detected changes with tracked files
- **overlay system**: Identifies candidates for the overlay/redirection system
- **3dp-mods**: Works alongside your version-controlled customizations

---

## 📊 Using Results for system.mdc

The output from these tools provides the foundation for creating a comprehensive `system.mdc` file that documents:

1. **Hardware Specifications** - From system-info-gatherer
2. **Software Stack** - Installed packages, versions, configurations
3. **Custom Modifications** - All tracked and modified files
4. **System Architecture** - Overlay system, mod-zones, custom scripts
5. **Development Environment** - Tools, languages, frameworks
6. **Network Configuration** - Interfaces, services, access points
7. **Known Customizations** - Documented changes from package defaults

---

## 🛠️ Troubleshooting

### "debsums not found"
The script will auto-install it:
```bash
sudo apt-get update && sudo apt-get install debsums
```

### Slow Performance
Use `--config-only` flag to only check configuration files:
```bash
./detect-modified-system-files.sh -c
```

### Missing MD5 Sums
Some packages don't include checksums. This is normal for:
- Locally built packages
- Some configuration packages
- Meta-packages

### False Positives
Some files are expected to change:
- `/etc/machine-id` - Unique machine identifier
- `/etc/hostname` - System hostname
- Log files in `/var/log`

---

## 📝 Next Steps

After running these tools:

1. Review the modified files list
2. Identify which changes are intentional vs. accidental
3. Add critical configs to system-tracker
4. Document your system architecture in `system.mdc`
5. Set up regular scans to catch drift

**Create a cron job for periodic scans:**
```bash
# Add to crontab
0 0 * * 0 /home/pi/_playground/_scripts/detect-modified-system-files.sh -c -o /home/pi/weekly-scan.txt
```

This gives you weekly snapshots of system changes! 🎯

