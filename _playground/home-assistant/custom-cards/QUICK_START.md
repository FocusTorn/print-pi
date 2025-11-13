# Quick Start Guide: Custom Cards

## Create and Activate a Custom Card in 3 Steps

### Step 1: Create Your Card

```bash
cd /home/pi/_playground/home-assistant/custom-cards

# Create card directory
mkdir -p my-card

# Copy example as template
cp example-card/example-card.js my-card/my-card.js

# Edit the card (replace 'example-card' with 'my-card')
# You can use your favorite editor
```

### Step 2: Activate Your Card

```bash
./activate-card.sh my-card
```

### Step 3: Use in Home Assistant

1. **Reload Frontend**: Settings → Developer Tools → Reload Frontend
2. **Add to Dashboard**: Edit Dashboard → Add Card → Custom Cards → My Card
3. **Or use YAML**:
   ```yaml
   type: custom:my-card
   entity: sensor.example_sensor
   title: My Custom Card
   ```

## Common Tasks

### List All Cards
```bash
./list-cards.sh
```

### Deactivate a Card
```bash
./deactivate-card.sh my-card
```

### Check Card Status
```bash
ls -la ~/homeassistant/www/community/my-card
```

## Troubleshooting

### Card Not Appearing?
1. Check activation: `./list-cards.sh`
2. Reload frontend in HA
3. Check browser console for errors

### Card Not Working?
1. Check browser console (F12)
2. Verify entity exists: `ha list-entities my_entity`
3. Check card type matches: `custom:my-card`

### Changes Not Showing?
1. Hard reload browser (Ctrl+Shift+R)
2. Reload frontend in HA
3. Clear browser cache

## Next Steps

- See `README.md` for detailed documentation
- See `example-card/README.md` for card-specific docs
- Customize your card JavaScript file
- Add more configuration options
- Improve styling and layout

## Example Card Template

The `example-card` directory contains a complete working example:
- `example-card.js` - The card implementation
- `example-dashboard.yaml` - Usage example
- `README.md` - Detailed documentation

You can use it as a starting point for your own cards!

