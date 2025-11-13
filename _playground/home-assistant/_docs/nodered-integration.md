# Node-RED Integration with Home Assistant Dashboards

Complete guide for integrating Node-RED flows into Home Assistant dashboards for enhanced control and automation.

## Prerequisites

1. ✅ Node-RED Companion installed via HACS
2. ✅ Node-RED running (Docker container or addon)
3. ✅ Home Assistant running and accessible
4. ✅ `node-red-contrib-home-assistant-websocket` palette installed in Node-RED

## Setup Steps

### Step 1: Configure Node-RED Integration in HA

1. **Open Home Assistant**
   - Go to Settings → Devices & Services
   - Click "Add Integration"
   - Search for "Node-RED"
   - Click "Node-RED Companion"

2. **Configure Connection**
   - URL: `http://192.168.1.159:1880` (or your Node-RED URL)
   - Access Token: Create a Long-Lived Access Token in HA
     - Profile → Security → Create Token
     - Copy token and paste in Node-RED integration

3. **Verify Connection**
   - Check that Node-RED appears in Devices & Services
   - Status should show "Connected"

### Step 2: Helper Entities Setup

Helper entities are already configured in:
- `input_booleans.yaml` - Flow triggers and enable/disable switches
- `input_numbers.yaml` - Flow status, counters, and duration
- `input_texts.yaml` - Flow messages and error reporting

**Entities Created:**
- `input_boolean.nodered_flow_trigger` - Trigger flows from dashboard
- `input_boolean.nodered_flow_enabled` - Enable/disable flows
- `input_boolean.nodered_automation_active` - Automation status
- `input_number.nodered_flow_status` - Flow progress (0-100%)
- `input_number.nodered_flow_counter` - Execution counter
- `input_number.nodered_flow_duration` - Last execution duration
- `input_text.nodered_flow_message` - Status messages
- `input_text.nodered_flow_error` - Error messages
- `input_text.nodered_last_execution` - Last execution timestamp

### Step 3: Create Node-RED Flow

#### Example Flow: Watch HA Entity and Execute Logic

```json
[
  {
    "id": "ha-entity-watcher",
    "type": "api-current-state",
    "name": "Watch Flow Trigger",
    "server": "home-assistant",
    "version": 3,
    "outputs": 1,
    "entity_id": "input_boolean.nodered_flow_trigger",
    "state_type": "str",
    "halt_if": "off",
    "halt_if_type": "str",
    "halt_if_compare": "is",
    "override_topic": true,
    "state_location": "payload",
    "override_payload": "msg",
    "entity_location": "data",
    "override_data": "msg",
    "x": 200,
    "y": 100,
    "wires": [["flow-logic"]]
  },
  {
    "id": "flow-logic",
    "type": "function",
    "name": "Execute Flow Logic",
    "func": "// Your flow logic here\nconst trigger = msg.payload;\n\n// Update status\nmsg.payload = {\n    entity_id: 'input_number.nodered_flow_status',\n    state: 25\n};\n\nreturn msg;",
    "outputs": 1,
    "x": 400,
    "y": 100,
    "wires": [["update-status"]]
  },
  {
    "id": "update-status",
    "type": "api-call-service",
    "name": "Update Status",
    "server": "home-assistant",
    "version": 3,
    "domain": "input_number",
    "service": "set_value",
    "entity_id": "input_number.nodered_flow_status",
    "data": "{\"value\": {{payload.state}}}",
    "dataType": "json",
    "mergecontext": "",
    "output_type": "entity_id",
    "output_location": "payload",
    "output_location_type": "msg",
    "x": 600,
    "y": 100,
    "wires": [["update-message"]]
  },
  {
    "id": "update-message",
    "type": "api-call-service",
    "name": "Update Message",
    "server": "home-assistant",
    "version": 3,
    "domain": "input_text",
    "service": "set_value",
    "entity_id": "input_text.nodered_flow_message",
    "data": "{\"value\": \"Flow executed successfully\"}",
    "dataType": "json",
    "x": 800,
    "y": 100,
    "wires": [[]]
  }
]
```

#### Example Flow: Complete Workflow with Status Updates

**Flow Steps:**
1. Watch `input_boolean.nodered_flow_trigger` for changes
2. When triggered, set status to "Running" (25%)
3. Execute your logic
4. Update status to "Complete" (100%)
5. Update message with result
6. Reset trigger back to `off`
7. Update last execution timestamp

### Step 4: Add Dashboard Cards

#### Option A: Add to Existing Dashboard

Add to your `dashboard-a1-main.yaml`:

```yaml
  - title: Node-RED Control
    path: nodered
    icon: mdi:vector-curve
    cards: !include cards/nodered-controls.yaml
```

#### Option B: Use Dedicated Dashboard

Access the dedicated Node-RED dashboard:
- URL: `http://192.168.1.159:8123/lovelace/nodered-flows`
- Or add as a tab in your main dashboard

### Step 5: Create Node-RED Flow in UI

1. **Open Node-RED**
   - Go to `http://192.168.1.159:1880`

2. **Add Home Assistant Nodes**
   - Drag "events: state" node
   - Configure to watch `input_boolean.nodered_flow_trigger`
   - Set "If state is" to "on"

3. **Add Function Node**
   - Add your custom logic
   - Update status entities as needed

4. **Add Service Call Nodes**
   - Use "call service" nodes to update HA entities
   - Update `input_number.nodered_flow_status`
   - Update `input_text.nodered_flow_message`

5. **Deploy Flow**
   - Click "Deploy" button
   - Test by toggling `input_boolean.nodered_flow_trigger` in HA

## Usage Examples

### Example 1: Simple Flow Trigger

**In Node-RED:**
- Watch `input_boolean.nodered_flow_trigger`
- When `on`, execute logic
- Update `input_text.nodered_flow_message` with result
- Reset trigger to `off`

**In HA Dashboard:**
- Button card toggles `input_boolean.nodered_flow_trigger`
- Text sensor displays `input_text.nodered_flow_message`

### Example 2: Progress Tracking

**In Node-RED:**
- Watch trigger
- Execute multi-step process
- Update `input_number.nodered_flow_status` (0%, 25%, 50%, 75%, 100%)
- Update message at each step

**In HA Dashboard:**
- Gauge card shows `input_number.nodered_flow_status`
- History graph shows progress over time

### Example 3: Error Handling

**In Node-RED:**
- Catch errors in flow
- Update `input_text.nodered_flow_error` with error message
- Update `input_number.nodered_flow_status` to 0

**In HA Dashboard:**
- Conditional card shows error if `input_text.nodered_flow_error` is not empty
- Alert badge on error entity

### Example 4: Integration with A1 Printer

**Node-RED Flow:**
- Watch printer status
- Trigger heat soak workflow
- Update flow status as steps complete
- Send notifications

**HA Dashboard:**
- Button to trigger heat soak
- Status gauge showing progress
- Message showing current step

## Advanced Integration

### Webhook Integration

Create webhook endpoints in Node-RED:

1. **Add HTTP In Node**
   - Method: POST
   - URL: `/webhook/flow-trigger`

2. **Connect to Flow Logic**
   - Process webhook payload
   - Execute flow
   - Return response

3. **Call from HA**
   - Use RESTful Command integration
   - Or use `rest_command` in configuration.yaml

### MQTT Integration

Use MQTT for bidirectional communication:

1. **Node-RED Publishes**
   - Status updates to MQTT topics
   - Flow results to MQTT topics

2. **HA Subscribes**
   - MQTT sensors for status
   - MQTT switches for control

### Service Calls from HA

Call Node-RED logic via HA services:

1. **Create Service in Node-RED**
   - Use "call service" node
   - Expose as HA service

2. **Call from Dashboard**
   - Button card calls service
   - Script calls service
   - Automation calls service

## Troubleshooting

### Node-RED Can't Connect to HA

1. **Check Connection**
   - Verify Node-RED integration in HA
   - Check Long-Lived Access Token
   - Verify URL is correct

2. **Check Logs**
   ```bash
   docker logs nodered
   ha logs | grep -i nodered
   ```

### Entities Not Updating

1. **Check Entity Names**
   - Verify entity IDs match in Node-RED and HA
   - Check for typos in entity IDs

2. **Check Service Calls**
   - Verify service calls are correct
   - Check domain (input_number, input_text, etc.)

### Flow Not Triggering

1. **Check Trigger Entity**
   - Verify `input_boolean.nodered_flow_trigger` exists
   - Check if entity is being toggled
   - Verify Node-RED is watching correct entity

2. **Check Flow Deployment**
   - Ensure flow is deployed in Node-RED
   - Check for errors in Node-RED debug panel

## Best Practices

1. **Use Helper Entities**
   - Always use helper entities for flow control
   - Don't modify core HA entities directly

2. **Error Handling**
   - Always update error entity on failure
   - Clear error entity on success

3. **Status Updates**
   - Update status frequently during long flows
   - Provide meaningful status messages

4. **Reset Triggers**
   - Always reset trigger entities after execution
   - Prevents accidental re-triggers

5. **Testing**
   - Test flows in Node-RED debug panel
   - Verify entity updates in HA
   - Test dashboard controls

## Related Files

- `input_booleans.yaml` - Flow control switches
- `input_numbers.yaml` - Flow status and counters
- `input_texts.yaml` - Flow messages and errors
- `cards/nodered-controls.yaml` - Dashboard control cards
- `dashboard-nodered.yaml` - Dedicated Node-RED dashboard

## References

- [Node-RED Documentation](https://nodered.org/docs/)
- [Node-RED Companion](https://github.com/zachowj/hass-node-red)
- [Home Assistant Websocket](https://zachowj.github.io/node-red-contrib-home-assistant-websocket/)

---

**Last Updated:** November 2024  
**Platform:** Raspberry Pi 4 - Debian 13  
**Node-RED:** Docker container  
**Home Assistant:** Docker container

