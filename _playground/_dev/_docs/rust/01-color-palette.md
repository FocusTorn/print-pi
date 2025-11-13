# Universal Rust TUI Color Palette

## Purpose

This document defines the universal color palette and color system for all Rust TUI applications in the workspace. This ensures visual consistency across all TUI projects.

## Hex Color Helper

All custom colors use this helper function:

```rust
fn hex_color(hex: u32) -> Color {
    Color::Rgb(
        ((hex >> 16) & 0xFF) as u8,
        ((hex >> 8) & 0xFF) as u8,
        (hex & 0xFF) as u8,
    )
}
```

**Usage:**
```rust
let color = hex_color(0x0A0A0A);  // Dark background
```

## Core Color Palette

### Background Colors

| Color | Hex Value | Usage |
|-------|-----------|-------|
| Background | `0x0A0A0A` | Main TUI background |
| Panel Background | `0x141420` | Solid panel/modal background (file browser, popups) |

### Selection Colors

| Color | Hex Value | Usage |
|-------|-----------|-------|
| Active Selection BG | `0x1A2A2A` | Highlighted item background (focused) |
| Inactive Selection BG | `0x151515` | Highlighted item background (unfocused) |
| Dimmed Selection BG | `0x0D0D0D` | Selection when modal visible (nearly invisible) |

### Border Colors

| Color | Hex Value | Usage |
|-------|-----------|-------|
| Modal Dimmed Border | `0x222222` | Borders when modal is visible |
| Inactive Border | `0x333333` | Panel borders when not focused |
| Active Border | `Color::White` | Panel borders when focused |

### Text Colors

| Color | Hex Value | Usage |
|-------|-----------|-------|
| Modal Dimmed Text | `0x444444` | Text when modal is visible |
| Inactive Text | `0x777777` | Text in unfocused panels |
| Secondary Text | `0x888888` | Secondary information text |
| Label Text | `0x666666` | Labels and metadata text |
| Title Text | `0xBBBBBB` | Title bar text (when not dimmed) |
| Active Text | `0xFFFFFF` or `Color::White` | Active panel text |
| Grey Text | `Color::Gray` | Inactive form fields |
| Placeholder | `Color::DarkGray` | Empty field placeholders |

### Accent Colors

| Color | Value | Usage |
|-------|-------|-------|
| Accent Cyan | `Color::Cyan` | Primary accent color (titles, highlights) |

## Semantic Colors

Semantic colors are used for conveying meaning:

| Color | Value | Usage |
|-------|-------|-------|
| Success | `Color::Green` | Success messages, active states, confirmations |
| Error | `Color::Red` | Error messages, failed states |
| Warning | `Color::Yellow` | Warning messages, caution states |
| Info | `Color::Cyan` | Informational messages, info states |

### Semantic Color Usage Examples

```rust
// Success
Style::default().fg(Color::Green).add_modifier(Modifier::BOLD)

// Error
Style::default().fg(Color::Red).add_modifier(Modifier::BOLD)

// Warning
Style::default().fg(Color::Yellow)

// Info
Style::default().fg(Color::Cyan)
```

## Special Purpose Colors

### Confirm Dialog Colors

| Color | Hex Value | Usage |
|-------|-----------|-------|
| Confirm Yes Selected | `Color::Green` on `0x0F1F0F` | Yes button when selected |
| Confirm No Selected | `0xFF4444` on `0x1F0F0F` | No button when selected (brighter red) |
| Confirm Unselected | `0x666666` | Button text when not selected |

### Input Cursor Colors

| Color | Value | Usage |
|-------|-------|-------|
| Form Field Cursor | `Color::White` | Cursor in form fields (█ character) |
| Input Popup Cursor | `Color::Yellow` | Cursor in input popups (█ character) |

## Color Application Patterns

### Text Color Logic

Standard pattern for determining text color based on state:

```rust
let text_color = if modal_visible {
    hex_color(0x444444)  // Dimmed when modal visible
} else if is_active {
    hex_color(0xFFFFFF)  // White when focused
} else {
    hex_color(0x777777)  // Grey when unfocused
};
```

### Border Color Logic

Standard pattern for determining border color:

```rust
let border_color = if modal_visible {
    hex_color(0x222222)  // Dimmed when modal visible
} else if is_active {
    Color::White  // White when focused
} else {
    hex_color(0x333333)  // Grey when unfocused
};
```

### Selection Background Logic

Standard pattern for selection backgrounds:

```rust
let selection_bg = if modal_visible {
    hex_color(0x0D0D0D)  // Nearly invisible when modal visible
} else if is_active {
    hex_color(0x1A2A2A)  // Cyan-tinted when focused
} else {
    hex_color(0x151515)  // Subtle grey when unfocused
};
```

## Color Consistency Rules

1. **Always use hex_color() helper**: Never hardcode RGB values directly
2. **Use semantic colors for meaning**: Success, error, warning, info
3. **Apply dimming consistently**: All UI elements dim when modal visible
4. **Maintain contrast**: Ensure text is readable against backgrounds
5. **Follow state-based logic**: Colors change based on focus and modal state

## Implementation Checklist

When implementing colors:

- [ ] Use `hex_color()` helper for all custom colors
- [ ] Use semantic colors (Green, Red, Yellow, Cyan) for meaning
- [ ] Apply text color logic based on state (modal, active, inactive)
- [ ] Apply border color logic based on state
- [ ] Apply selection background logic based on state
- [ ] Use appropriate cursor color (White for forms, Yellow for popups)
- [ ] Maintain contrast for readability
- [ ] Test dimming behavior when modals are visible

## Reference

- **Styling Helpers**: See `02-styling-helpers.md` for helper functions
- **Component Patterns**: See `04-component-patterns.md` for component usage
- **Implementation**: See Detour package for reference implementation

