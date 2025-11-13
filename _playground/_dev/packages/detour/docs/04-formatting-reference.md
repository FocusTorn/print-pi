# Detour Formatting Reference

## Purpose

This document serves as a quick reference for Detour-specific formatting details. For comprehensive universal formatting patterns, see `_dev/_docs/rust/`.

## Universal Patterns Reference

**Comprehensive universal formatting is documented in:**
- **Color Palette**: `_dev/_docs/rust/01-color-palette.md` - Complete color system
- **Styling Helpers**: `_dev/_docs/rust/02-styling-helpers.md` - Universal helper functions
- **Layout Patterns**: `_dev/_docs/rust/03-layout-patterns.md` - Layout structure
- **Component Patterns**: `_dev/_docs/rust/04-component-patterns.md` - Component patterns

This document focuses on **Detour-specific** formatting details and quick reference.

## Detour-Specific Quick Reference

### Detour Status Icons

- `✓` - Active detour (green)
- `○` - Inactive detour (grey)
- `❌` - Error state (red)
- `⚠️` - Warning state (yellow)

### Detour List Item Format

```
✓ /path/to/original → /path/to/custom
   📝 2h ago  |  📏 12.5 KB  |  ⚠️  Restart needed
```

### Detour View Modes

- `DetoursList` - List all detours
- `DetoursAdd` - Add new detour form
- `DetoursEdit` - Edit existing detour form
- `InjectionsList` - List all injections
- `InjectionsAdd` - Add new injection form
- `MirrorsList` - List all mirrors
- `MirrorsAdd` - Add new mirror form
- `MirrorsEdit` - Edit existing mirror form
- `ServicesList` - List all services
- `StatusOverview` - System status dashboard
- `LogsLive` - Live log viewer
- `ConfigEdit` - Config file editor

### Detour-Specific Key Bindings

**Detours List**:
- `Space` - Toggle detour active state
- `e` - Edit selected detour
- `d` - Show diff viewer
- `v` - Validate selected detour
- `Delete` - Delete selected detour (with confirmation)

**Forms**:
- `Ctrl+F` - Open file browser for path field
- `Tab` - Path completion or next field
- `Enter` - Submit form
- `Esc` - Cancel form

## Detour-Specific Color Usage

### Status Colors

- **Active**: `Color::Green` (✓)
- **Inactive**: `hex_color(0x777777)` (○)
- **Error**: `Color::Red` (❌)
- **Warning**: `Color::Yellow` (⚠️)

### File Status Colors

- **File exists**: `Color::Green` (✓)
- **File not found**: `Color::Red` (❌)
- **Restart needed**: `Color::Yellow` (⚠️)

## Detour-Specific Component Usage

### Detour List Panel

```rust
use crate::components::list_panel;

let items: Vec<list_panel::ItemRow> = app.detours.iter().map(|detour| {
    list_panel::ItemRow {
        line1: format!("{} → {}", detour.original, detour.custom),
        line2: Some(format!("   {} | {}", detour.status_text(), detour.size_display())),
        status_icon: Some(if detour.active { "✓" } else { "○" }.to_string()),
    }
}).collect();

list_panel::draw_list_panel(f, area, "Detours", &items, &mut state, is_active, modal_visible, &theme);
```

### Detour Form Panel

```rust
use crate::components::form_panel;

let fields = vec![
    form_panel::FormField {
        label: "Original Path:".to_string(),
        value: form.original_path.clone(),
        placeholder: "/path/to/original/file".to_string(),
    },
    form_panel::FormField {
        label: "Custom Path:".to_string(),
        value: form.custom_path.clone(),
        placeholder: "/path/to/custom/file".to_string(),
    },
];

form_panel::draw_form_panel(f, area, "Add Detour", &fields, &form_state, is_active, modal_visible);
```

## Reference

- **Universal Formatting**: See `_dev/_docs/rust/` for comprehensive universal patterns
- **Structure Guide**: See `01-structure-guide.md` for Detour structure
- **Style Guide**: See `02-style-guide.md` for Detour styling
- **Implementation Patterns**: See `03-implementation-patterns.md` for Detour patterns
