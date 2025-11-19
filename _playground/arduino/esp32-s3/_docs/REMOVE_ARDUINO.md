# Removing Arduino CLI

Guide for removing Arduino CLI installation after switching to ESP-IDF.

## What Gets Removed

- Arduino CLI binary (`~/.local/bin/arduino-cli`)
- Arduino data directory (`~/.arduino15/`)
- Arduino user directory (`~/_playground/arduino/`)
- Shell aliases (optional - can keep for reference)

## Removal Steps

### Step 1: Remove Arduino CLI Binary

```bash
rm ~/.local/bin/arduino-cli
```

### Step 2: Remove Arduino Data Directory

This contains:
- Installed board packages (ESP32 core, tools, etc.)
- Configuration files
- Cache

```bash
rm -rf ~/.arduino15
```

**Size**: Can be several GB (ESP32 core is ~500MB+)

### Step 3: Remove Arduino User Directory (Optional)

If you want to remove all Arduino projects:

```bash
# Remove entire Arduino directory
rm -rf ~/_playground/arduino

# Or keep projects but remove Arduino CLI specific files
# (Keep your .ino files if you might convert them later)
```

### Step 4: Remove Shell Aliases (Optional)

Edit `~/.zshrc` and remove or comment out:

```bash
# ESP32-S3 shortcuts (Arduino CLI)
alias esp32-build='$ESP32_SCRIPTS/esp32-build.sh'
alias esp32-compile='arduino-cli compile -j $(nproc) --fqbn esp32:esp32:esp32s3'
alias esp32-upload='$ESP32_SCRIPTS/esp32-build.sh .'
alias esp32-monitor='arduino-cli monitor -p $($ESP32_SCRIPTS/esp32-detect-port.sh) --config baudrate=115200'
alias arduino-compile-fast='arduino-cli compile -j $(nproc)'
```

Keep the ESP32_SCRIPTS variable if you're keeping helper scripts.

### Step 5: Verify Removal

```bash
# Check if arduino-cli is gone
which arduino-cli
# Should return nothing

# Check if directories are gone
ls ~/.arduino15
# Should say "No such file or directory"
```

## What to Keep

You might want to keep:

- **Arduino projects** (`~/_playground/arduino/esp32-s3/Blink_ESP32S3/`) - for reference
- **Helper scripts** (`~/_playground/arduino/esp32-s3/_scripts/`) - some might be useful
- **Documentation** (`~/_playground/arduino/esp32-s3/_docs/`) - reference material

## Automated Removal Script

Create a removal script:

```bash
cat > ~/_playground/_scripts/remove-arduino-cli.sh << 'EOF'
#!/bin/bash
# Remove Arduino CLI installation

set -e

echo "🗑️  Removing Arduino CLI..."

# Remove binary
if [ -f ~/.local/bin/arduino-cli ]; then
    rm ~/.local/bin/arduino-cli
    echo "✅ Removed arduino-cli binary"
else
    echo "ℹ️  arduino-cli binary not found"
fi

# Remove data directory
if [ -d ~/.arduino15 ]; then
    SIZE=$(du -sh ~/.arduino15 | cut -f1)
    echo "⚠️  Removing ~/.arduino15 ($SIZE)"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf ~/.arduino15
        echo "✅ Removed ~/.arduino15"
    else
        echo "⏭️  Skipped"
    fi
else
    echo "ℹ️  ~/.arduino15 not found"
fi

echo ""
echo "✅ Arduino CLI removal complete!"
echo ""
echo "Note: Shell aliases in ~/.zshrc were not removed."
echo "      Edit ~/.zshrc manually if you want to remove them."
EOF

chmod +x ~/_playground/_scripts/remove-arduino-cli.sh
```

Then run:
```bash
~/_playground/_scripts/remove-arduino-cli.sh
```

## After Removal

1. **Verify ESP-IDF works**:
   ```bash
   get_idf
   idf.py --version
   ```

2. **Test a project**:
   ```bash
   cd ~/_playground/arduino/esp32-s3/esp-idf-projects/hello_world_template
   get_idf
   idf.py set-target esp32s3
   idf.py build
   ```

3. **Update documentation** - Remove Arduino references from your docs

## Reinstalling Later

If you need Arduino CLI again:

```bash
~/_playground/_scripts/bootstraps/bootstrap-arduino-cli.sh
```

---

**Note**: This only removes Arduino CLI. Your ESP-IDF installation is separate and unaffected.

