# Picture Elements Card - Custom Components Documentation

## Overview

The `picture-elements` card in your configuration uses several **custom components** that are **not part of Home Assistant Core**. These require separate documentation and installation.

## Core Home Assistant Components

### ✅ `picture-elements` Card
- **Documentation**: [Home Assistant Dev Docs - Picture Elements](https://www.home-assistant.io/dashboards/picture-elements/)
- **Status**: Core HA component
- **Purpose**: Base card type that allows overlaying elements on an image

### ✅ Standard Elements
These are part of `picture-elements` core:
- `type: state-icon` - Display entity icon
- `type: state-label` - Display entity state text
- `type: state-badge` - Display entity state badge
- `type: conditional` - Conditional element display
- `type: image` - Display image element

## Custom Components (Not in HA Core)

### 1. `custom:config-template-card`

**Purpose**: Allows using Home Assistant templates in picture-elements card elements.

**Documentation**: 
- GitHub: https://github.com/custom-cards/config-template-card
- HACS: Available in HACS as "Config Template Card"

**Usage in Your Card**:
```yaml
- type: custom:config-template-card
  entities:
    - sensor.a1_a1_wifi_signal
  element:
    type: state-icon
    entity: sensor.a1_a1_wifi_signal
    icon: mdi:ethernet-cable
  style:
    left: 76%
    top: 27.7%
```

**Why Needed**: 
- Picture-elements doesn't support templates in element properties by default
- This card enables dynamic icon/color changes based on entity states
- Allows conditional styling based on sensor values

### 2. `custom:hui-element`

**Purpose**: Allows embedding other card types as elements within picture-elements.

**Documentation**:
- GitHub: https://github.com/custom-cards/hui-element
- HACS: Available in HACS as "HUI Element"

**Usage in Your Card**:
```yaml
- type: custom:hui-element
  card_type: picture-entity
  show_name: false
  show_state: false
  entity: image.a1_a1_print_preview
  style:
    top: 61.5%
    left: 47%
```

**Why Needed**:
- Allows nesting other card types (like `picture-entity`) inside picture-elements
- Enables complex card compositions
- Provides access to card features not available in standard picture-elements elements

### 3. `card_mod` / `lovelace-card-mod`

**Purpose**: Allows custom CSS styling of Lovelace cards using Jinja2 templates.

**Documentation**:
- GitHub: https://github.com/thomasloven/lovelace-card-mod
- HACS: Available in HACS as "Card Mod"
- Documentation: https://github.com/thomasloven/lovelace-card-mod#readme

**Usage in Your Card**:
```yaml
card_mod:
  style: |
    ha-card {
      background: none !important;
      border: none !important;
    }
    {% if is_state('light.a1_a1_chamber_light', 'on') %}
    ha-card::before {
      background-image: url('/local/media/bambuprinter/a1_lighton.png');
    }
    {% else %}
    ha-card::before {
      background-image: url('/local/media/bambuprinter/a1_lightoff.png');
    }
    {% endif %}
```

**Why Needed**:
- `picture-elements` doesn't support `state_image` like `picture-entity` does
- Allows dynamic background images based on entity states
- Provides full CSS control with Jinja2 template support
- Enables custom styling that's not possible with standard card options

**Template Syntax**:
- Uses **Jinja2 templates**, not JavaScript
- Correct: `{% if is_state('light.a1_a1_chamber_light', 'on') %}`
- Wrong: `${states["light.a1_a1_chamber_light"].state === "on"}`

## Installation Status

Based on your system, these custom components are installed:
- ✅ `config-template-card` - `/home/pi/homeassistant/www/community/config-template-card/`
- ✅ `hui-element` - `/home/pi/homeassistant/www/community/lovelace-hui-element/`
- ✅ `card-mod` - `/home/pi/homeassistant/www/community/lovelace-card-mod/`

## Best Practices

### 1. Template Syntax
- ✅ Use **Jinja2** syntax for card-mod templates: `{% if is_state(...) %}`
- ❌ Don't use JavaScript template literals: `${states[...]}`
- ✅ Use Home Assistant template functions: `is_state()`, `states()`, `state_attr()`

### 2. Image Paths
- ✅ Use `/local/` prefix for images in `www/` directory
- ✅ Absolute paths: `/local/media/bambuprinter/a1_lighton.png`
- ❌ Don't use relative paths: `media/bambuprinter/a1_lighton.png`
- ❌ Don't use `/www/` prefix: `/www/media/...`

### 3. Card Structure
- ✅ Keep `image` property at root level (required for picture-elements)
- ✅ Use `card_mod` for dynamic styling
- ✅ Use `custom:config-template-card` for template-based elements
- ✅ Use `custom:hui-element` for nested cards

### 4. Performance
- ✅ Minimize template complexity
- ✅ Cache template results when possible
- ✅ Use conditional elements to hide unused elements
- ✅ Limit number of custom cards per dashboard

## Common Issues

### Issue 1: Images Not Loading

**Symptoms**: Images don't display in picture-elements card

**Causes**:
1. Wrong image path format
2. Images not in `www/` directory
3. Card-mod template syntax error
4. Browser cache issues

**Solutions**:
1. Verify image path: `/local/media/bambuprinter/a1_lighton.png`
2. Check image exists: `ls /home/pi/homeassistant/www/media/bambuprinter/`
3. Test image URL: `http://192.168.1.159:8123/local/media/bambuprinter/a1_lighton.png`
4. Use Jinja2 syntax in card-mod: `{% if is_state(...) %}`
5. Clear browser cache

### Issue 2: Template Not Evaluating

**Symptoms**: Templates don't update when entity state changes

**Causes**:
1. Wrong template syntax (JavaScript instead of Jinja2)
2. Entity not in `entities:` list
3. Template cache not refreshing

**Solutions**:
1. Use Jinja2 syntax: `{% if is_state('entity.id', 'state') %}`
2. Add entity to `entities:` list in config-template-card
3. Refresh dashboard or restart Home Assistant

### Issue 3: Card-Mod Not Applying

**Symptoms**: Card-mod styles don't apply

**Causes**:
1. Card-mod not installed
2. Template syntax error
3. CSS selector incorrect

**Solutions**:
1. Verify card-mod installed: Check `/home/pi/homeassistant/www/community/lovelace-card-mod/`
2. Check browser console for errors
3. Verify CSS selector: `ha-card`, `ha-card::before`, etc.
4. Test template syntax separately

## Documentation Links

### Core Home Assistant
- [Picture Elements Card](https://www.home-assistant.io/dashboards/picture-elements/)
- [Templating](https://www.home-assistant.io/docs/configuration/templating/)
- [Jinja2 Templates](https://www.home-assistant.io/docs/configuration/templating/#jinja2-templates)

### Custom Components
- [Config Template Card](https://github.com/custom-cards/config-template-card)
- [HUI Element](https://github.com/custom-cards/hui-element)
- [Card Mod](https://github.com/thomasloven/lovelace-card-mod)

### Installation
- [HACS](https://hacs.xyz/) - Home Assistant Community Store
- [Manual Installation](https://github.com/thomasloven/hass-config/wiki/Lovelace-Plugins) - Manual card installation

## Summary

**Components Not in HA Core:**
1. `custom:config-template-card` - Template support in elements
2. `custom:hui-element` - Nested card support
3. `card_mod` - Custom CSS styling with templates

**All components are installed and available in your system.**

**Key Points:**
- Use Jinja2 templates, not JavaScript
- Use `/local/` prefix for images
- Keep `image` property at root level
- Use card-mod for dynamic background images
- Follow HA Dev Docs for core components
- Refer to custom component docs for custom features

---

**Next Steps:**
1. Fix card-mod template syntax (use Jinja2)
2. Verify image paths are correct
3. Test card with both light states
4. Check browser console for errors

