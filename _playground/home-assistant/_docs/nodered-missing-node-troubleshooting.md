# Node-RED Missing Node Type Troubleshooting

## Error Message

"This node is a type unknown to your installation of Node-RED. If you deploy with the node in this state, it's configuration will be preserved, but the flow will not start until the missing type is installed."

## What This Means

A node in your flow requires a palette package (node module) that isn't installed in your Node-RED instance.

## How to Identify the Missing Node Type

### Method 1: Check Node Info in Node-RED Editor

1. **Click on the node** that shows the error
2. **Check the Info sidebar** (right side panel)
3. **Look for the node type** - it will show something like:
   - `node-red-contrib-home-assistant-websocket/events-state`
   - `node-red-contrib-mqtt-broker/mqtt-broker`
   - Or similar pattern

### Method 2: Check Node Properties

1. **Double-click the node** to open its properties
2. **Check the node type** at the top
3. **The type will indicate the palette name**

### Method 3: Check Node-RED Logs

```bash
docker logs nodered | grep -i "missing\|unknown\|error"
```

## Common Missing Node Types

### Home Assistant Nodes
- **Palette**: `node-red-contrib-home-assistant-websocket`
- **Install**: Menu → Manage palette → Install → Search for "node-red-contrib-home-assistant-websocket"

### MQTT Nodes
- **Palette**: `node-red-contrib-aedes` or `node-red-contrib-mqtt-broker`
- **Install**: Menu → Manage palette → Install → Search for MQTT broker

### Database Nodes
- **Palette**: `node-red-contrib-influxdb` or `node-red-contrib-postgresql`
- **Install**: Menu → Manage palette → Install → Search for database type

### HTTP/API Nodes
- **Palette**: Various (check node type)
- **Install**: Menu → Manage palette → Install → Search for specific type

## How to Install Missing Palette

### Step 1: Identify the Palette Name

From the node type, extract the palette name:
- Node type: `node-red-contrib-home-assistant-websocket/events-state`
- Palette name: `node-red-contrib-home-assistant-websocket`

### Step 2: Install via Node-RED UI

1. **Open Node-RED Editor**
   - Go to `http://192.168.1.159:1880`

2. **Open Palette Manager**
   - Click **Menu** (top right, hamburger icon)
   - Select **Manage palette**

3. **Install Palette**
   - Click **Install** tab
   - Search for the palette name
   - Click **Install** button
   - Wait for installation to complete

4. **Restart Node-RED** (if needed)
   ```bash
   docker restart nodered
   ```

### Step 3: Verify Installation

1. **Check node is available**
   - The node should no longer show as "unknown"
   - Node should be available in the palette (left sidebar)

2. **Deploy flow**
   - Click **Deploy** button
   - Flow should start without errors

## Install via Command Line (Alternative)

If you can't install via UI, you can install via command line:

```bash
# Enter Node-RED container
docker exec -it nodered bash

# Install palette
npm install <palette-name>

# Exit container
exit

# Restart Node-RED
docker restart nodered
```

## Troubleshooting

### Node Still Shows as Unknown After Installation

1. **Restart Node-RED:**
   ```bash
   docker restart nodered
   ```

2. **Clear browser cache:**
   - Hard refresh: `Ctrl+Shift+R` (or `Cmd+Shift+R` on Mac)

3. **Check installation:**
   ```bash
   docker exec nodered npm list <palette-name>
   ```

4. **Check Node-RED logs:**
   ```bash
   docker logs nodered | tail -50
   ```

### Palette Installation Fails

1. **Check Node-RED logs:**
   ```bash
   docker logs nodered | tail -50
   ```

2. **Check disk space:**
   ```bash
   df -h
   ```

3. **Check permissions:**
   ```bash
   ls -la /home/pi/nodered/node_modules/
   ```

4. **Try manual installation:**
   ```bash
   docker exec nodered npm install <palette-name>
   docker restart nodered
   ```

### Multiple Missing Nodes

If multiple nodes are missing:

1. **Identify all missing node types**
2. **Install all required palettes**
3. **Restart Node-RED**
4. **Deploy flow**

## Finding Node Type from Node ID

If you have a node ID but can't find it in the flow:

1. **Check if node is in a different tab:**
   - Look through all tabs in Node-RED
   - Node might be in a different flow

2. **Check if node was deleted:**
   - Node might have been removed from flow
   - But reference might still exist

3. **Check Node-RED logs:**
   ```bash
   docker logs nodered | grep -i "3a7ca8e6215a655a"
   ```

## Quick Reference

### Common Palette Names

- Home Assistant: `node-red-contrib-home-assistant-websocket`
- MQTT Broker: `node-red-contrib-aedes` or `node-red-contrib-mqtt-broker`
- InfluxDB: `node-red-contrib-influxdb`
- PostgreSQL: `node-red-contrib-postgresql`
- MongoDB: `node-red-contrib-mongodb`
- Redis: `node-red-contrib-redis`
- Slack: `node-red-contrib-slack`
- Telegram: `node-red-contrib-telegrambot`

### Installation Steps

1. Identify node type
2. Extract palette name
3. Install via Palette Manager
4. Restart Node-RED (if needed)
5. Deploy flow
6. Verify node works

## For Your Specific Case

**Node ID**: `3a7ca8e6215a655a`

**To find the node type:**
1. Open Node-RED editor
2. Navigate to the node (click the link in the error)
3. Check the Info sidebar for node type
4. Install the required palette
5. Restart Node-RED if needed

**If node is not visible:**
- Node might be in a different tab
- Node might have been deleted
- Check all tabs in Node-RED editor

---

**Next Steps:**
1. Open Node-RED editor at `http://192.168.1.159:1880`
2. Click on the node showing the error
3. Check Info sidebar for node type
4. Install required palette
5. Deploy flow

