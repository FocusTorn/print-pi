# Detour Style Guide for AI Agents

## Purpose

This document provides Detour-specific styling details and extensions. For universal styling patterns, see `_dev/_docs/rust/02-styling-helpers.md` and `_dev/_docs/rust/01-color-palette.md`.

## Universal Patterns Reference

**Universal styling patterns are documented in:**
- **Color Palette**: `_dev/_docs/rust/01-color-palette.md`
- **Styling Helpers**: `_dev/_docs/rust/02-styling-helpers.md`
- **Component Patterns**: `_dev/_docs/rust/04-component-patterns.md`

This guide focuses on **Detour-specific** styling details and extensions.

## Detour-Specific Styling

### Detour Status Icons

```rust
// Active detour
"✓"  // Checkmark (green when active)

// Inactive detour
"○"  // Empty circle (grey when inactive)

// Error state
"❌"  // Red X

// Warning state
"⚠️"  // Warning symbol
```

### Detour List Item Display

**Format**:
```
✓ /path/to/original → /path/to/custom
   📝 2h ago  |  📏 12.5 KB  |  ⚠️  Restart needed
```

**Styling**:
- Line 1: Main path (white when active, grey when inactive)
- Line 2: Metadata (secondary text color `0x888888`)
- Status icon: Color-coded (green for active, grey for inactive)

### Detour Form Styling

**Fields**:
- Original Path: Path input with file browser
- Custom Path: Path input with file browser
- Options: Checkboxes for backup, restart, profile

**Special Styling**:
- File existence indicator: `✓ File exists` (green) or `❌ File not found` (red)
- Path validation: Real-time validation with visual feedback
- Preview section: Shows what operation will do

### Status Overview Styling

**Layout**:
```
┌─ System Status ───────┬─ Detours ─────────┬─ Health ──────────────────┐
│ Overall: ✓ Healthy    │ Active: 3         │ ✓ All detours mounted     │
│ Last check: 1m ago    │ Inactive: 1       │ ✓ No permission issues    │
│                       │ Errors: 1         │ ⚠️  2 services need restart│
│ Profile: default      │ Total: 4          │ ✓ All files synced        │
```

**Color Coding**:
- Overall status: Green (✓) / Yellow (⚠️) / Red (❌)
- Detour counts: White for numbers, grey for labels
- Health indicators: Green (✓) / Yellow (⚠️) / Red (❌)

### Logs Live View Styling

**Color Coding by Level**:
```rust
let level_color = match log.level.as_str() {
    "ERROR" => Color::Red,
    "WARN" => Color::Yellow,
    "SUCCESS" => Color::Green,
    _ => hex_color(0x888888),  // INFO and others
};
```

**Format**:
```
[timestamp] [LEVEL] message
```

**Styling**:
- Timestamp: `0x666666` (grey)
- Level: Color-coded by level
- Message: White

### Config Edit View Styling

**Features**:
- Line numbers: `0x444444` (grey), right-aligned
- Content: White text
- Syntax highlighting: YAML-aware (future enhancement)

**Format**:
```
   1 │ # Detour Configuration
   2 │
   3 │ detour /path/to/original = /path/to/custom
```

## Detour-Specific Extensions

### Diff Viewer (Detour-Specific)

**Purpose**: Compare original and custom files side-by-side

**Styling**:
- Border: `BorderType::Double` with white borders
- Background: `0x0A0A0A`
- Line numbers: `0x444444` (grey)
- Content: White text
- Split: Two panels side-by-side

### Validation Report (Detour-Specific)

**Purpose**: Display validation results for detours

**Styling**:
- Border: `BorderType::Double`
- Background: Dimmed when visible
- Content: White text
- Issues: Red for errors, yellow for warnings
- Success: Green for "All valid"

## Detour-Specific Color Usage

### Status Colors

```rust
// Detour active
Color::Green  // ✓ Active

// Detour inactive
hex_color(0x777777)  // ○ Inactive

// Error state
Color::Red  // ❌ Error

// Warning state
Color::Yellow  // ⚠️ Warning
```

### File Status Colors

```rust
// File exists
Color::Green  // ✓ File exists

// File not found
Color::Red  // ❌ File not found

// File needs restart
Color::Yellow  // ⚠️ Restart needed
```

## Detour-Specific Component Extensions

### Detour List Item Component

Extends universal `list_panel` with Detour-specific data:

```rust
let items: Vec<ItemRow> = app.detours.iter().map(|detour| {
    list_panel::ItemRow {
        line1: format!("{} → {}", detour.original, detour.custom),
        line2: Some(format!(
            "   {} | {} | {}",
            detour.status_text(),
            detour.size_display(),
            detour.modified_ago()
        )),
        status_icon: Some(if detour.active { "✓" } else { "○" }.to_string()),
    }
}).collect();
```

### Detour Form Component

Extends universal `form_panel` with Detour-specific fields:

```rust
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
```

## Best Practices

1. **Use Universal Helpers**: Use universal styling helpers from `_dev/_docs/rust/`
2. **Extend for Detour**: Add Detour-specific styling on top of universal patterns
3. **Consistent Icons**: Use standard status icons (✓, ○, ❌, ⚠️)
4. **Color Coding**: Use semantic colors for status (Green/Red/Yellow)
5. **Metadata Display**: Use secondary text color for metadata

## Reference

- **Universal Styling**: See `_dev/_docs/rust/02-styling-helpers.md`
- **Universal Colors**: See `_dev/_docs/rust/01-color-palette.md`
- **Universal Components**: See `_dev/_docs/rust/04-component-patterns.md`
- **Formatting Reference**: See `04-formatting-reference.md` (references universal docs)
