# Example Custom Card

This is a template custom card that demonstrates how to create a custom card in `_playground` that can be activated in Home Assistant like a HACS card.

## Structure

```
custom-cards/
└── example-card/
    ├── example-card.js      # The card JavaScript file
    └── README.md            # This file
```

## Activation Instructions

### Method 1: Manual Symlink (Recommended for Development)

1. Create a symlink from the HA www directory to your card:
   ```bash
   ln -s /home/pi/_playground/home-assistant/custom-cards/example-card \
         /home/pi/homeassistant/www/community/example-card
   ```

2. Restart Home Assistant or reload the frontend

3. The card will be available in the dashboard editor under "Custom Cards"

### Method 2: Using the Activation Script

Run the activation script:
```bash
/home/pi/_playground/home-assistant/custom-cards/activate-card.sh example-card
```

## Usage in Dashboard

Once activated, you can use the card in your dashboard YAML:

```yaml
type: custom:example-card
entity: sensor.example_sensor
title: My Example Card
```

Or add it via the UI:
1. Edit your dashboard
2. Click "Add Card"
3. Look for "Example Card" in the custom cards section
4. Configure the entity and title

## Development

### Making Changes

1. Edit the JavaScript file in `_playground/home-assistant/custom-cards/example-card/`
2. The changes will be immediately available (no rebuild needed)
3. Reload the frontend in Home Assistant (Settings → Developer Tools → Reload Frontend)

### Testing

1. Add the card to a test dashboard
2. Reload the dashboard to see changes
3. Check browser console for any errors

## Customization

### Adding Configuration Options

Edit the `setConfig` method to validate additional config options:

```javascript
setConfig(config) {
  if (!config.entity) {
    throw new Error('Please define an entity');
  }
  // Add more validation
  if (config.color && !/^#[0-9A-F]{6}$/i.test(config.color)) {
    throw new Error('Invalid color format');
  }
  this.config = config;
}
```

### Styling

Use CSS variables for theming:
- `--primary-text-color` - Primary text color
- `--secondary-text-color` - Secondary text color
- `--primary-color` - Primary accent color
- `--card-background-color` - Card background

### State Handling

The `hass` setter receives the Home Assistant state object. Access entities via `hass.states[entityId]`.

## Card Registration

The card is registered with Home Assistant using:

```javascript
window.customCards = window.customCards || [];
window.customCards.push({
  type: 'example-card',
  name: 'Example Card',
  description: 'A simple example custom card',
  preview: true,
  documentationURL: 'https://github.com/yourusername/example-card'
});
```

This allows Home Assistant to:
- Display the card in the card picker
- Show documentation links
- Provide card previews
- Enable card configuration in the UI

## File Structure Requirements

For a card to work properly:
1. **JavaScript file**: Must define a custom element and register it
2. **File naming**: Should match the card type (e.g., `example-card.js` for `custom:example-card`)
3. **Directory naming**: Should match the card name for clarity

## Troubleshooting

### Card not appearing in UI
- Check that the symlink exists: `ls -la ~/homeassistant/www/community/example-card`
- Verify the JavaScript file is readable
- Check browser console for JavaScript errors
- Reload the frontend in Home Assistant

### Card not working
- Check browser console for errors
- Verify the entity exists: `ha list-entities example`
- Check that the card type matches: `custom:example-card`

### Changes not appearing
- Clear browser cache
- Hard reload the page (Ctrl+Shift+R)
- Reload the frontend in Home Assistant

## Next Steps

1. Customize the card for your specific use case
2. Add more configuration options
3. Improve styling and layout
4. Add error handling
5. Add TypeScript support (optional)

