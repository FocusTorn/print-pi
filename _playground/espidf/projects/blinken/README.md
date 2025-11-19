# blinken

ESP-IDF project for esp32s3.

## Setup

1. Activate ESP-IDF environment:
   ```bash
   get_idf
   ```

2. Set target:
   ```bash
   cd /home/pi/_playground/espidf/projects/blinken
   idf.py set-target esp32s3
   ```

3. Build:
   ```bash
   idf.py build
   ```

4. Flash:
   ```bash
   idf.py -p /dev/ttyUSB0 flash
   ```

5. Monitor:
   ```bash
   idf.py -p /dev/ttyUSB0 monitor
   ```

## Project Structure

- `main/main.c` - Main application code
- `CMakeLists.txt` - Project build configuration
- `main/CMakeLists.txt` - Component build configuration
