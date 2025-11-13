# Installing State Switch Card (Manual HACS Method)

The `state-switch` card may not appear in HACS search directly. Here's how to install it manually:

## Method 1: Add as Custom Repository in HACS

1. **Open HACS** in Home Assistant
2. **Click the three dots (⋮)** in the top-right corner
3. **Select "Custom repositories"**
4. **Add Repository**:
   - **Repository**: `https://github.com/thomasloven/lovelace-state-switch`
   - **Category**: Select **Lovelace**
   - Click **Add**

5. **Install the Card**:
   - Go to **HACS** → **Frontend** → **Lovelace Cards**
   - You should now see **"State Switch"** in the list
   - Click on it → **Download**

6. **Add to Lovelace Resources**:
   - Go to **Settings** → **Dashboards** → **Resources** (or **More Options** → **Resources**)
   - Click **Add Resource**
   - **URL**: `/hacsfiles/lovelace-state-switch/state-switch.js`
   - **Resource type**: `JavaScript Module`
   - Click **Create**

7. **Restart Home Assistant**

## Method 2: Manual Installation (If HACS doesn't work)

If HACS installation doesn't work, you can install manually:

```bash
cd /home/pi/homeassistant/www/community
git clone https://github.com/thomasloven/lovelace-state-switch.git state-switch
```

Then add to Lovelace resources:
- **URL**: `/local/community/state-switch/state-switch.js`
- **Resource type**: `JavaScript Module`

## Verification

After installation, you should be able to use:
```yaml
type: custom:state-switch
```

If you see an error about the card not being found, check:
1. The resource is added correctly
2. Home Assistant was restarted
3. The file exists: `/home/pi/homeassistant/www/community/state-switch/state-switch.js`

