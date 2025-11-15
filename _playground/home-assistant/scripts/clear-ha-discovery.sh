#!/bin/bash
# Clear old Home Assistant MQTT discovery messages

echo "Clearing old Home Assistant MQTT discovery messages..."
echo

# Clear all discovery config topics (retained messages)
mosquitto_pub -h localhost -t "homeassistant/sensor/+/+/config" -n -r 2>/dev/null && echo "✅ Cleared sensor discovery topics"
mosquitto_pub -h localhost -t "homeassistant/switch/+/+/config" -n -r 2>/dev/null && echo "✅ Cleared switch discovery topics"
mosquitto_pub -h localhost -t "homeassistant/text/+/+/config" -n -r 2>/dev/null && echo "✅ Cleared text discovery topics"
mosquitto_pub -h localhost -t "homeassistant/button/+/+/config" -n -r 2>/dev/null && echo "✅ Cleared button discovery topics"
mosquitto_pub -h localhost -t "homeassistant/select/+/+/config" -n -r 2>/dev/null && echo "✅ Cleared select discovery topics"
mosquitto_pub -h localhost -t "homeassistant/number/+/+/config" -n -r 2>/dev/null && echo "✅ Cleared number discovery topics"
mosquitto_pub -h localhost -t "homeassistant/fan/+/+/config" -n -r 2>/dev/null && echo "✅ Cleared fan discovery topics"
mosquitto_pub -h localhost -t "homeassistant/light/+/+/config" -n -r 2>/dev/null && echo "✅ Cleared light discovery topics"
mosquitto_pub -h localhost -t "homeassistant/binary_sensor/+/+/config" -n -r 2>/dev/null && echo "✅ Cleared binary_sensor discovery topics"
mosquitto_pub -h localhost -t "homeassistant/device_automation/+/+/config" -n -r 2>/dev/null && echo "✅ Cleared device_automation discovery topics"

echo
echo "✅ Old discovery messages cleared!"
echo
echo "Next steps:"
echo "1. Reload your NodeRed flow (click Deploy in NodeRed UI)"
echo "2. NodeRed will republish all discovery messages with the new default_entity_id format"
echo "3. The warnings should disappear after NodeRed republishes"


