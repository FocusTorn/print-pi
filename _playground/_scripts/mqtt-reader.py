#!/usr/bin/env python3
"""
MQTT Topic Reader
Subscribes to an MQTT topic and displays JSON messages in a readable key-value format
"""

import sys
import json
import subprocess
import datetime
from typing import Dict, Any


def format_timestamp(timestamp: float) -> str:
    """Convert Unix timestamp to human-readable datetime string."""
    try:
        dt = datetime.datetime.fromtimestamp(timestamp)
        return dt.strftime("%Y-%m-%d %H:%M:%S")
    except (ValueError, TypeError, OSError):
        return "Invalid timestamp"


def format_value(value: Any) -> str:
    """Format a value for display."""
    if value is None:
        return "null"
    elif isinstance(value, bool):
        return "true" if value else "false"
    elif isinstance(value, float):
        # Format floats with appropriate precision
        if abs(value) < 0.001:
            return f"{value:.6f}"
        elif abs(value) < 1:
            return f"{value:.3f}"
        else:
            return f"{value:.2f}"
    elif isinstance(value, int):
        return str(value)
    else:
        return str(value)


def display_readings(data: Dict[str, Any], topic: str):
    """Display readings in a two-column key-value format."""
    # Extract timestamp first if present
    timestamp = data.get('timestamp')
    readable_time = format_timestamp(timestamp) if timestamp is not None else "N/A"
    
    # Define field order: left column first, then right column
    left_column_order = [
        'temperature', 'humidity', 'pressure', 'gas_resistance',
        'smoothed_temp', 'smoothed_change_rate', 'max_rate_since_soak_start',
        'soak_started', 'rate_ok', 'ready', 'temp_ok',
    ]
    
    right_column_order = [
        'heat_stable', 'temp_smoothing_buffer', 'rate_smoothing_buffer',
        'target_temp', 'rate_change_plateau', 'rate_start_type', 'rate_start_temp',
    ]
    
    # Get all available keys
    available_keys = set(data.keys()) - {'timestamp'}
    
    # Build left column (preferred order, then any remaining)
    left_keys = []
    remaining_left = available_keys.copy()
    
    for key in left_column_order:
        if key in remaining_left:
            left_keys.append(key)
            remaining_left.remove(key)
    
    # Add empty line after gas_resistance if we have smoothed values
    if 'smoothed_temp' in left_keys:
        insert_pos = left_keys.index('smoothed_temp')
        if insert_pos > 0:
            left_keys.insert(insert_pos, '')
    
    # Add empty line before soak_started if present
    if 'soak_started' in left_keys:
        insert_pos = left_keys.index('soak_started')
        if insert_pos > 0:
            left_keys.insert(insert_pos, '')
    
    # Build right column (preferred order, then any remaining)
    right_keys = []
    remaining_right = remaining_left.copy()
    
    for key in right_column_order:
        if key in remaining_right:
            right_keys.append(key)
            remaining_right.remove(key)
    
    # Add empty line after rate_smoothing_buffer if we have target_temp
    if 'target_temp' in right_keys:
        insert_pos = right_keys.index('target_temp')
        if insert_pos > 0:
            right_keys.insert(insert_pos, '')
    
    # Add any remaining keys to right column
    if remaining_right:
        if right_keys:
            right_keys.append('')
        right_keys.extend(sorted(remaining_right))
    
    # Calculate max key lengths for each column
    left_max_key_len = 0
    for key in left_keys:
        if key and key in data:
            left_max_key_len = max(left_max_key_len, len(key))
    
    right_max_key_len = 0
    for key in right_keys:
        if key and key in data:
            right_max_key_len = max(right_max_key_len, len(key))
    
    # Calculate max value widths for each column (for right-alignment)
    left_max_value_len = 0
    for key in left_keys:
        if key and key in data:
            formatted_value = format_value(data.get(key))
            left_max_value_len = max(left_max_value_len, len(formatted_value))
    
    right_max_value_len = 0
    for key in right_keys:
        if key and key in data:
            formatted_value = format_value(data.get(key))
            right_max_value_len = max(right_max_value_len, len(formatted_value))
    
    # Calculate value start positions (key + 4 spaces)
    left_value_start = left_max_key_len + 4
    right_value_start = right_max_key_len + 4
    
    # Calculate total width: left column + separator + right column
    left_column_width = left_max_key_len + 4 + left_max_value_len
    right_column_width = right_max_key_len + 4 + right_max_value_len
    separator_width = 5  # "  ┃  "
    total_width = left_column_width + separator_width + right_column_width
    
    # Print header
    print(f"\n{'='*total_width}")
    print(f"Topic: {topic}")
    print(f"{'='*total_width}")
    print(f"{'Timestamp':<30} {readable_time}")
    print(f"{'-'*total_width}")
    
    # Print two-column layout
    max_len = max(len(left_keys), len(right_keys))
    for i in range(max_len):
        left_line = ""
        right_line = ""
        
        if i < len(left_keys):
            key = left_keys[i]
            if key == '':
                left_line = ""
            else:
                value = data.get(key)
                formatted_value = format_value(value)
                # Left-align key, 4 spaces, then right-align value to max width
                left_line = f"{key:<{left_max_key_len}}    {formatted_value:>{left_max_value_len}}"
        
        if i < len(right_keys):
            key = right_keys[i]
            if key == '':
                right_line = ""
            else:
                value = data.get(key)
                formatted_value = format_value(value)
                # Left-align key, 4 spaces, then right-align value to max width
                right_line = f"{key:<{right_max_key_len}}    {formatted_value:>{right_max_value_len}}"
        
        if left_line and right_line:
            print(f"{left_line}  ┃  {right_line}")
        elif left_line:
            print(f"{left_line}  ┃")
        elif right_line:
            # Pad left side to align with left column width
            left_padding = left_value_start + left_max_value_len
            print(f"{'':<{left_padding}}  ┃  {right_line}")
        elif not left_line and not right_line:
            print()
    
    print()


def main():
    if len(sys.argv) < 2:
        print("Usage: mqtt <topic> [host] [port]")
        print("Example: mqtt 'sensors/bme680/raw'")
        print("Example: mqtt 'sensors/bme680/raw' localhost 1883")
        sys.exit(1)
    
    topic = sys.argv[1]
    host = sys.argv[2] if len(sys.argv) > 2 else "localhost"
    port = int(sys.argv[3]) if len(sys.argv) > 3 else 1883
    
    print(f"Subscribing to: {topic} on {host}:{port}")
    print("Press Ctrl+C to stop\n")
    
    try:
        # Use mosquitto_sub to subscribe to the topic
        cmd = ["mosquitto_sub", "-h", host, "-p", str(port), "-t", topic, "-C", "1"]
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        while True:
            line = process.stdout.readline()
            if not line:
                break
            
            line = line.strip()
            if not line:
                continue
            
            try:
                data = json.loads(line)
                display_readings(data, topic)
            except json.JSONDecodeError as e:
                print(f"Error parsing JSON: {e}")
                print(f"Raw message: {line}\n")
            except KeyboardInterrupt:
                print("\n\nStopped by user")
                process.terminate()
                break
    
    except FileNotFoundError:
        print("Error: mosquitto_sub not found. Install mosquitto-clients:")
        print("  sudo apt install mosquitto-clients")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n\nStopped by user")
        sys.exit(0)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()

