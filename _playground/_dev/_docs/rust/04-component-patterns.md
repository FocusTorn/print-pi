# Universal Rust TUI Component Patterns

## Purpose

This document defines universal reusable component patterns for Rust TUI applications. These patterns ensure consistency and reusability across all TUI projects.

## List Panel Component

### Purpose

Generic list panel component for displaying lists with selection, scrolling, and modal dimming support.

### Data Structures

```rust
pub struct ItemRow {
    pub line1: String,
    pub line2: Option<String>,
    pub status_icon: Option<String>,
}

pub struct ListPanelTheme {
    pub secondary_text: Color,
}

impl Default for ListPanelTheme {
    fn default() -> Self {
        Self { 
            secondary_text: hex_color(0x888888) 
        }
    }
}
```

### Component Signature

```rust
pub fn draw_list_panel(
    f: &mut Frame,
    area: Rect,
    title: &str,
    items: &[ItemRow],
    state: &mut ListState,
    is_active: bool,
    modal_visible: bool,
    theme: &ListPanelTheme,
)
```

### Implementation Pattern

```rust
pub fn draw_list_panel(
    f: &mut Frame,
    area: Rect,
    title: &str,
    items: &[ItemRow],
    state: &mut ListState,
    is_active: bool,
    modal_visible: bool,
    theme: &ListPanelTheme,
) {
    // Border styling
    let (border_style, border_type) = get_border_style(is_active, modal_visible);
    let text_color = get_text_color(is_active, modal_visible);
    
    // Title styling
    let title_style = if is_active {
        accent_color()
    } else {
        Style::default().fg(text_color)
    };
    let title_span = Span::styled(format!(" {} ", title), title_style);
    
    // Build list items
    let list_items: Vec<ListItem> = if items.is_empty() {
        vec![ListItem::new(" No items")
            .style(Style::default().fg(Color::DarkGray))]
    } else {
        items.iter().map(|row| {
            let mut lines: Vec<Line> = Vec::new();
            let mut line1 = String::new();
            if let Some(icon) = &row.status_icon {
                line1.push_str(icon);
                line1.push(' ');
            }
            line1.push_str(&row.line1);
            lines.push(Line::from(line1));
            if let Some(second) = &row.line2 {
                lines.push(Line::from(Span::styled(
                    second.clone(),
                    Style::default().fg(theme.secondary_text)
                )));
            }
            ListItem::new(lines).style(Style::default().fg(text_color))
        }).collect()
    };
    
    // Selection highlighting
    let highlight_style = if modal_visible {
        get_selection_style_modal()
    } else {
        get_selection_style(is_active)
    };
    
    // Render list
    let list = List::new(list_items)
        .block(Block::default()
            .title(title_span)
            .borders(Borders::ALL)
            .border_type(border_type)
            .border_style(border_style))
        .highlight_style(highlight_style);
    
    f.render_stateful_widget(list, area, state);
}
```

## Form Panel Component

### Purpose

Generic form panel component for displaying forms with fields, cursor, and placeholders.

### Data Structures

```rust
pub struct FormField {
    pub label: String,
    pub value: String,
    pub placeholder: String,
}

pub struct FormState {
    pub active_field: usize,
    pub cursor_pos: usize,
}
```

### Component Signature

```rust
pub fn draw_form_panel(
    f: &mut Frame,
    area: Rect,
    title: &str,
    fields: &[FormField],
    state: &FormState,
    is_active: bool,
    modal_visible: bool,
)
```

### Cursor Rendering Pattern

```rust
// Use split_at to insert cursor
let display_text = if field.value.is_empty() {
    field.placeholder.clone()
} else {
    field.value.clone()
};

let cursor = state.cursor_pos.min(display_text.len());
let (head, tail) = display_text.split_at(cursor);

// Render: head + cursor + tail
let spans = vec![
    Span::styled(head, Style::default().fg(text_fg)),
    Span::styled("█", Style::default().fg(Color::White)),  // Form fields
    Span::styled(tail, Style::default().fg(text_fg)),
];
```

### Compact vs Normal Mode

```rust
let use_compact = content_area.height < 20;

if use_compact {
    // Compact: label: value on one line
} else {
    // Normal: label on one line, value on next line
}
```

## Popup/Dialog Patterns

### Popup Types

```rust
pub enum Popup {
    Confirm {
        title: String,
        message: String,
        selected: usize,  // 0 = Yes, 1 = No
    },
    Input {
        title: String,
        prompt: String,
        input: String,
        cursor_pos: usize,
    },
    Error {
        title: String,
        message: String,
    },
    Info {
        title: String,
        message: String,
        shown_at: std::time::Instant,
    },
}
```

### Content-Based Sizing

```rust
// Calculate width based on content
let max_line_len = message.lines().map(|l| l.len()).max().unwrap_or(30);
let popup_width = (max_line_len as u16 + 8)
    .max(40)  // Minimum
    .min((area.width as f32 * 0.60) as u16)  // Max 60%
    .min(area.width - 4);  // Screen bounds

// Wrap text
let wrapped_lines = wrap_text(message, max_text_width);

// Calculate height
let popup_height = (wrapped_lines.len() as u16 + 7).min(area.height - 4);
```

### Clear Before Render

```rust
// Always clear popup area before rendering
f.render_widget(Clear, popup_area);

// Then render popup content
```

## Toast Notification Pattern

### Structure

**IMPORTANT**: Toasts MUST use `SystemTime` for `shown_at`, NOT `Instant`:

```rust
use std::time::SystemTime;

pub enum ToastType {
    Success,
    Error,
    Info,
}

pub struct Toast {
    pub message: String,
    pub toast_type: ToastType,
    pub shown_at: SystemTime,  // NOT Instant
}
```

### Auto-Dismiss Logic

**IMPORTANT**: Toast auto-dismiss MUST be handled in the event handler:

```rust
// In event handler (events.rs)
use std::time::{SystemTime, UNIX_EPOCH};

// Auto-dismiss after 2.5 seconds
let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default();
app.toasts.retain(|toast| {
    let toast_time = toast.shown_at.duration_since(UNIX_EPOCH).unwrap_or_default();
    let elapsed = now.saturating_sub(toast_time);
    elapsed.as_secs_f32() <= 2.5
});
```

### Rendering Pattern

```rust
// Bottom-right, stacked upward
for toast in app.toasts.iter().rev() {
    let (icon, fg_color) = match toast.toast_type {
        ToastType::Success => ("✓", Color::Green),
        ToastType::Error => ("✗", Color::Red),
        ToastType::Info => ("ℹ", Color::Cyan),
    };
    
    // Calculate max width for alignment
    // Left-pad shorter toasts
    // Render with Clear before render
}
```

## File Browser Pattern

### Structure

```rust
pub struct FileBrowser {
    pub current_dir: PathBuf,
    pub entries: Vec<FileEntry>,
    pub selected_index: usize,
    pub scroll_offset: usize,
    pub visible_height: usize,
}

pub struct FileEntry {
    pub name: String,
    pub path: PathBuf,
    pub is_dir: bool,
    pub size: u64,
}
```

### Selection Persistence

```rust
// When navigating to parent, maintain selection context
let current_name = self.current_dir.file_name()
    .and_then(|n| n.to_str())
    .unwrap_or("")
    .to_string();

// Load parent entries...

// Find and select the directory we just came from
for (i, entry) in self.entries.iter().enumerate() {
    if entry.name == current_name {
        self.selected_index = i;
        self.adjust_scroll_to_selection();
        break;
    }
}
```

## Scrollbar Pattern

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

### Scroll Adjustment

```rust
fn adjust_scroll_to_selection(&mut self) {
    if self.selected_index < self.scroll_offset {
        self.scroll_offset = self.selected_index;
    } else if self.selected_index >= self.scroll_offset + self.visible_height {
        self.scroll_offset = self.selected_index.saturating_sub(self.visible_height - 1);
    }
}
```

## Empty State Pattern

### Standard Empty State

```rust
if items.is_empty() {
    vec![ListItem::new(" No items configured")
        .style(Style::default().fg(Color::DarkGray))]
} else {
    // Render actual items
}
```

## Text Wrapping Helper

```rust
fn wrap_text(text: &str, max_width: usize) -> Vec<String> {
    let mut lines = Vec::new();
    
    for paragraph in text.split('\n') {
        if paragraph.is_empty() {
            lines.push(String::new());
            continue;
        }
        
        let words: Vec<&str> = paragraph.split_whitespace().collect();
        let mut current_line = String::new();
        
        for word in words {
            if current_line.is_empty() {
                current_line = word.to_string();
            } else if current_line.len() + 1 + word.len() <= max_width {
                current_line.push(' ');
                current_line.push_str(word);
            } else {
                lines.push(current_line);
                current_line = word.to_string();
            }
        }
        
        if !current_line.is_empty() {
            lines.push(current_line);
        }
    }
    
    lines
}
```

## Best Practices

1. **Reusable Components**: Create reusable components for common patterns
2. **Consistent Styling**: Use universal styling helpers
3. **Empty States**: Always provide helpful empty state messages
4. **Clear Before Render**: Always clear modal/popup areas
5. **Scroll Management**: Update visible height on every render
6. **Selection Persistence**: Maintain context when navigating

## Implementation Checklist

When implementing components:

- [ ] Use list_panel for all list rendering
- [ ] Use form_panel for all form rendering
- [ ] Handle empty states
- [ ] Clear before rendering modals
- [ ] Implement scroll management
- [ ] Use text wrapping for popups
- [ ] Apply modal dimming
- [ ] Maintain selection persistence
- [ ] Use universal styling helpers
- [ ] Follow component patterns

## Reference

- **Styling Helpers**: See `02-styling-helpers.md` for styling functions
- **Layout Patterns**: See `03-layout-patterns.md` for layout structure
- **Event Handling**: See `05-event-handling.md` for component events
- **Implementation**: See Detour package for reference implementation

