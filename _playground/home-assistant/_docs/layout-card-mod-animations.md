# Layout Card + Card Mod Animations Guide

This guide shows how to combine `layout-card` (for structure) with `card-mod` (for animations) to create a smooth, animated expandable camera.

## Overview

**Layout Card** provides:
- Advanced grid layout control
- Responsive positioning
- Dynamic column/row spanning

**Card Mod** provides:
- CSS animations and transitions
- State-based styling (using Jinja2)
- Smooth expand/collapse effects

## Key Features

### 1. Smooth Transitions
```yaml
card_mod:
  style: |
    ha-card {
      transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
    }
```

### 2. State-Based Sizing
```yaml
card_mod:
  style: |
    /* Small state */
    ha-card {
      grid-column: span 4;
      grid-row: span 3;
    }
    
    /* Large state - when expanded */
    {% if is_state('input_boolean.camera_a1_expanded', 'on') %}
    ha-card {
      grid-column: 1 / -1; /* Full width */
      grid-row: span 12;
    }
    {% endif %}
```

### 3. Animations
```yaml
card_mod:
  style: |
    @keyframes expandIn {
      from {
        opacity: 0;
        transform: scale(0.9);
      }
      to {
        opacity: 1;
        transform: scale(1);
      }
    }
    
    ha-card {
      animation: expandIn 0.4s ease;
    }
```

## Example Configurations

### Simple Expandable with Animation
```yaml
- type: custom:layout-card
  layout_type: custom:grid-layout
  layout:
    grid-template-columns: repeat(12, 1fr)
    grid-template-rows: auto
  cards:
    - type: picture-entity
      entity: camera.a1_camera
      camera_view: live
      tap_action:
        action: toggle
        entity_id: input_boolean.camera_a1_expanded
      card_mod:
        style: |
          ha-card {
            transition: all 0.4s ease;
            {% if is_state('input_boolean.camera_a1_expanded', 'on') %}
            grid-column: 1 / -1;
            grid-row: span 12;
            {% else %}
            grid-column: span 4;
            grid-row: span 3;
            {% endif %}
          }
      layout:
        grid-column: span 4
        grid-row: span 3
```

### Advanced with Multiple Animations
```yaml
card_mod:
  style: |
    ha-card {
      /* Smooth transitions */
      transition: all 0.5s cubic-bezier(0.34, 1.56, 0.64, 1);
      border-radius: 12px;
      overflow: hidden;
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    }
    
    /* Collapsed */
    ha-card {
      grid-column: span 4;
      grid-row: span 3;
    }
    
    /* Expanded */
    {% if is_state('input_boolean.camera_a1_expanded', 'on') %}
    ha-card {
      grid-column: 1 / -1;
      grid-row: span 12;
      border-radius: 16px;
      box-shadow: 0 12px 32px rgba(0,0,0,0.25);
    }
    {% endif %}
    
    /* Hover effect */
    ha-card:hover {
      transform: translateY(-2px);
    }
    
    /* Active/press effect */
    ha-card:active {
      transform: scale(0.98);
    }
```

## Animation Options

### 1. Easing Functions
- `ease` - Default, smooth
- `ease-in` - Slow start
- `ease-out` - Slow end
- `ease-in-out` - Slow start and end
- `cubic-bezier(0.4, 0, 0.2, 1)` - Custom curve (Material Design)

### 2. Transition Properties
- `all` - All properties
- `transform` - Position/scale/rotate
- `opacity` - Fade in/out
- `box-shadow` - Shadow changes
- `border-radius` - Corner rounding

### 3. Keyframe Animations
```yaml
@keyframes slideIn {
  from {
    opacity: 0;
    transform: translateX(-20px);
  }
  to {
    opacity: 1;
    transform: translateX(0);
  }
}

ha-card {
  animation: slideIn 0.4s ease;
}
```

## Pros and Cons

### Pros ✅
- **Smooth animations** - Professional look and feel
- **Flexible layout** - Full control over grid positioning
- **State-aware** - Responds to entity states
- **Already installed** - Both cards are available
- **Highly customizable** - Full CSS control

### Cons ❌
- **Complex configuration** - More YAML than simple conditionals
- **CSS knowledge helpful** - Better results with CSS understanding
- **Performance** - Animations use GPU, but more complex than static
- **Debugging** - CSS issues can be harder to troubleshoot

## Tips

1. **Use `cubic-bezier` easing** for smooth, natural animations
2. **Keep transitions under 0.5s** for responsive feel
3. **Test on mobile** - Animations should work on all devices
4. **Use `will-change`** for better performance:
   ```css
   ha-card {
     will-change: transform, grid-column, grid-row;
   }
   ```
5. **Combine with hover effects** for better UX

## Full Example

See `dashboard-a1-camera-layout-card-mod.yaml` for complete working examples with:
- Simple expandable with animation
- Conditional layout approach
- Advanced dynamic grid with multiple animations

