# Home Assistant Custom Cards

This directory contains custom cards for Home Assistant that are developed in `_playground` and can be activated like HACS cards.

## Directory Structure

```
custom-cards/
├── README.md                 # This file
├── activate-card.sh          # Script to activate a card
├── deactivate-card.sh        # Script to deactivate a card
├── list-cards.sh             # Script to list all cards and their status
└── example-card/             # Example card template
    ├── example-card.js       # Card JavaScript file
    └── README.md             # Card-specific documentation
```

## Quick Start

### 1. Create a New Card

1. Create a new directory for your card:
   ```bash
   mkdir -p /home/pi/_playground/home-assistant/custom-cards/my-card
   ```

2. Create the JavaScript file (must match card name):
   ```bash
   touch /home/pi/_playground/home-assistant/custom-cards/my-card/my-card.js
   ```

3. Use the example card as a template:
   ```bash
   cp custom-cards/example-card/example-card.js custom-cards/my-card/my-card.js
   ```

### 2. Activate the Card

Run the activation script:
```bash
cd /home/pi/_playground/home-assistant/custom-cards
./activate-card.sh my-card
```

### 3. Use the Card in Home Assistant

1. Reload the frontend in Home Assistant:
   - Settings → Developer Tools → Reload Frontend
   - Or restart Home Assistant: `ha restart`

2. Add the card to your dashboard:
   - Edit dashboard → Add Card → Look for "My Card" in custom cards
   - Or use YAML: `type: custom:my-card`

## Card Development

### Card Structure

A custom card must:

1. **Define a custom element** that extends `HTMLElement`
2. **Implement `setConfig(config)`** to handle configuration
3. **Implement `set hass(hass)`** to receive Home Assistant state updates
4. **Register the card** with `window.customCards`

### Example Card Template

```javascript
class MyCard extends HTMLElement {
  setConfig(config) {
    if (!config.entity) {
      throw new Error('Please define an entity');
    }
    this.config = config;
  }

  set hass(hass) {
    if (!this.content) {
      this._renderCard();
    }
    
    const entityId = this.config.entity;
    const state = hass.states[entityId];
    // Update card content based on state
  }

  _renderCard() {
    const card = document.createElement('ha-card');
    card.header = this.config.title || 'My Card';
    this.content = document.createElement('div');
    this.content.style.padding = '16px';
    card.appendChild(this.content);
    this.appendChild(card);
  }

  getCardSize() {
    return 1;
  }
}

customElements.define('my-card', MyCard);

// Register with Home Assistant
window.customCards = window.customCards || [];
window.customCards.push({
  type: 'my-card',
  name: 'My Card',
  description: 'A custom card for my use case',
  preview: true,
  documentationURL: 'https://github.com/yourusername/my-card'
});
```

### Card Registration

The `window.customCards` array allows Home Assistant to:
- Display the card in the card picker UI
- Show documentation links
- Provide card previews
- Enable card configuration in the UI

Required fields:
- `type`: The card type (matches custom element name)
- `name`: Display name in the UI
- `description`: Short description

Optional fields:
- `preview`: Show preview in card picker (default: false)
- `documentationURL`: Link to documentation

## Activation System

### How It Works

1. **Source**: Cards are stored in `_playground/home-assistant/custom-cards/`
2. **Target**: Cards are symlinked to `~/homeassistant/www/community/`
3. **Loading**: Home Assistant loads cards from `www/community/` directory
4. **Activation**: The activation script creates the symlink

### Activation Scripts

#### `activate-card.sh`

Activates a card by creating a symlink:
```bash
./activate-card.sh <card-name>
```

#### `deactivate-card.sh`

Deactivates a card by removing the symlink:
```bash
./deactivate-card.sh <card-name>
```

#### `list-cards.sh`

Lists all cards and their activation status:
```bash
./list-cards.sh
```

## Card Configuration

### Configuration Options

Cards can accept configuration via the `setConfig` method:

```javascript
setConfig(config) {
  // Required fields
  if (!config.entity) {
    throw new Error('Please define an entity');
  }
  
  // Optional fields with defaults
  this.config = {
    entity: config.entity,
    title: config.title || 'My Card',
    color: config.color || '#000000',
    ...config
  };
}
```

### Using in Dashboard

#### YAML Mode

```yaml
type: custom:my-card
entity: sensor.example_sensor
title: My Example Card
color: '#FF0000'
```

#### UI Mode

1. Edit dashboard
2. Add Card → Custom Cards → My Card
3. Configure entity, title, and other options
4. Save

## Development Workflow

### 1. Create Card

```bash
mkdir -p custom-cards/my-card
# Create my-card.js file
```

### 2. Activate Card

```bash
./activate-card.sh my-card
```

### 3. Develop and Test

1. Edit the JavaScript file
2. Reload frontend in Home Assistant
3. Test in dashboard
4. Check browser console for errors

### 4. Iterate

- Make changes to JavaScript
- Reload frontend
- Test changes
- Repeat

## Best Practices

### File Naming

- Card directory: `my-card/`
- JavaScript file: `my-card.js` (should match card name)
- Custom element: `my-card` (should match file name)

### Error Handling

Always validate configuration:

```javascript
setConfig(config) {
  if (!config.entity) {
    throw new Error('Please define an entity');
  }
  // Validate entity exists
  // Validate other config options
  this.config = config;
}
```

### Styling

Use Home Assistant CSS variables:

```javascript
const style = `
  .card-content {
    color: var(--primary-text-color);
    background: var(--card-background-color);
    padding: 16px;
  }
`;
```

### State Updates

Handle state updates efficiently:

```javascript
set hass(hass) {
  const entityId = this.config.entity;
  const state = hass.states[entityId];
  
  if (!state) {
    // Handle unavailable state
    return;
  }
  
  // Update only if state changed
  if (this._lastState !== state.state) {
    this._lastState = state.state;
    this._updateCard(state);
  }
}
```

## Troubleshooting

### Card Not Appearing in UI

1. **Check activation**:
   ```bash
   ./list-cards.sh
   ```

2. **Check symlink**:
   ```bash
   ls -la ~/homeassistant/www/community/my-card
   ```

3. **Check JavaScript file**:
   ```bash
   ls -la ~/homeassistant/www/community/my-card/my-card.js
   ```

4. **Reload frontend** in Home Assistant

5. **Check browser console** for JavaScript errors

### Card Not Working

1. **Check browser console** for errors
2. **Verify entity exists**: `ha list-entities my_entity`
3. **Check card type**: Must match `custom:my-card`
4. **Validate configuration**: Check `setConfig` errors

### Changes Not Appearing

1. **Clear browser cache**
2. **Hard reload** page (Ctrl+Shift+R)
3. **Reload frontend** in Home Assistant
4. **Check file permissions**: Card files should be readable

## Integration with Detour System

Cards in `_playground` are tracked in git and can be:
- Version controlled
- Shared across systems
- Backed up with `_playground`

The activation system creates symlinks to make cards available to Home Assistant without copying files.

## Examples

See the `example-card/` directory for a complete example card implementation.

## Resources

- [Home Assistant Custom Cards Documentation](https://developers.home-assistant.io/docs/frontend/custom-ui/custom-card/)
- [Lit Element Documentation](https://lit.dev/docs/)
- [Home Assistant Frontend Development](https://developers.home-assistant.io/docs/frontend/)

