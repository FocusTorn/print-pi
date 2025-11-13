# MQTT Topic Structure

## Topic Naming Convention

```
sensor-hub/{node-id}/{component}/{sensor-type}/{sensor-id}/{data-type}
```

### Topic Components

- **`sensor-hub`** - Base topic prefix
- **`{node-id}`** - Unique identifier for each sensor node (e.g., "kitchen", "bedroom", "garage")
- **`{component}`** - Component type: "mux" (multiplexer), "sensor", or "system"
- **`{sensor-type}`** - Sensor model/type (e.g., "bme280", "sht31", "tmp102")
- **`{sensor-id}`** - Unique identifier for the sensor (e.g., "0", "1", "temperature-sensor")
- **`{data-type}`** - Type of data: "data", "temperature", "humidity", "pressure", "status", etc.

## Topic Examples

### Sensor Data Topics

```
# Complete sensor data (JSON)
sensor-hub/kitchen-node/sensor/bme280/0/data

# Individual measurements
sensor-hub/kitchen-node/sensor/bme280/0/temperature
sensor-hub/kitchen-node/sensor/bme280/0/humidity
sensor-hub/kitchen-node/sensor/bme280/0/pressure

# Multiple sensors on same mux
sensor-hub/kitchen-node/sensor/bme280/1/temperature
sensor-hub/kitchen-node/sensor/sht31/0/temperature
```

### System Status Topics

```
# Node status (online/offline, uptime, etc.)
sensor-hub/kitchen-node/system/status

# Node information (firmware version, hardware info)
sensor-hub/kitchen-node/system/info

# Error messages
sensor-hub/kitchen-node/system/error

# Heartbeat (keepalive)
sensor-hub/kitchen-node/system/heartbeat
```

### Multiplexer Status Topics

```
# Mux channel status
sensor-hub/kitchen-node/mux/0/status
sensor-hub/kitchen-node/mux/1/status

# Mux errors
sensor-hub/kitchen-node/mux/0/error
```

### Command Topics (Raspberry Pi → Sensor Node)

```
# Request sensor reading
sensor-hub/kitchen-node/command/read

# Configure sensor
sensor-hub/kitchen-node/command/config

# Reboot node
sensor-hub/kitchen-node/command/reboot

# Update firmware (OTA)
sensor-hub/kitchen-node/command/update
```

## Message Format

### Sensor Data (JSON)

```json
{
  "node_id": "kitchen-node",
  "mux_channel": 0,
  "sensor_type": "bme280",
  "sensor_id": "0",
  "timestamp": 1699123456,
  "temperature": 22.5,
  "humidity": 45.2,
  "pressure": 1013.25,
  "unit": {
    "temperature": "celsius",
    "humidity": "percent",
    "pressure": "hPa"
  }
}
```

### System Status (JSON)

```json
{
  "node_id": "kitchen-node",
  "status": "online",
  "uptime": 3600,
  "wifi_rssi": -45,
  "free_heap": 123456,
  "firmware_version": "1.0.0",
  "timestamp": 1699123456
}
```

### Error Message (JSON)

```json
{
  "node_id": "kitchen-node",
  "error_code": "I2C_ERROR",
  "error_message": "Failed to read from sensor on mux channel 0",
  "timestamp": 1699123456
}
```

### Command (JSON)

```json
{
  "command": "read",
  "mux_channel": 0,
  "sensor_id": "0",
  "timestamp": 1699123456
}
```

## QoS Levels

- **QoS 0** - At most once delivery (for frequent sensor data)
- **QoS 1** - At least once delivery (for status messages)
- **QoS 2** - Exactly once delivery (for critical commands)

## Retain Flags

- **Retain = false** - Sensor data, status updates
- **Retain = true** - System info, last known status

## Topic Wildcards

### Subscribe to All Nodes

```
sensor-hub/+/system/status
```

### Subscribe to All Sensors

```
sensor-hub/+/sensor/+/+/data
```

### Subscribe to Specific Sensor Type

```
sensor-hub/+/sensor/bme280/+/data
```

### Subscribe to All Topics from a Node

```
sensor-hub/kitchen-node/#
```

## Topic Structure Diagram

```
sensor-hub/
├── {node-id}/
│   ├── system/
│   │   ├── status
│   │   ├── info
│   │   ├── error
│   │   └── heartbeat
│   ├── mux/
│   │   └── {mux-id}/
│   │       ├── status
│   │       └── error
│   ├── sensor/
│   │   └── {sensor-type}/
│   │       └── {sensor-id}/
│   │           ├── data
│   │           ├── temperature
│   │           ├── humidity
│   │           ├── pressure
│   │           └── status
│   └── command/
│       ├── read
│       ├── config
│       ├── reboot
│       └── update
```

## MQTT Broker Configuration

### Authentication

Use username/password authentication for security:

```bash
# Create user
mosquitto_passwd -c /etc/mosquitto/passwd sensor-hub-user

# Set permissions in mosquitto.conf
user sensor-hub-user
password_file /etc/mosquitto/passwd
```

### ACL (Access Control List)

Limit topic access:

```
# Sensor nodes can publish to their own topics
user sensor-hub-user
topic write sensor-hub/+/system/+
topic write sensor-hub/+/sensor/+
topic read sensor-hub/+/command/+

# Raspberry Pi can read all topics
user pi-user
topic read sensor-hub/#
topic write sensor-hub/+/command/+
```

## Example Subscriptions (Raspberry Pi)

### Python (paho-mqtt)

```python
import paho.mqtt.client as mqtt

def on_connect(client, userdata, flags, rc):
    # Subscribe to all sensor data
    client.subscribe("sensor-hub/+/sensor/+/+/data")
    # Subscribe to system status
    client.subscribe("sensor-hub/+/system/status")
    # Subscribe to errors
    client.subscribe("sensor-hub/+/system/error")

def on_message(client, userdata, msg):
    topic = msg.topic
    payload = msg.payload.decode()
    print(f"Received: {topic} -> {payload}")

client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message
client.connect("localhost", 1883, 60)
client.loop_forever()
```

## Best Practices

1. **Use descriptive node IDs** - "kitchen-node" not "node1"
2. **Include timestamps** - Always include Unix timestamp in messages
3. **Use JSON format** - Structured data is easier to parse
4. **Set appropriate QoS** - Use QoS 0 for frequent data, QoS 1 for important status
5. **Implement heartbeat** - Regular status updates to detect offline nodes
6. **Error handling** - Publish errors to error topics for monitoring
7. **Topic versioning** - Consider versioning for future compatibility (e.g., "sensor-hub/v1/...")

