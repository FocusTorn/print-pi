# Node-RED Debugging Guide

## How to See What Your Flow is Broadcasting

### Method 1: Debug Node (Recommended)

**Steps:**
1. Add a Debug node after your publish/broadcast node
2. Connect it to see messages
3. Open Debug panel (right sidebar)
4. Watch messages in real-time

**Debug Node Settings:**
- **Output:** Complete msg object (see everything)
- **Output:** msg.payload (see just the data)
- **Output:** msg.topic (see just the topic)
- **Output:** Selected property (see specific property)

### Method 2: Debug Panel

**Access:**
- Click "Debug" tab in right sidebar
- Or press `Ctrl+Shift+D` (or `Cmd+Shift+D` on Mac)

**Features:**
- See all messages from Debug nodes
- Filter messages
- Clear messages
- Copy messages

### Method 3: MQTT Topic Monitor

**For MQTT Flows:**
1. Add an MQTT In node
2. Subscribe to the topic you're publishing to
3. Connect to Debug node
4. See what's being published

**Or use MQTT Client:**
- Use MQTT Explorer or similar tool
- Subscribe to topics
- Monitor in real-time

### Method 4: Node-RED Logs

**View Logs:**
```bash
docker logs -f nodered
```

**Filter for specific messages:**
```bash
docker logs nodered | grep -i "mqtt\|publish\|broadcast"
```

## Common Debugging Scenarios

### Debug MQTT Publish

1. Add Debug node after MQTT Out node
2. Set Debug output to "complete msg object"
3. Deploy flow
4. Trigger flow
5. Check Debug panel for:
   - Topic being published to
   - Payload being sent
   - QoS settings
   - Retain flag

### Debug Home Assistant Service Calls

1. Add Debug node after Call Service node
2. Set Debug output to "complete msg object"
3. Deploy flow
4. Trigger flow
5. Check Debug panel for:
   - Service being called
   - Entity ID
   - Service data
   - Response from HA

### Debug Function Node Output

1. Add Debug node after Function node
2. Set Debug output to "msg.payload"
3. Deploy flow
4. Trigger flow
5. Check Debug panel for processed data

## Debug Panel Tips

1. **Filter Messages:**
   - Click filter icon in Debug panel
   - Type to filter by node name or message content

2. **Clear Messages:**
   - Click clear icon
   - Or press `Ctrl+L`

3. **Copy Messages:**
   - Right-click message
   - Copy to clipboard
   - Paste elsewhere for analysis

4. **Auto-scroll:**
   - Debug panel auto-scrolls to newest messages
   - Scroll up to see older messages

## Monitoring MQTT Topics

### Using Node-RED

1. Add MQTT In node
2. Configure broker connection
3. Set topic to `#` (all topics) or specific topic
4. Connect to Debug node
5. Deploy and monitor

### Using MQTT Explorer

1. Download MQTT Explorer
2. Connect to your MQTT broker
3. Subscribe to topics
4. Monitor in real-time

### Using Command Line

```bash
# Subscribe to all topics
mosquitto_sub -h <broker-ip> -t "#" -v

# Subscribe to specific topic
mosquitto_sub -h <broker-ip> -t "device/+/report" -v
```

## Best Practices

1. **Use Debug Nodes Liberally:**
   - Add Debug nodes after every important node
   - See data flow through your flow

2. **Use Descriptive Node Names:**
   - Name Debug nodes clearly
   - Know which node is sending which message

3. **Clear Debug Panel Regularly:**
   - Avoid clutter
   - Focus on current messages

4. **Use Multiple Debug Nodes:**
   - Debug at different points in flow
   - Compare input vs output

5. **Disable Debug Nodes When Done:**
   - Right-click Debug node
   - Select "Disable"
   - Keeps flow clean

## Troubleshooting

### No Messages in Debug Panel

1. Check Debug node is connected
2. Check flow is deployed
3. Check flow is triggered
4. Check Debug panel is open
5. Check Debug node is enabled

### Too Many Messages

1. Filter Debug panel
2. Use specific Debug nodes (not all)
3. Disable unnecessary Debug nodes
4. Clear Debug panel regularly

### Messages Not Showing Expected Data

1. Check node configuration
2. Check data format
3. Check node is receiving data
4. Add Debug node earlier in flow
5. Check for errors in flow

## Example: Debug MQTT Flow

```
[Trigger] → [Process Data] → [MQTT Out] → [Debug] → [See Messages]
```

**Steps:**
1. Add Debug node after MQTT Out
2. Set Debug output to "complete msg object"
3. Deploy flow
4. Trigger flow
5. Check Debug panel for:
   - Topic: `device/ABC123/request`
   - Payload: `{"print": {"command": "pause"}}`
   - QoS: 0
   - Retain: false

## Quick Reference

- **Debug Node:** Add after nodes to see messages
- **Debug Panel:** Right sidebar, shows all Debug messages
- **MQTT Monitor:** Subscribe to topics to see publishes
- **Node-RED Logs:** `docker logs -f nodered`
- **Filter Messages:** Click filter icon in Debug panel
- **Clear Messages:** Click clear icon or `Ctrl+L`

