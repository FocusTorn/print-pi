# Detour Style Guide for AI Agents

## Purpose

This document provides AI agents with a complete guide to recreating Detour's visual style, color scheme, and UI patterns. Reference this when implementing new UI components or creating similar TUI applications.

## Quick Reference

**Primary Reference**: See `RUST-TUI-FORMATTING.md` in the root directory for comprehensive styling details.

This document provides a condensed, AI Agent-focused summary with implementation patterns.

## Color Palette

### Hex Color Helper

```rust
fn hex_color(hex: u32) -> Color {
    Color::Rgb(
        ((hex >> 16) & 0xFF) as u8,
        ((hex >> 8) & 0xFF) as u8,
        (hex & 0xFF) as u8,
    )
}
```

### Core Colors

| Color | Hex | Usage |
|-------|-----|-------|
| Background | `0x0A0A0A` | Main TUI background |
| Panel BG | `0x141420` | File browser background |
| Active Selection | `0x1A2A2A` | Focused item background |
| Inactive Selection | `0x151515` | Unfocused item background |
| Dimmed Selection | `0x0D0D0D` | Selection when modal visible |
| Modal Dimmed Border | `0x222222` | Borders when modal visible |
| Modal Dimmed Text | `0x444444` | Text when modal visible |
| Inactive Border | `0x333333` | Panel borders (unfocused) |
| Inactive Text | `0x777777` | Text (unfocused) |
| Secondary Text | `0x888888` | Secondary information |
| Label Text | `0x666666` | Labels and metadata |
| Title Text | `0xBBBBBB` | Title bar text |

### Semantic Colors

- **Success**: `Color::Green`
- **Error**: `Color::Red`
- **Warning**: `Color::Yellow`
- **Info**: `Color::Cyan`
- **Accent**: `Color::Cyan`

## Universal Helpers

### Selection Style

```rust
fn get_selection_style(is_active: bool) -> Style {
    if is_active {
        Style::default()
            .bg(hex_color(0x1A2A2A))
            .fg(Color::Cyan)
    } else {
        Style::default()
            .bg(hex_color(0x151515))
            .fg(hex_color(0x777777))
    }
}
```

### Accent Colors

```rust
fn accent_color() -> Style {
    Style::default().fg(Color::Cyan)
}

fn bold_accent_color() -> Style {
    Style::default()
        .fg(Color::Cyan)
        .add_modifier(Modifier::BOLD)
}
```

### Text Color Logic

```rust
let text_color = if modal_visible {
    hex_color(0x444444)  // Dimmed when modal visible
} else if is_active {
    hex_color(0xFFFFFF)  // White when focused
} else {
    hex_color(0x777777)  // Grey when unfocused
};
```

## Border Styling

### Standard Panel Borders

```rust
let border_style = if modal_visible {
    Style::default().fg(hex_color(0x222222))
} else if is_active {
    Style::default().fg(Color::White)
} else {
    Style::default().fg(hex_color(0x333333))
};

let border_type = if is_active {
    BorderType::Thick
} else {
    BorderType::Plain
};
```

### Border Type Usage

- **Title Bar**: `BorderType::Rounded` (always)
- **Validation Report**: `BorderType::Double`
- **Modal/Popup**: `BorderType::Double`
- **File Browser**: `BorderType::Rounded` with cyan borders
- **Diff Viewer**: `BorderType::Double` with white borders
- **Content Panels**: `BorderType::Thick` (focused) or `BorderType::Plain` (unfocused)
- **Status/Logs/Config**: `BorderType::Rounded`

## Layout Structure

### Screen Division

```
┌─────────────────────────────────────────┐
│     Title Bar (3 lines)                 │
├──────────┬──────────────┬───────────────┤
│          │              │               │
│  Views   │   Actions    │   Content     │
│ (Col 1)  │   (Col 2)    │   (Col 3)     │
│          │              │               │
├──────────┴──────────────┴───────────────┤
│     Bottom Status Area (5 lines)        │
└─────────────────────────────────────────┘
```

### Area Calculations

```rust
let title_height = 3;
let status_height = 5;
let content_height = area.height.saturating_sub(title_height + status_height);

let title_area = Rect { x: 0, y: 0, width: area.width, height: 3 };
let content_area = Rect { x: 0, y: 3, width: area.width, height: content_height };
let status_area = Rect { x: 0, y: area.height - 5, width: area.width, height: 5 };
```

### Column Widths

```rust
// Column 1: Dynamic based on longest view name
let col1_width = (max_view_len + 4) as u16;

// Column 2: Dynamic based on longest action name
let col2_width = (max_action_len + 6) as u16;

// Column 3: Remaining space
let col3_width = area.width.saturating_sub(col3_x + 1);
```

## Form Input Styling

### Cursor Rendering

```rust
// Use split_at to insert cursor
let cursor = state.cursor_pos.min(display_text.len());
let (head, tail) = display_text.split_at(cursor);

// Render: head + cursor + tail
let spans = vec![
    Span::styled(head, Style::default().fg(text_fg)),
    Span::styled("█", Style::default().fg(Color::White)),  // Form fields
    Span::styled(tail, Style::default().fg(text_fg)),
];
```

### Placeholder Text

```rust
let display_text = if field.value.is_empty() {
    field.placeholder.clone()
} else {
    field.value.clone()
};

let text_fg = if is_placeholder {
    Color::DarkGray
} else {
    Color::White
};
```

### Input Popup Cursor

**Important**: Input popup uses **Yellow** cursor, not white!

```rust
Span::styled("█", Style::default().fg(Color::Yellow))  // Input popup
```

## Modal Dimming

### Key Principle

**No global overlay!** Dimming is conditional per widget using `app.is_modal_visible()`.

### Implementation Pattern

```rust
let modal_visible = app.is_modal_visible();

// Apply dimming to each widget individually
let border_color = if modal_visible {
    hex_color(0x222222)  // Dimmed
} else if is_active {
    Color::White  // Active
} else {
    hex_color(0x333333)  // Inactive
};
```

### Selection When Modal Visible

```rust
let highlight_style = if modal_visible {
    Style::default()
        .bg(hex_color(0x0D0D0D))  // Nearly invisible
        .fg(hex_color(0x444444))  // Dimmed grey
} else {
    get_selection_style(is_active)
};
```

## Popup Styling

### Popup Dimensions

#### Content-Based Width

```rust
let max_line_len = message.lines().map(|l| l.len()).max().unwrap_or(30);
let popup_width = (max_line_len as u16 + 8)
    .max(40)  // Minimum
    .min((area.width as f32 * 0.60) as u16)  // Max 60%
    .min(area.width - 4);  // Screen bounds
```

#### Dynamic Height

```rust
let wrapped_lines = wrap_text(message, max_text_width);
let popup_height = (wrapped_lines.len() as u16 + 7).min(area.height - 4);
```

### Confirm Popup Buttons

```rust
// Yes button (selected)
Style::default()
    .fg(Color::Green)
    .bg(hex_color(0x0F1F0F))  // Subtle green background

// Yes button (unselected)
Style::default().fg(hex_color(0x666666))

// No button (selected)
Style::default()
    .fg(hex_color(0xFF4444))  // Brighter red
    .bg(hex_color(0x1F0F0F))  // Subtle red background

// No button (unselected)
Style::default().fg(hex_color(0x666666))
```

## Toast Notifications

### Structure

```rust
pub struct Toast {
    pub message: String,
    pub toast_type: ToastType,
    pub shown_at: std::time::Instant,
}
```

### Styling

- **Background**: `0x0A0A0A` (match UI background)
- **Success**: Green text with `✓` icon
- **Error**: Red text with `✗` icon
- **Info**: Cyan text with `ℹ` icon
- **Modifier**: Bold text
- **Position**: Bottom-right, stacked upward
- **Auto-dismiss**: 2.5 seconds

### Implementation

```rust
// Auto-dismiss
app.toasts.retain(|toast| {
    toast.shown_at.elapsed().map(|d| d.as_secs_f32() <= 2.5).unwrap_or(false)
});

// Render (bottom-right, stacked)
for toast in app.toasts.iter().rev() {
    let (icon, fg_color) = match toast.toast_type {
        ToastType::Success => ("✓", Color::Green),
        ToastType::Error => ("✗", Color::Red),
        ToastType::Info => ("ℹ", Color::Cyan),
    };
    // ... render with padding
}
```

## List Rendering

### Multi-line Items

```rust
ListItem::new(vec![
    Line::from("Main content"),
    Line::from(Span::styled(
        "   Secondary info",
        Style::default().fg(hex_color(0x888888))
    )),
])
```

### Empty States

```rust
if items.is_empty() {
    vec![ListItem::new(" No items configured")
        .style(Style::default().fg(Color::DarkGray))]
} else {
    // ... render items
}
```

## Scrollbar Styling

### When to Show

```rust
if entries.len() > visible_height {
    // Show scrollbar
}
```

### Rendering

```rust
let scrollbar_height = list_area.height as usize;
let total_items = entries.len();
let scrollbar_position = (scroll_offset * scrollbar_height) / total_items;
let scrollbar_size = (scrollbar_height * scrollbar_height) / total_items.max(1);

for i in 0..scrollbar_height {
    let is_scrollbar = i >= scrollbar_position && i < (scrollbar_position + scrollbar_size);
    let symbol = if is_scrollbar { "█" } else { "│" };
    let color = if is_scrollbar { Color::Cyan } else { Color::DarkGray };
}
```

## Status Bar

### Title Bar

```rust
let title_text = format!(
    " Detour  |  Profile: {}  |  {} active  |  Status: {} ",
    profile, active_count, status_icon
);

Paragraph::new(title_text)
    .alignment(Alignment::Center)
    .style(Style::default()
        .fg(if modal_visible { hex_color(0x444444) } else { hex_color(0xBBBBBB) })
        .add_modifier(Modifier::BOLD))
```

### Bottom Status

```rust
// Success
Span::styled(
    format!(" ✓ {} ", msg),
    Style::default().fg(Color::Green).add_modifier(Modifier::BOLD)
)

// Error
Span::styled(
    format!(" ✗ {} ", msg),
    Style::default().fg(Color::Red).add_modifier(Modifier::BOLD)
)
```

## Minimum Size

### Requirements

- **Width**: 120 columns minimum
- **Height**: 16 rows minimum

### Handling Below Minimum

```rust
if area.width < 120 || area.height < 16 {
    draw_minimal_ui(f, app);
    return;
}
```

### Minimal UI

```rust
// Message: "Terminal too small! Minimum: 120x16" (red, bold, centered)
// Current size: "Current: {width}x{height}" (dark grey, centered)
// Quit hint: "Press 'q' to quit" (dark grey, centered)
```

## Centered Rectangle Helper

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

## Best Practices

1. **Always Clear Before Render**: Use `Clear` widget for modals/popups
2. **Consistent State Checks**: Check `modal_visible` and `is_active` first
3. **Use Helpers**: Prefer helper functions over inline styling
4. **Empty States**: Always provide helpful empty state messages
5. **Text Wrapping**: Use helper function for text wrapping in popups
6. **Scroll Management**: Update visible height on every render
7. **Color Consistency**: Use hex_color() helper for all custom colors
8. **Border Types**: Use appropriate border type for component type

## Implementation Checklist

When implementing new UI components:

- [ ] Use `get_selection_style()` for list selections
- [ ] Use `accent_color()` for titles and highlights
- [ ] Check `modal_visible` for dimming
- [ ] Use appropriate border type
- [ ] Handle empty states
- [ ] Clear area before rendering modals
- [ ] Use `centered_rect()` for centered popups
- [ ] Use content-based sizing for popups
- [ ] Implement scroll management
- [ ] Test minimum size handling
- [ ] Verify keyboard navigation
- [ ] Check cursor rendering (split_at method)
- [ ] Verify placeholder text styling
- [ ] Test modal dimming behavior

## Reference

- **Detailed Styling**: See `RUST-TUI-FORMATTING.md` in root directory
- **Implementation**: See `src/ui.rs` and `src/components/`
- **Examples**: See existing component implementations

