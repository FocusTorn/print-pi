# GPIO Status Display Tool

A beautiful colorized terminal display of Raspberry Pi GPIO pin status, similar to the classic `gpio readall` command.

## Features

- **Visual Pin Layout**: Shows physical GPIO header in familiar readall format
- **Color Coding**: Uses ANSI colors for easy visual parsing
- **Multiple Pin Standards**: Shows BCM (GPIO), WiringPi, and Physical pin numbers
- **Pin States**: Displays mode (IN/OUT/ALT), pull (up/down), and voltage level (HIGH/LOW)
- **Modern Tooling**: Uses `pinctrl` instead of deprecated `raspi-gpio`

## Requirements

- Raspberry Pi with GPIO support
- `pinctrl` utility (usually installed by default on Pi OS)
- Python 3.7+
- `colored` package
- `RPi.GPIO` package (for pin conversion utilities)

## Installation

From snake-pit root:

```bash
cd /home/pi/_playground/snake-pit
uv pip install colored RPi.GPIO
```

## Usage

```bash
cd /home/pi/_playground/snake-pit
uv run python projects/gpio-status/gpio_status.py
```

## Example Output

```
                                    ┌─────────────────┐                              
                                    │      Pi 4B      │                               
┌─────┬─────┬────────────┬──────┬───┼───┬─────────┬───┼───┬──────┬────────────┬─────┬─────┐
│ BCM │ WPi │    Name    │ Mode │ P │ V │   Pin   │ V │ P │ Mode │    Name    │ WPi │ BCM │
├─────┼─────┼────────────┼──────┼───┼───┼────┬────┼───┼───┼──────┼────────────┼─────┼─────┤
│   2 │   8 │ SDA1       │ ALT0 │ ▲ │ 1 │  3 │        5v │      │ ALT0 │ SCL1       │   9 │   3 │
...
```

## Legend

- **BCM**: Broadcom GPIO pin number
- **WPi**: WiringPi pin number
- **Name**: Pin function name
- **Mode**: IN, OUT, or ALT (alternate function)
- **P**: Pull resistor - ▲ (pull-up), ▼ (pull-down), - (none)
- **V**: Voltage level - 1 (HIGH), 0 (LOW)

## Migration from Old System

This tool was migrated from `/media/pi/rootfs1/home/pi/pyfunctions/_utilities_/src/gpio_status/` 
and updated to use `pinctrl` instead of the deprecated `raspi-gpio` command.

## Original Author

Created as a replacement for `gpio readall` with enhanced colorization and readability.

