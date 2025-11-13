# Node-RED Integration Quick Start

Quick setup guide for integrating Node-RED flows into Home Assistant dashboards.

## Step 1: Verify Node-RED Companion is Installed ✅

You've already completed this step!

## Step 2: Add Helper Entities to HA Configuration

The helper entities are already created in:
- `input_booleans.yaml`
- `input_numbers.yaml`
- `input_texts.yaml`

**Make sure these are included in your `configuration.yaml`:**

```yaml
input_boolean: !include input_booleans.yaml
input_number: !include input_numbers.yaml
input_text: !include input_texts.yaml
```

**Or add them directly:**

```yaml
input_boolean:
  nodered_flow_trigger:
    name: Node-RED Flow Trigger
    icon: mdi:play-circle
    initial: false
  nodered_flow_enabled:
    name: Node-RED Flow Enabled
    icon: mdi:toggle-switch
    initial: true
  nodered_automation_active:
    name: Node-RED Automation Active
    icon: mdi:robot
    initial: false

input_number:
  nodered_flow_status:
    name: Node-RED Flow Status
    icon: mdi:percent
    min: 0
    max: 100
    step: 1
    unit_of_measurement: "%"
    initial: 0
  nodered_flow_counter:
    name: Node-RED Flow Executions
    icon: mdi:counter
    min: 0
    max: 999999
    step: 1
    initial: 0
  nodered_flow_duration:
    name: Node-RED Flow Duration
    icon: mdi:timer
    min: 0
    max: 3600
    step: 1
    unit_of_measurement: "s"
    initial: 0

input_text:
  nodered_flow_message:
    name: Node-RED Flow Message
    icon: mdi:message-text
    initial: "Ready"
    max: 255
  nodered_flow_error:
    name: Node-RED Flow Error
    icon: mdi:alert-circle
    initial: ""
    max: 255
  nodered_last_execution:
    name: Node-RED Last Execution
    icon: mdi:clock-time-four
    initial: "Never"
    max: 50
```

## Step 3: Restart Home Assistant

After adding the helper entities, restart HA:

```bash
ha restart
```

Or via the UI: Settings → System → Restart

## Step 4: Configure Node-RED Integration in HA

1. **Open Home Assistant**
   - Go to Settings → Devices & Services
   - Click "Add Integration" (bottom right)
   - Search for "Node-RED"
   - Select "Node-RED Companion"

2. **Configure Connection**
   - **Name**: Node-RED (or leave default)
   - Click "Submit"

3. **Verify Connection**
   - Node-RED should appear in Devices & Services
   - Status should show "Connected"
   - If not connected, check Node-RED is running

## Step 5: Configure Node-RED to Connect to HA

1. **Open Node-RED**
   - Go to `http://192.168.1.159:1880`
   - Or `http://MyP.local:1880`

2. **Install Home Assistant Palette** (if not already installed)
   - Menu → Manage palette → Install
   - Search: `node-red-contrib-home-assistant-websocket`
   - Click "Install"

3. **Configure Home Assistant Server**
   - Drag a "events: state" node onto the canvas
   - Double-click to configure
   - Click "Add new home-assistant-server"
   - Configure:
     - **Name**: Home Assistant
     - **Base URL**: `http://192.168.1.159:8123`
     - **Access Token**: Create in HA → Profile → Security → Create Token
     - Click "Add" then "Done"

4. **Test Connection**
   - Add a "debug" node
   - Connect to "events: state" node
   - Deploy flow
   - Toggle an entity in HA
   - Check Node-RED debug panel for messages

## Step 6: Create Example Flow

1. **Import Example Flow**
   - In Node-RED, go to Menu → Import
   - Copy contents of `_docs/nodered-example-flow.json`
   - Paste and click "Import"
   - Update the server configuration node with your HA credentials

2. **Deploy Flow**
   - Click "Deploy" button
   - Flow should be active

3. **Test Flow**
   - In HA, go to Developer Tools → States
   - Find `input_boolean.nodered_flow_trigger`
   - Toggle it to `on`
   - Watch the flow execute in Node-RED
   - Check HA entities update:
     - `input_number.nodered_flow_status` should update
     - `input_text.nodered_flow_message` should update
     - `input_number.nodered_flow_counter` should increment

## Step 7: Add Dashboard Cards

### Option A: Add to Existing Dashboard

Edit your dashboard YAML and add:

```yaml
  - title: Node-RED Control
    path: nodered
    icon: mdi:vector-curve
    cards: !include cards/nodered-controls.yaml
```

### Option B: Use Dedicated Dashboard

Access the dedicated Node-RED dashboard:
- URL: `http://192.168.1.159:8123/lovelace/nodered-flows`
- Or add as a view in your main dashboard

## Step 8: Test Integration

1. **Trigger Flow from Dashboard**
   - Go to your dashboard
   - Click "Trigger Flow" button
   - Watch status update in real-time

2. **Monitor Flow Status**
   - Check gauge shows progress
   - Check message updates
   - Check counter increments

3. **Check for Errors**
   - If error occurs, check error message
   - Check Node-RED debug panel
   - Check HA logs: `ha logs | grep -i nodered`

## Troubleshooting

### Entities Not Showing in HA

1. **Check Configuration**
   - Verify entities are in `configuration.yaml`
   - Check YAML syntax is correct
   - Restart HA after adding entities

2. **Check Entity Names**
   - Verify entity IDs match in Node-RED and HA
   - Check for typos

### Node-RED Can't Connect to HA

1. **Check Connection**
   - Verify Node-RED integration in HA is configured
   - Check Long-Lived Access Token is valid
   - Verify URL is correct

2. **Check Logs**
   ```bash
   docker logs nodered
   ha logs | grep -i nodered
   ```

### Flow Not Triggering

1. **Check Trigger Entity**
   - Verify `input_boolean.nodered_flow_trigger` exists
   - Check if entity is being toggled
   - Verify Node-RED is watching correct entity

2. **Check Flow Deployment**
   - Ensure flow is deployed in Node-RED
   - Check for errors in Node-RED debug panel

## Next Steps

1. **Customize Flows**
   - Modify example flow for your needs
   - Add your custom logic
   - Create multiple flows for different tasks

2. **Add More Controls**
   - Create additional helper entities
   - Add more dashboard cards
   - Integrate with other HA entities

3. **Advanced Integration**
   - Use webhooks for external triggers
   - Integrate with MQTT
   - Create complex automation workflows

## Related Files

- `input_booleans.yaml` - Flow control switches
- `input_numbers.yaml` - Flow status and counters
- `input_texts.yaml` - Flow messages and errors
- `cards/nodered-controls.yaml` - Dashboard control cards
- `dashboard-nodered.yaml` - Dedicated Node-RED dashboard
- `_docs/nodered-example-flow.json` - Example Node-RED flow
- `_docs/nodered-integration.md` - Complete integration guide

---

**Quick Reference:**
- Node-RED: `http://192.168.1.159:1880`
- Home Assistant: `http://192.168.1.159:8123`
- Trigger Entity: `input_boolean.nodered_flow_trigger`
- Status Entity: `input_number.nodered_flow_status`

