
# Symlink: /usr/local/bin/gpio_status

# ip: Sets the GPIO pin as an input. This means the pin will be used to read data from external devices or sensors.
# op: Sets the GPIO pin as an output. This means the pin will be used to send data or control external devices (like LEDs).
# a0-a5: Sets the GPIO pin to one of its alternate functions. GPIO pins on the Raspberry Pi often have multiple functions (like SPI, I2C, UART, PWM). a0 through a5 correspond to these alternate functions. The specific function for each a value varies depending on the GPIO pin and the Raspberry Pi model. You would consult the Raspberry Pi's GPIO documentation to determine which alternate function corresponds to which a value for a specific pin.
# pu: Enables the internal pull-up resistor for the GPIO pin. This weakly pulls the pin's voltage HIGH when it's not actively driven by the Raspberry Pi. Useful for buttons or switches.
# pd: Enables the internal pull-down resistor for the GPIO pin. This weakly pulls the pin's voltage LOW when it's not actively driven by the Raspberry Pi.
# pn: Disables any internal pull-up or pull-down resistors on the GPIO pin. This is usually what you want when you're actively driving the pin HIGH or LOW as an output (e.g., for controlling LEDs).
# dh: If the GPIO pin is configured as an output (op), this option sets the pin to a HIGH logic level (1).
# dl: If the GPIO pin is configured as an output (op), this option sets the pin to a LOW logic level (0).

try:
    from colored import fore, back, style
except ImportError:
    print("ERROR: colored package not installed. Install with: uv pip install colored")
    import sys
    sys.exit(1)

import sys, os, time
import subprocess

MODES=["IN", "OUT", "ALT5", "ALT4", "ALT0", "ALT1", "ALT2", "ALT3"]
HEADER = ('3.3v', '5v', 2, '5v', 3, 'GND', 4, 14, 'GND', 15, 17, 18, 27, 'GND', 22, 23, '3.3v', 24, 10, 'GND', 9, 25, 11, 8, 'GND', 7, 0, 1, 5, 'GND', 6, 12, 13, 'GND', 19, 16, 26, 20, 'GND', 21)
            

FUNCTION = {
'Pull': ('High', 'High', 'High', 'High', 'High', 'High', 'High', 'High', 'High', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low'),
'ALT0': ('SDA0', 'SCL0', 'SDA1', 'SCL1', 'GPCLK0', 'GPCLK1', 'GPCLK2', 'SPI0_CE1_N', 'SPI0_CE0_N', 'SPI0_MISO', 'SPI0_MOSI', 'SPI0_SCLK', 'PWM0', 'PWM1', 'TXD0', 'RXD0', 'FL0', 'FL1', 'PCM_CLK', 'PCM_FS', 'PCM_DIN', 'PCM_DOUT', 'SD0_CLK', 'SD0_XMD', 'SD0_DATO', 'SD0_DAT1', 'SD0_DAT2', 'SD0_DAT3'),
'ALT1': ('SA5', 'SA4', 'SA3', 'SA2', 'SA1', 'SAO', 'SOE_N', 'SWE_N', 'SDO', 'SD1', 'SD2', 'SD3', 'SD4', 'SD5', 'SD6', 'SD7', 'SD8', 'SD9', 'SD10', 'SD11', 'SD12', 'SD13', 'SD14', 'SD15', 'SD16', 'SD17', 'TE0', 'TE1'),
'ALT2': ('PCLK', 'DE', 'LCD_VSYNC', 'LCD_HSYNC', 'DPI_D0', 'DPI_D1', 'DPI_D2', 'DPI_D3', 'DPI_D4', 'DPI_D5', 'DPI_D6', 'DPI_D7', 'DPI_D8', 'DPI_D9', 'DPI_D10', 'DPI_D11', 'DPI_D12', 'DPI_D13', 'DPI_D14', 'DPI_D15', 'DPI_D16', 'DPI_D17', 'DPI_D18', 'DPI_D19', 'DPI_D20', 'DPI_D21', 'DPI_D22', 'DPI_D23'),
'ALT3': ('SPI3_CE0_N', 'SPI3_MISO', 'SPI3_MOSI', 'SPI3_SCLK', 'SPI4_CE0_N', 'SPI4_MISO', 'SPI4_MOSI', 'SPI4_SCLK', '_', '_', '_', '_', 'SPI5_CE0_N', 'SPI5_MISO', 'SPI5_MOSI', 'SPI5_SCLK', 'CTS0', 'RTS0', 'SPI6_CE0_N', 'SPI6_MISO', 'SPI6_MOSI', 'SPI6_SCLK', 'SD1_CLK', 'SD1_CMD', 'SD1_DAT0', 'SD1_DAT1', 'SD1_DAT2', 'SD1_DAT3'),
'ALT4': ('TXD2', 'RXD2', 'CTS2', 'RTS2', 'TXD3', 'RXD3', 'CTS3', 'RTS3', 'TXD4', 'RXD4', 'CTS4', 'RTS4', 'TXD5', 'RXD5', 'CTS5', 'RTS5', 'SPI1_CE2_N', 'SPI1_CE1_N', 'SPI1_CE0_N', 'SPI1_MISO', 'SPIl_MOSI', 'SPI1_SCLK', 'ARM_TRST', 'ARM_RTCK', 'ARM_TDO', 'ARM_TCK', 'ARM_TDI', 'ARM_TMS'),
'ALT5': ('SDA6', 'SCL6', 'SDA3', 'SCL3', 'SDA3', 'SCL3', 'SDA4', 'SCL4', 'SDA4', 'SCL4', 'SDA5', 'SCL5', 'SDA5', 'SCL5', 'TXD1', 'RXD1', 'CTS1', 'RTS1', 'PWM0', 'PWM1', 'GPCLK0', 'GPCLK1', 'SDA6', 'SCL6', 'SPI3_CE1_N', 'SPI4_CE1_N', 'SPI5_CE1_N', 'SPI6_CE1_N')
}

PiModel = {
0: 'A',
1: 'B',
2: 'A+',
3: 'B+',
4: '2B',
6: 'CM1',
8: '3B',
9: 'Zero',
0xa: 'CM3',
0xc: 'ZeroW',
0xd: '3B+',
0xe: '3A+',
0x10: 'CM3+',
0x11: '4B',
0x12: 'Zero2W',
0x13: '400',
0x14: 'CM4'
}


RESET = '\033[0;0m'

RED   = '\x1B[1m\x1B[38;5;9m'
BROWN   = '\x1B[1m\x1B[38;5;130m'

GREEN = '\x1B[38;5;46m'
BRED = '\x1B[38;5;196m'
ORANGE = '\033[1;33m'
CYAN = '\x1B[38;5;51m'
YELLOW = '\x1B[38;5;227m'
PURPLE = '\x1B[38;5;201m'
BLUE = '\033[1;34m'



COL = {
    '3.3v': RED,
    '5v': RED,
    'GND': BROWN
}

wpiPin = {
    'Pin: WiringPi': '', 
    3: 8,
    5: 9,
    12: 1
}

TYPE = 0
rev = 0

#--- pin_converter ---------------------------------------------------------------------------------->> 
def pin_converter(pin_number, input_type="physical", output_type="wiringpi"):
    """
    Converts between physical pin numbers, GPIO numbers, and wiringPi pin numbers.
    Args:
            pin_number: The pin number to convert.
            input_type: The type of the input pin number ("physical", "gpio", or "wiringpi").
                        Defaults to "physical".
            output_type: The type of the output pin number ("physical", "gpio", or "wiringpi").
                        Defaults to "wiringpi".
    Returns:
            The converted pin number, or None if the conversion is not possible or if invalid
            input is provided.
    """
    import RPi.GPIO as GPIO

    # Pin Mapping --------------------------------------------->>

    pin_map = {
        #Physical: [GPIO, wiringPi]
        3: [2, 8],
        5: [3, 9],
        7: [4, 7],
        8: [14, 15],
        10: [15, 16],
        11: [17, 0],
        12: [18, 1],
        13: [27, 2],
        15: [22, 3],
        16: [23, 4],
        18: [24, 5],
        19: [10, 12],
        21: [9, 13],
        22: [25, 6],
        23: [11, 14],
        24: [8, 10],
        26: [7, 11],
        27: [0, 0],
        28: [1, 1],
        29: [5, 21],
        31: [6, 22],
        32: [12, 26],
        33: [13, 23],
        35: [19, 24],
        36: [16, 27],
        37: [26, 25],
        38: [20, 28],
        40: [21, 29],
    }

       #----------------------------------------------------------<<
    # Validation ---------------------------------------------->>

    if input_type.lower() not in ["physical", "gpio", "wiringpi"] or \
        output_type.lower() not in ["physical", "gpio", "wiringpi"]:
        print("Invalid input or output type.  Must be 'physical', 'gpio', or 'wiringpi'.")
        return None

    try:
            pin_number = int(pin_number) # ensure pin_number is an integer
    except ValueError:
            print("Invalid pin number. Must be an integer.")
            return None

    #----------------------------------------------------------<<

    if pin_number not in pin_map and input_type.lower() == "physical":
        return None

    if input_type.lower() == "physical":
        gpio_pin = pin_map[pin_number][0]
        wiringpi_pin = pin_map[pin_number][1]

    elif input_type.lower() == "gpio":
        try:
            physical_pin = next(key for key, value in pin_map.items() if value[0] == pin_number)
            wiringpi_pin = pin_map[physical_pin][1]
            if output_type.lower() == "gpio": return pin_number
        except StopIteration:
            print("GPIO pin not found in mapping")
            return None

    elif input_type.lower() == "wiringpi":
        try:
            physical_pin = next(key for key, value in pin_map.items() if value[1] == pin_number)
            gpio_pin = pin_map[physical_pin][0]
            if output_type.lower() == "wiringpi": return pin_number
        except StopIteration:
            print("WiringPi pin not found in mapping")
            return None

    if output_type.lower() == "physical":     return physical_pin if input_type.lower() != "physical" else pin_number
    elif output_type.lower() == "gpio":       return gpio_pin if input_type.lower() != "gpio" else pin_number
    elif output_type.lower() == "wiringpi":   return wiringpi_pin if input_type.lower() != "wiringpi" else pin_number

#----------------------------------------------------------------------------------------------------<<

# ['GPIO', '2:', 'level=1', 'fsel=4', 'alt=0', 'func=SDA1', 'pull=UP']

def pin_state(g):
    # Use pinctrl (replacement for deprecated raspi-gpio)
    # Output format: " 2: a0    pu | hi // GPIO2 = SDA1"
    result = subprocess.run(['pinctrl', 'get', str(g)], stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout.decode('utf-8')
    
    if not result.strip():
        return 'ERR', 'ERR', '-', '-'
    
    # Parse output: " 2: a0    pu | hi // GPIO2 = SDA1"
    parts = result.split()
    if len(parts) < 4:
        return 'ERR', 'ERR', '-', '-'
    
    D = {}
    
    # Extract mode: ip, op, or a0-a5
    mode_str = parts[1]
    if mode_str == 'ip':
        gpiomode = 0
        mode = 'IN'
    elif mode_str == 'op':
        gpiomode = 1
        mode = 'OUT'
    elif mode_str.startswith('a'):
        # ALT function: a0, a1, etc.
        alt_num = mode_str[1]
        mode = f'ALT{alt_num}'
        gpiomode = 9
        D['alt'] = int(alt_num)
    
    # Extract pull: pu, pd, pn, or --
    pull_str = parts[2]
    if pull_str == 'pu':
        D['pull'] = 'UP'
    elif pull_str == 'pd':
        D['pull'] = 'DOWN'
    else:
        D['pull'] = 'NONE'
    
    # Extract level: hi, lo
    level_str = parts[4]
    if level_str == 'hi':
        D['level'] = 1
    else:
        D['level'] = 0
    
    # Extract function name from comment: "// GPIO2 = SDA1"
    if '//' in result:
        comment_part = result.split('//')[1].strip()
        if '=' in comment_part:
            func_name = comment_part.split('=')[1].strip()
            D['func'] = func_name
        else:
            D['func'] = comment_part
    
    # Determine display name
    if gpiomode < 2:  # IN or OUT
        name = f'GPIO{g}'
    else:
        # ALT mode - use function name if available, otherwise lookup
        if 'func' in D:
            name = D['func']
        elif gpiomode == 9 and 'alt' in D:
            mode_type = f"ALT{D['alt']}"
            if mode_type in FUNCTION:
                name = FUNCTION[mode_type][g]
            else:
                name = f'GPIO{g}'
        else:
            name = f'GPIO{g}'
    
    # Format pull indicator
    if D.get('pull') == 'UP':
        color = f"{fore(196)}"
        if g == 0 or g == 1:
            pull = "▲"
        else:
            pull = f"{color}▲{style('reset')}"
    elif D.get('pull') == 'DOWN':
        color = f"{fore(130)}"
        if g == 0 or g == 1:
            pull = "▼"
        else:
            pull = f"{color}▼{style('reset')}"
    else:
        pull = "-"
    
    # Format level indicator
    if D.get('level') == 1:
        color = f"{style(1)}{fore(196)}"
        if g == 0 or g == 1:
            level = 1
        else:
            level = f"{color}1{style(0)}"
    elif D.get('level') == 0:
        color = f"{style(1)}{fore(130)}"
        if g == 0 or g == 1:
            level = 0
        else:
            level = f"{color}0{style(0)}"
    else:
        level = '-'
    
    return name, mode, pull, level

def format_name(name, alignment, width=10):
    name_color = ""

    if name.startswith("GPIO"):
        name_color = GREEN

    # Dynamic alignment using f-string formatting codes
    if alignment == "left":
        formatted_name = f"{name:<{width}}"
    elif alignment == "right":
        formatted_name = f"{name:>{width}}"
    else:
        formatted_name = name  # No alignment if alignment is invalid

    return f"{name_color}{formatted_name}{RESET}" if name_color else formatted_name

def print_gpio(pin_state):
    global TYPE, rev
    GPIOPINS = 40 if rev >= 16 else 26  # Set GPIOPINS based on revision in one line
    vModel = f"Pi{' ' if len(PiModel[TYPE]) % 2 == 0 else '  '}{PiModel.get(TYPE, '??')}"

    #--- Header block ------------------------------------------------------------------------------->>

    print( '                                    ┌─────────────────┐                              ')
    print(f'                                    │    {vModel:^9}    │                               ')
    print( '┌─────┬─────┬────────────┬──────┬───┼───┬─────────┬───┼───┬──────┬────────────┬─────┬─────┐')
    print( '│ BCM │ WPi │    Name    │ Mode │ P │ V │   Pin   │ V │ P │ Mode │    Name    │ WPi │ BCM │')
    print( '├─────┼─────┼────────────┼──────┼───┼───┼────┬────┼───┼───┼──────┼────────────┼─────┼─────┤')

    #------------------------------------------------------------------------------------------------<<

    for h in range(1, GPIOPINS, 2):
        # --- Odd Pin ------------------
        bcm = HEADER[h - 1]
        name, mode, pull, level = pin_state(bcm) if isinstance(bcm, int) else ('', '', '', '')
        
        WPi = pin_converter(h, input_type="physical", output_type="wiringpi")
        
        if (bcm == 0):
            col = f'{style(2)}{style(9)}'
            b = f'{style(0)}│{col}'
            print(f"│{col} {bcm:3} {b} {WPi:3} {b} {name:<10} {b} {mode:<{4}} {b} {pull} {b} {level} {b} {h:2} {style(0)}│", end='')
        elif isinstance(bcm, int):
            colored_name = format_name(name, 'left', 10)
            print(f'│{bcm:4} │{WPi:4} │ {colored_name} │ {mode:<{4}} │ {pull} │ {level} │ {h:2} │', end='')
        else:
            color = COL.get(bcm, '')
            print(f'│{color}▓▓▓▓▓▓▓▓▓▓▓▓ {bcm:<4} ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓{f"▓ {h}" if h>9 else f"▓▓ {h}"} {RESET}│', end='')

        # --- Even Pin ------------------
        bcm = HEADER[h]
        name, mode, pull, level = pin_state(bcm) if isinstance(bcm, int) else ('', '', '', '')
        WPi = pin_converter(h+1 , input_type="physical", output_type="wiringpi")
        
        if (bcm == 1):
            col = f'{style(2)}{style(9)}'
            b = f'{style(0)}│{col}'
            print(f'{col}{h+1:3} {b} {level} {b} {pull} {b} {mode:<{4}} {b} {name:>10} {b} {WPi:3} {b} {bcm:3} {style(0)}│')
        elif isinstance(bcm, int):
            colored_name = format_name(name, 'right', 10)
            print(f' {h+1:<3}│ {level} │ {pull} │ {mode:<{4}} │ {colored_name} │{WPi:4} │{bcm:4} │')
        else:
            color = COL.get(bcm, '')
            print(f"{color} {f'{h+1} ▓' if h+1>9 else f'{h+1} ▓▓'}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ {bcm:<3} ▓▓▓▓▓▓▓▓▓▓▓▓{RESET}│")

    #--- Footer block ------------------------------------------------------------------------------->>

    print('├─────┼─────┼────────────┼──────┼───┼───┼────┴────┼───┼───┼──────┼────────────┼─────┼─────┤')
    print('│ BCM │ WPi │    Name    │ Mode │ P │ V │   Pin   │ V │ P │ Mode │    Name    │ WPi │ BCM │')
    print('└─────┴─────┴────────────┴──────┴───┴───┴─────────┴───┴───┴──────┴────────────┴─────┴─────┘')

    #------------------------------------------------------------------------------------------------<<

def get_hardware_revision():
    with open('/proc/cpuinfo', 'r') as f:
        for line in f.readlines():
            if 'Revision' in line:
                REV = line.split(':')[1]
                REV = REV.strip()   # Revision as string
                return int(REV, base=16)

def main():
    global TYPE, rev
    rev = get_hardware_revision()

    if(rev & 0x800000):   # New Style
        TYPE = (rev&0x00000FF0)>>4
    else:   # Old Style
        rev &= 0x1F
        MM = [0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 3, 6, 2, 3, 6, 2]
        TYPE = MM[rev] # Map Old Style revision to TYPE

    print_gpio(pin_state)

if __name__ == '__main__':
	main()


