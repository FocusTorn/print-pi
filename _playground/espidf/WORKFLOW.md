# ESP-IDF Development Workflow

## 🎯 Typical Development Cycle

### 1. **Start Development Session**

```bash
# Navigate to your project
cd ~/_playground/espidf/projects/blinken

# Activate ESP-IDF environment (required each new terminal)
get_idf

# Verify environment
idf.py --version
```

### 2. **Edit Code**

- Edit files in `main/main.c` or other components
- Use VS Code/Cursor with IntelliSense (configured via `.clangd`)
- Code is in: `~/_playground/espidf/projects/<project_name>/`

### 3. **Build Project**

```bash
# Standard build
idf.py build

# Or use helper script (auto-detects port, handles everything)
~/_playground/espidf/_scripts/build.sh . --monitor
```

### 4. **Flash to Device**

```bash
# Manual flash
idf.py -p /dev/ttyUSB0 flash

# Or use helper script (auto-detects port)
~/_playground/espidf/_scripts/build.sh . --port /dev/ttyUSB0
```

### 5. **Monitor Output**

```bash
# Monitor serial output
idf.py -p /dev/ttyUSB0 monitor

# Exit monitor: Press Ctrl+]

# Or combine flash + monitor
idf.py -p /dev/ttyUSB0 flash monitor
```

### 6. **Iterate**

Repeat steps 2-5 as you develop:
1. Edit code
2. Build (`idf.py build`)
3. Flash (`idf.py -p /dev/ttyUSB0 flash`)
4. Monitor (`idf.py -p /dev/ttyUSB0 monitor`)
5. Test and repeat

---

## 🚀 Quick Workflow (Using Helper Scripts)

**One command to build, flash, and monitor:**

```bash
cd ~/_playground/espidf/projects/blinken
get_idf
~/_playground/espidf/_scripts/build.sh . --monitor
```

This script:
- ✅ Auto-detects ESP32-S3 board port
- ✅ Builds the project
- ✅ Flashes to device
- ✅ Opens serial monitor

---

## 📝 Common Tasks

### Create New Project

```bash
cd ~/_playground/espidf
get_idf
./_scripts/new-project.sh my_new_project esp32s3
cd projects/my_new_project
idf.py set-target esp32s3
idf.py build
```

### Configure Project (menuconfig)

```bash
get_idf
idf.py menuconfig
# Make changes, save, exit
idf.py build  # Rebuild with new config
```

### Clean Build

```bash
idf.py fullclean  # Remove all build artifacts
idf.py build      # Fresh build
```

### Check Connected Devices

```bash
# Auto-detect port
~/_playground/espidf/_scripts/detect-port.sh

# Or list all boards
idf.py -p /dev/ttyUSB0 flash monitor
```

### Debugging

```bash
# Monitor with specific baud rate
idf.py -p /dev/ttyUSB0 monitor -b 115200

# Erase flash if needed
idf.py -p /dev/ttyUSB0 erase-flash
```

---

## 🔄 Daily Workflow Summary

**Morning/Start of session:**
```bash
cd ~/_playground/espidf/projects/blinken
get_idf
```

**During development:**
```bash
# Edit code in VS Code/Cursor
# Then in terminal:
idf.py build                    # Build
idf.py -p /dev/ttyUSB0 flash    # Flash
idf.py -p /dev/ttyUSB0 monitor  # Monitor
```

**Or use helper script:**
```bash
~/_playground/espidf/_scripts/build.sh . --monitor
```

---

## 💡 Pro Tips

1. **Keep terminal with `get_idf` active** - Don't close it, or run `get_idf` in each new terminal
2. **Use helper scripts** - They auto-detect ports and handle common tasks
3. **Monitor while developing** - Use `flash monitor` to see output immediately
4. **Incremental builds** - `idf.py build` only rebuilds changed files (fast!)
5. **Clean when needed** - Use `fullclean` if you get weird build errors

---

## 🛠️ Helper Scripts Available

Located in `~/_playground/espidf/_scripts/`:

- **`new-project.sh`** - Create new ESP-IDF project
- **`build.sh`** - Build, flash, and optionally monitor
- **`detect-port.sh`** - Auto-detect ESP32 board port

---

## 📚 Project Structure

```
espidf/
├── projects/
│   └── blinken/          # Your project
│       ├── main/
│       │   └── main.c    # Your code here
│       ├── CMakeLists.txt
│       ├── build/        # Generated build files
│       └── sdkconfig     # Project config
├── _scripts/             # Helper scripts
└── _docs/                # Documentation
```

---

**Remember:** Always run `get_idf` in each new terminal session before using `idf.py` commands!

