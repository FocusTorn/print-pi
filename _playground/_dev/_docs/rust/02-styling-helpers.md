# Universal Rust TUI Styling Helpers

## Purpose

This document defines universal styling helper functions and patterns that should be used across all Rust TUI applications for consistency.

## Hex Color Helper

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
let bg_color = hex_color(0x0A0A0A);
```

## Selection Style Helper

Universal helper for list item selection styling:

```rust
fn get_selection_style(is_active: bool) -> Style {
    if is_active {
        // Focused state - Cyan highlight
        Style::default()
            .bg(hex_color(0x1A2A2A))  // Dim cyan background
            .fg(Color::Cyan)           // Cyan text
    } else {
        // Unfocused state - Grey highlight
        Style::default()
            .bg(hex_color(0x151515))  // Very subtle grey background
            .fg(hex_color(0x777777))  // Grey text
    }
}
```

**Usage:**
```rust
let highlight_style = get_selection_style(is_active);
```

## Selection Style When Modal Visible

When a modal/overlay is visible, selections should be dimmed:

```rust
fn get_selection_style_modal() -> Style {
    Style::default()
        .bg(hex_color(0x0D0D0D))  // Nearly invisible highlight
        .fg(hex_color(0x444444))  // Dimmed grey text
}
```

**Usage:**
```rust
let highlight_style = if modal_visible {
    get_selection_style_modal()
} else {
    get_selection_style(is_active)
};
```

## Accent Color Helpers

### Basic Accent Color

```rust
fn accent_color() -> Style {
    Style::default().fg(Color::Cyan)
}
```

### Bold Accent Color

```rust
fn bold_accent_color() -> Style {
    Style::default()
        .fg(Color::Cyan)
        .add_modifier(Modifier::BOLD)
}
```

**Usage:**
```rust
// Title when focused
let title_style = if is_active {
    bold_accent_color()
} else {
    Style::default().fg(text_color)
};
```

## Text Color Logic Helper

Standard pattern for determining text color:

```rust
fn get_text_color(is_active: bool, modal_visible: bool) -> Color {
    if modal_visible {
        hex_color(0x444444)  // Dimmed when modal visible
    } else if is_active {
        hex_color(0xFFFFFF)  // White when focused
    } else {
        hex_color(0x777777)  // Grey when unfocused
    }
}
```

**Usage:**
```rust
let text_color = get_text_color(is_active, modal_visible);
```

## Border Styling Helper

Standard pattern for border styling:

```rust
fn get_border_style(is_active: bool, modal_visible: bool) -> (Style, BorderType) {
    let border_style = if modal_visible {
        Style::default().fg(hex_color(0x222222))  // Dimmed when modal active
    } else if is_active {
        Style::default().fg(Color::White)          // White when focused
    } else {
        Style::default().fg(hex_color(0x333333))  // Grey when unfocused
    };
    
    let border_type = if is_active {
        BorderType::Thick   // Thick border when focused
    } else {
        BorderType::Plain   // Plain border when unfocused
    };
    
    (border_style, border_type)
}
```

**Usage:**
```rust
let (border_style, border_type) = get_border_style(is_active, modal_visible);

let block = Block::default()
    .borders(Borders::ALL)
    .border_type(border_type)
    .border_style(border_style);
```

## Centered Rectangle Helper

Helper for centering popups and modals:

```rust
fn centered_rect(percent_x: u16, percent_y: u16, r: Rect) -> Rect {
    use ratatui::layout::{Constraint, Direction, Layout};
    
    let popup_layout = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Percentage((100 - percent_y) / 2),
            Constraint::Percentage(percent_y),
            Constraint::Percentage((100 - percent_y) / 2),
        ])
        .split(r);
    
    Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage((100 - percent_x) / 2),
            Constraint::Percentage(percent_x),
            Constraint::Percentage((100 - percent_x) / 2),
        ])
        .split(popup_layout[1])[1]
}
```

**Usage:**
```rust
// Center a popup that takes 60% width and 40% height
let popup_area = centered_rect(60, 40, area);
```

## Modal Dimming Pattern

**Key Principle**: No global overlay! Dimming is conditional per widget.

All widgets should check modal state and adjust colors accordingly:

```rust
let modal_visible = app.is_modal_visible();

// Apply dimming to each widget individually
let text_color = if modal_visible {
    hex_color(0x444444)  // Dimmed
} else if is_active {
    hex_color(0xFFFFFF)  // Active
} else {
    hex_color(0x777777)  // Inactive
};

let border_color = if modal_visible {
    hex_color(0x222222)  // Dimmed
} else if is_active {
    Color::White  // Active
} else {
    hex_color(0x333333)  // Inactive
};
```

## Title Styling Pattern

Standard pattern for panel titles:

```rust
fn get_title_style(is_active: bool, modal_visible: bool) -> Style {
    if modal_visible {
        Style::default().fg(hex_color(0x444444))  // Dimmed
    } else if is_active {
        accent_color()  // Cyan when focused
    } else {
        Style::default().fg(get_text_color(is_active, modal_visible))
    }
}

// Usage
let title_span = Span::styled(
    " Title Text ",
    get_title_style(is_active, modal_visible)
);
```

## Status Message Styling

### Success Message

```rust
fn success_style() -> Style {
    Style::default()
        .fg(Color::Green)
        .add_modifier(Modifier::BOLD)
}

// Usage
Span::styled(
    format!(" ✓ {} ", message),
    success_style()
)
```

### Error Message

```rust
fn error_style() -> Style {
    Style::default()
        .fg(Color::Red)
        .add_modifier(Modifier::BOLD)
}

// Usage
Span::styled(
    format!(" ✗ {} ", message),
    error_style()
)
```

## Best Practices

1. **Use Helper Functions**: Always use helper functions instead of inline styling
2. **Consistent State Checks**: Always check `modal_visible` and `is_active` in the same order
3. **No Global Overlay**: Apply dimming per widget, not via global overlay
4. **Reusable Helpers**: Create helpers for common patterns
5. **Semantic Colors**: Use semantic colors (Green, Red, Yellow, Cyan) for meaning

## Implementation Checklist

When implementing styling:

- [ ] Use `hex_color()` helper for all custom colors
- [ ] Use `get_selection_style()` for list selections
- [ ] Use `accent_color()` for titles and highlights
- [ ] Check `modal_visible` for dimming
- [ ] Use `get_text_color()` for text color logic
- [ ] Use `get_border_style()` for border styling
- [ ] Use `centered_rect()` for centered popups
- [ ] Apply modal dimming per widget (not global overlay)
- [ ] Use semantic colors for status messages

## Reference

- **Color Palette**: See `01-color-palette.md` for color definitions
- **Component Patterns**: See `04-component-patterns.md` for component usage
- **Layout Patterns**: See `03-layout-patterns.md` for layout structure
- **Implementation**: See Detour package for reference implementation

