# Universal Rust TUI Layout Patterns

## Purpose

This document defines universal layout patterns for Rust TUI applications, focusing on the three-column horizontal layout pattern that is the standard for workspace TUI applications.

## Three-Column Layout Pattern

### Overview

The standard layout consists of three horizontal columns:

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

### Layout Structure

1. **Title Bar** (3 lines) - Application title, status, information
2. **Content Area** - Three columns:
   - Column 1: Views (narrow, dynamic width)
   - Column 2: Actions (medium, dynamic width)
   - Column 3: Content (wide, remaining space)
3. **Status Area** (5 lines) - Status messages, help text, descriptions

## Area Calculations

### Standard Area Layout

```rust
let area = f.size();

// Title bar (3 lines)
let title_height = 3;
let title_area = Rect {
    x: area.x,
    y: area.y,
    width: area.width,
    height: title_height,
};

// Status area (5 lines)
let status_height = 5;
let status_area = Rect {
    x: area.x,
    y: area.height.saturating_sub(status_height),
    width: area.width,
    height: status_height,
};

// Content area (remaining space)
let content_y = title_area.y + title_area.height;
let content_height = area.height.saturating_sub(title_height + status_height);
let content_area = Rect {
    x: area.x,
    y: content_y,
    width: area.width,
    height: content_height,
};
```

### Column Width Calculations

**REQUIRED**: Use helper functions that take App reference:

```rust
fn calculate_view_width(app: &App) -> u16 {
    let max_len = app.views
        .iter()
        .map(|v| v.len())
        .max()
        .unwrap_or(8);
    (max_len + 4) as u16 // +2 padding, +2 borders
}

fn calculate_action_width(app: &App) -> u16 {
    let actions = app.get_current_actions();
    let max_len = actions
        .iter()
        .map(|a| a.len())
        .max()
        .unwrap_or(15);
    (max_len + 6) as u16 // +2 padding, +2 borders, +2 indicator space
}

// In ui rendering:
let col1_width = calculate_view_width(app);
let col2_width = calculate_action_width(app);
```

// Column 1 area
let col1_area = Rect {
    x: area.x + 1,
    y: content_y,
    width: col1_width,
    height: content_height,
};

// Column 2 area
let col2_x = col1_area.x + col1_width + 1;
let col2_area = Rect {
    x: col2_x,
    y: content_y,
    width: col2_width,
    height: content_height,
};

// Column 3 area (remaining space)
let col3_x = col2_area.x + col2_width + 1;
let col3_width = area.width.saturating_sub(col3_x + 1);
let col3_area = Rect {
    x: col3_x,
    y: content_y,
    width: col3_width,
    height: content_height,
};
```

## Minimum Size Requirements

### Standard Minimums

- **Width**: 120 columns minimum
- **Height**: 16 rows minimum

### Handling Below Minimum

```rust
if area.width < 120 || area.height < 16 {
    draw_minimal_ui(f, app);
    return;
}
```

### Minimal UI Implementation

```rust
fn draw_minimal_ui(f: &mut Frame, app: &App) {
    let area = f.size();
    
    // Clear screen
    f.render_widget(
        Paragraph::new("").style(Style::default().bg(Color::Black)),
        area,
    );
    
    // Error message
    let message = "Terminal too small! Minimum: 120x16";
    let message_para = Paragraph::new(message)
        .alignment(Alignment::Center)
        .style(Style::default()
            .fg(Color::Red)
            .add_modifier(Modifier::BOLD));
    
    f.render_widget(message_para, Rect {
        x: area.x,
        y: area.y + area.height / 2 - 1,
        width: area.width,
        height: 1,
    });
    
    // Current size
    let size_text = format!("Current: {}x{}", area.width, area.height);
    let size_para = Paragraph::new(size_text)
        .alignment(Alignment::Center)
        .style(Style::default().fg(Color::DarkGray));
    
    f.render_widget(size_para, Rect {
        x: area.x,
        y: area.y + area.height / 2,
        width: area.width,
        height: 1,
    });
    
    // Quit hint
    let quit_text = "Press 'q' to quit";
    let quit_para = Paragraph::new(quit_text)
        .alignment(Alignment::Center)
        .style(Style::default().fg(Color::DarkGray));
    
    f.render_widget(quit_para, Rect {
        x: area.x,
        y: area.y + area.height / 2 + 1,
        width: area.width,
        height: 1,
    });
}
```

## Column Responsibilities

### Column 1: Views

- **Purpose**: Navigation between different views/modes
- **Width**: Dynamic based on longest view name
- **Content**: List of available views
- **Selection**: Single selection, determines current view mode
- **Navigation**: Up/Down arrows, Enter to select

### Column 2: Actions

- **Purpose**: Actions available for current view
- **Width**: Dynamic based on longest action name
- **Content**: List of actions for current view
- **Selection**: Single selection, determines action to perform
- **Navigation**: Up/Down arrows, Enter to execute
- **Indicators**: Arrow (►) for actions with sub-panels

### Column 3: Content

- **Purpose**: Display content based on view + action
- **Width**: Remaining space after columns 1 and 2
- **Content**: Varies based on view and action
- **Types**: Lists, forms, information panels, etc.
- **Focus**: Receives focus when action is executed

## Responsive Behavior

### Dynamic Width Adjustment

Columns adjust their width based on content:

```rust
// Column 1 adjusts to longest view name
let col1_width = calculate_view_width(views);

// Column 2 adjusts to longest action name
let col2_width = calculate_action_width(actions);

// Column 3 takes remaining space
let col3_width = area.width.saturating_sub(col1_x + col2_width + 2);
```

### Minimum Column Widths

Ensure minimum usable widths:

```rust
let col1_width = col1_width.max(12);  // Minimum 12 columns
let col2_width = col2_width.max(20);  // Minimum 20 columns
let col3_width = col3_width.max(60);  // Minimum 60 columns
```

## Status Area Layout

### Status Area Structure (5 lines)

```
Line 1: Status message or error
Line 2: Context help (keyboard shortcuts)
Line 3: Separator line (────────────)
Line 4: Dynamic description
Line 5: Reserved/empty
```

### Status Area Implementation

**REQUIRED**: Status area MUST follow this structure with toast rendering:

```rust
fn draw_bottom_status(f: &mut Frame, area: Rect, app: &App) {
    let modal_visible = app.is_modal_visible();
    
    // Draw toast notifications stacked on bottom right
    draw_toasts(f, area, app);
    
    // Line 1: Global (grey) + Panel-specific (white) bindings
    let global_text = "[↑↓←→] Navigate  [q] Quit";
    let panel_text = get_panel_help(app);  // Returns view/action-specific help
    let spans = vec![
        Span::styled(global_text, Style::default().fg(if modal_visible { hex_color(0x333333) } else { hex_color(0x777777) })),
        Span::raw("  "),
        Span::styled(panel_text, Style::default().fg(if modal_visible { hex_color(0x444444) } else { Color::White })),
    ];
    let nav_paragraph = Paragraph::new(Line::from(spans));
    f.render_widget(nav_paragraph, Rect { x: area.x, y: area.y + 1, width: area.width, height: 1 });
    
    // Line 2: Horizontal divider
    let divider_line = "─".repeat(area.width as usize);
    let divider_color = if modal_visible {
        hex_color(0x222222)
    } else {
        Color::White
    };
    let divider_paragraph = Paragraph::new(divider_line)
        .style(Style::default().fg(divider_color));
    f.render_widget(divider_paragraph, Rect {
        x: area.x,
        y: area.y + 2,
        width: area.width,
        height: 1,
    });
    
    // Line 3: Dynamic description
    let description = app.get_current_description();
    let desc_line = format!(" {:<width$} ", description, width = area.width as usize - 2);
    let desc_color = if modal_visible {
        hex_color(0x333333)
    } else {
        Color::White
    };
    let desc_paragraph = Paragraph::new(desc_line)
        .style(Style::default().fg(desc_color));
    f.render_widget(desc_paragraph, Rect {
        x: area.x,
        y: area.y + 3,
        width: area.width,
        height: 1,
    });
}

fn get_panel_help(app: &App) -> String {
    match app.view_mode {
        ViewMode::List => {
            match app.active_column {
                ActiveColumn::Views => "[Enter] Select".to_string(),
                ActiveColumn::Actions => "[Enter] Execute".to_string(),
                ActiveColumn::Content => "[Enter] Select  [d] Delete".to_string(),
            }
        }
        // ... other view modes
        _ => String::new(),
    }
}
```

## Centered Popup/Modal Layout

### Centered Rectangle Helper

Use the `centered_rect()` helper from `02-styling-helpers.md`:

```rust
// Center a popup that takes 60% width and 40% height
let popup_area = centered_rect(60, 40, area);
```

### Common Popup Sizes

```rust
// File browser
let browser_area = centered_rect(70, 88, area);

// Confirm dialog
let confirm_area = centered_rect(60, 30, area);

// Input dialog
let input_area = centered_rect(50, 20, area);

// Validation report
let report_area = centered_rect(80, 89, area);
```

## Best Practices

1. **Always Check Minimum Size**: Handle undersized terminals gracefully
2. **Dynamic Column Widths**: Adjust based on content, not fixed values
3. **Responsive Layout**: Ensure columns work at various terminal sizes
4. **Consistent Spacing**: Use 1-column gaps between columns
5. **Status Area**: Always reserve 5 lines for status area
6. **Title Bar**: Always reserve 3 lines for title bar

## Implementation Checklist

When implementing layout:

- [ ] Check minimum size (120x16) before rendering
- [ ] Calculate title area (3 lines)
- [ ] Calculate status area (5 lines)
- [ ] Calculate content area (remaining space)
- [ ] Calculate column widths dynamically
- [ ] Ensure minimum column widths
- [ ] Handle responsive behavior
- [ ] Use centered_rect() for popups
- [ ] Test at various terminal sizes
- [ ] Test minimum size handling

## Reference

- **Styling Helpers**: See `02-styling-helpers.md` for centered_rect() helper
- **Component Patterns**: See `04-component-patterns.md` for component layout
- **State Management**: See `06-state-management.md` for layout state
- **Implementation**: See Detour package for reference implementation

