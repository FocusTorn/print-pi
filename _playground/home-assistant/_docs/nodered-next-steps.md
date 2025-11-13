# Node-RED Integration - Next Steps

## What's Been Set Up

✅ **Helper Entities Created:**
- `input_boolean.nodered_flow_trigger` - Trigger flows from dashboard
- `input_boolean.nodered_flow_enabled` - Enable/disable flows
- `input_boolean.nodered_automation_active` - Automation status
- `input_number.nodered_flow_status` - Flow progress (0-100%)
- `input_number.nodered_flow_counter` - Execution counter
- `input_number.nodered_flow_duration` - Last execution duration
- `input_text.nodered_flow_message` - Status messages
- `input_text.nodered_flow_error` - Error messages
- `input_text.nodered_last_execution` - Last execution timestamp

✅ **Dashboard Cards Created:**
- `cards/nodered-controls.yaml` - Control cards for Node-RED flows
- `dashboard-nodered.yaml` - Dedicated Node-RED dashboard

✅ **Documentation Created:**
- `nodered-integration.md` - Complete integration guide
- `nodered-quick-start.md` - Quick setup guide
- `nodered-example-flow.json` - Example Node-RED flow

## Immediate Next Steps

### 1. Add Helper Entities to HA Configuration

**Check if your `configuration.yaml` includes these files:**

```yaml
input_boolean: !include input_booleans.yaml
input_number: !include input_numbers.yaml
input_text: !include input_texts.yaml
```

**If not, add them manually or update your configuration.yaml to include them.**

**Then restart HA:**
```bash
ha restart
```

### 2. Configure Node-RED Integration in HA

1. Open Home Assistant → Settings → Devices & Services
2. Click "Add Integration"
3. Search for "Node-RED"
4. Select "Node-RED Companion"
5. Configure connection (should auto-detect)

### 3. Configure Node-RED to Connect to HA

1. Open Node-RED: `http://192.168.1.159:1880`
2. Install palette: `node-red-contrib-home-assistant-websocket` (if not already)
3. Create server configuration:
   - Base URL: `http://192.168.1.159:8123`
   - Access Token: Create in HA → Profile → Security → Create Token

### 4. Import and Test Example Flow

1. In Node-RED, go to Menu → Import
2. Copy contents from `_docs/nodered-example-flow.json`
3. Paste and import
4. Update server configuration node with your HA credentials
5. Deploy flow
6. Test by toggling `input_boolean.nodered_flow_trigger` in HA

### 5. Add Dashboard Cards

**Option A: Add to existing dashboard**
- Edit your dashboard YAML
- Add: `cards: !include cards/nodered-controls.yaml`

**Option B: Use dedicated dashboard**
- Access: `http://192.168.1.159:8123/lovelace/nodered-flows`
- Or add as a view in your main dashboard

## Testing the Integration

1. **Trigger Flow from Dashboard**
   - Go to dashboard
   - Click "Trigger Flow" button
   - Watch status update in real-time

2. **Verify Entities Update**
   - `input_number.nodered_flow_status` should update (0-100%)
   - `input_text.nodered_flow_message` should update
   - `input_number.nodered_flow_counter` should increment
   - `input_text.nodered_last_execution` should update

3. **Check for Errors**
   - If error occurs, check `input_text.nodered_flow_error`
   - Check Node-RED debug panel
   - Check HA logs: `ha logs | grep -i nodered`

## Customizing Your Flows

### Example: Simple Flow Trigger

**Node-RED Flow:**
1. Watch `input_boolean.nodered_flow_trigger`
2. When `on`, execute your logic
3. Update `input_text.nodered_flow_message` with result
4. Update `input_number.nodered_flow_status` to 100%
5. Reset trigger to `off`

**HA Dashboard:**
- Button card toggles `input_boolean.nodered_flow_trigger`
- Text sensor displays `input_text.nodered_flow_message`
- Gauge shows `input_number.nodered_flow_status`

### Example: Progress Tracking

**Node-RED Flow:**
1. Watch trigger
2. Execute multi-step process
3. Update `input_number.nodered_flow_status` at each step (0%, 25%, 50%, 75%, 100%)
4. Update `input_text.nodered_flow_message` at each step

**HA Dashboard:**
- Gauge card shows `input_number.nodered_flow_status`
- History graph shows progress over time
- Message card shows current step

### Example: Error Handling

**Node-RED Flow:**
1. Use "catch" node to catch errors
2. Update `input_text.nodered_flow_error` with error message
3. Update `input_number.nodered_flow_status` to 0
4. Reset trigger

**HA Dashboard:**
- Conditional card shows error if `input_text.nodered_flow_error` is not empty
- Alert badge on error entity

## Advanced Integration

### Webhook Integration

Create webhook endpoints in Node-RED:
1. Add "HTTP In" node
2. Configure endpoint (e.g., `/webhook/flow-trigger`)
3. Connect to your flow logic
4. Call from HA using RESTful Command or `rest_command`

### MQTT Integration

Use MQTT for bidirectional communication:
1. Node-RED publishes status to MQTT topics
2. HA subscribes via MQTT sensors
3. HA publishes commands to MQTT topics
4. Node-RED subscribes and processes

### Service Calls from HA

Call Node-RED logic via HA services:
1. Create service in Node-RED using "call service" node
2. Expose as HA service
3. Call from dashboard buttons, scripts, or automations

## Troubleshooting

### Entities Not Showing

1. Check `configuration.yaml` includes helper entity files
2. Verify YAML syntax is correct
3. Restart HA after adding entities
4. Check HA logs: `ha logs | grep -i error`

### Node-RED Can't Connect

1. Verify Node-RED integration in HA is configured
2. Check Long-Lived Access Token is valid
3. Verify URL is correct (`http://192.168.1.159:8123`)
4. Check Node-RED logs: `docker logs nodered`

### Flow Not Triggering

1. Verify `input_boolean.nodered_flow_trigger` exists in HA
2. Check Node-RED is watching correct entity
3. Ensure flow is deployed in Node-RED
4. Check Node-RED debug panel for errors

## Files Created

- `input_booleans.yaml` - Flow control switches
- `input_numbers.yaml` - Flow status and counters
- `input_texts.yaml` - Flow messages and errors
- `cards/nodered-controls.yaml` - Dashboard control cards
- `dashboard-nodered.yaml` - Dedicated Node-RED dashboard
- `_docs/nodered-integration.md` - Complete integration guide
- `_docs/nodered-quick-start.md` - Quick setup guide
- `_docs/nodered-example-flow.json` - Example Node-RED flow
- `_docs/nodered-next-steps.md` - This file

## Quick Reference

- **Node-RED URL**: `http://192.168.1.159:1880`
- **HA URL**: `http://192.168.1.159:8123`
- **Trigger Entity**: `input_boolean.nodered_flow_trigger`
- **Status Entity**: `input_number.nodered_flow_status`
- **Message Entity**: `input_text.nodered_flow_message`
- **Error Entity**: `input_text.nodered_flow_error`

## Documentation

- **Complete Guide**: `_docs/nodered-integration.md`
- **Quick Start**: `_docs/nodered-quick-start.md`
- **Example Flow**: `_docs/nodered-example-flow.json`

---

**Ready to go!** Follow the steps above to complete the integration and start controlling Node-RED flows from your Home Assistant dashboards.

