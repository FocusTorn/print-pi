# Universal Rust TUI UI Rendering Patterns

## Purpose

This document defines the standard UI rendering patterns for Rust TUI applications, ensuring consistent implementation from the start.

## Main UI Function

### Function Name

**CRITICAL**: The main UI rendering function MUST be named `ui()`:

```rust
pub fn ui(f: &mut Frame, app: &mut App) {
    // UI rendering code
}
```

**NOT** `draw()` or any other name.

### Function Signature

```rust
use ratatui::Frame;

pub fn ui(f: &mut Frame, app: &mut App) {
    let area = f.size();
    // ... rendering code
}
```

## Title Bar Rendering

### Standard Title Bar Pattern

**REQUIRED**: Title bar MUST use rounded borders and display status information:

```rust
fn draw_title(f: &mut Frame, area: Rect, app: &App) {
    let modal_visible = app.is_modal_visible();
    
    let title_text = format!(
        " [App Name]  |  Status: {}  |  Info: {} ",
        app.status_text(),
        app.info_text()
    );
    
    let border_color = if modal_visible {
        hex_color(0x222222)
    } else {
        hex_color(0x666666)
    };
    let text_color = if modal_visible {
        hex_color(0x444444)
    } else {
        hex_color(0xBBBBBB)
    };
    
    let title_block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)  // REQUIRED: Rounded borders
        .border_style(Style::default().fg(border_color));
    
    let title = Paragraph::new(title_text)
        .alignment(Alignment::Center)
        .style(Style::default().fg(text_color).add_modifier(Modifier::BOLD))
        .block(title_block);
    
    f.render_widget(title, area);
}
```

## View Column Rendering

### Standard View Column Pattern

**REQUIRED**: View column MUST display views with arrows (►) and proper padding:

```rust
fn draw_view_column(f: &mut Frame, area: Rect, app: &mut App) {
    let modal_visible = app.is_modal_visible();
    let is_active = app.active_column == ActiveColumn::Views && !modal_visible;
    
    let border_style = if modal_visible {
        Style::default().fg(hex_color(0x222222))
    } else if is_active {
        Style::default().fg(Color::White)
    } else {
        Style::default().fg(hex_color(0x333333))
    };
    let border_type = if is_active { BorderType::Thick } else { BorderType::Plain };
    let text_color = if modal_visible {
        hex_color(0x444444)
    } else if is_active {
        hex_color(0xFFFFFF)
    } else {
        hex_color(0x777777)
    };
    
    // All views have associated panels, so all get arrows with proper padding
    let max_width = app.views.iter().map(|v| v.len()).max().unwrap_or(8);
    let items: Vec<ListItem> = app.views.iter().map(|view| {
        let padding = max_width - view.len();
        let display = format!(" {}{} ► ", view, " ".repeat(padding));  // REQUIRED: Arrow indicator
        ListItem::new(display).style(Style::default().fg(text_color))
    }).collect();
    
    // When modal is visible, use the dimmed inactive style
    let highlight_style = if modal_visible {
        Style::default()
            .bg(hex_color(0x0D0D0D))  // Nearly invisible highlight
            .fg(hex_color(0x444444))  // Dimmed grey text
    } else {
        get_selection_style(is_active)
    };
    
    let list = List::new(items)
        .block(Block::default()
            .borders(Borders::ALL)
            .border_type(border_type)
            .border_style(border_style))
        .highlight_style(highlight_style);
    
    f.render_stateful_widget(list, area, &mut app.view_state);
}
```

## Action Column Rendering

### Standard Action Column Pattern

**REQUIRED**: Action column MUST display actions with conditional arrows and empty highlight symbol:

```rust
fn draw_action_column(f: &mut Frame, area: Rect, app: &mut App) {
    let modal_visible = app.is_modal_visible();
    let actions = app.get_current_actions();  // REQUIRED: Use get_current_actions()
    let is_active = app.active_column == ActiveColumn::Actions && !modal_visible;
    
    let border_style = if modal_visible {
        Style::default().fg(hex_color(0x222222))
    } else if is_active {
        Style::default().fg(Color::White)
    } else {
        Style::default().fg(hex_color(0x333333))
    };
    let border_type = if is_active { BorderType::Thick } else { BorderType::Plain };
    let text_color = if modal_visible {
        hex_color(0x444444)
    } else if is_active {
        hex_color(0xFFFFFF)
    } else {
        hex_color(0x777777)
    };
    
    // Actions that open sub-panels get arrows with proper padding
    let max_width = actions.iter().map(|a| a.len()).max().unwrap_or(15);
    let items: Vec<ListItem> = actions.iter().map(|action| {
        let has_subpanel = matches!(action.as_str(),
            "List" | "New" | "Edit"  // Define which actions have sub-panels
        );
        let padding = max_width - action.len();
        let display = if has_subpanel {
            format!(" {}{} ► ", action, " ".repeat(padding))  // Arrow for sub-panels
        } else {
            format!(" {}{}", action, " ".repeat(padding))  // No arrow
        };
        ListItem::new(display).style(Style::default().fg(text_color))
    }).collect();
    
    // Selection in column 2 uses subtle cyan highlight, no arrow indicator
    let highlight_style = if modal_visible {
        Style::default()
            .bg(hex_color(0x0D0D0D))
            .fg(hex_color(0x444444))
    } else {
        get_selection_style(is_active)
    };
    
    let list = List::new(items)
        .block(Block::default()
            .borders(Borders::ALL)
            .border_type(border_type)
            .border_style(border_style))
        .highlight_style(highlight_style)
        .highlight_symbol("");  // REQUIRED: Empty string = no arrow indicator
    
    f.render_stateful_widget(list, area, &mut app.action_state);
}
```

## Content Column Rendering

### Standard Content Column Pattern

**REQUIRED**: Content column MUST use `list_panel` component for lists and support dynamic preview updates:

```rust
fn draw_content_column(f: &mut Frame, area: Rect, app: &mut App) {
    let modal_visible = app.is_modal_visible();
    
    // Determine what to render based on active column and selection
    let current_view_mode = app.view_mode;
    let mode_to_render = match app.active_column {
        ActiveColumn::Views => {
            // Column 1 (Views) is active - show preview based on selected view
            App::view_mode_from_index(app.view_state.selected().unwrap_or(0))  // REQUIRED: Use helper
        }
        ActiveColumn::Actions => {
            // Column 2 (Actions) is active - show preview based on selected action
            current_view_mode  // For now, use current view mode (could be enhanced)
        }
        ActiveColumn::Content => {
            // Column 3 (Content) is active - always show current view mode content
            current_view_mode
        }
    };
    
    // Special case: Hierarchical views with detail preview
    // When Content column is active and a child item is selected, show detail preview
    if mode_to_render == ViewMode::HierarchicalList 
        && app.active_column == ActiveColumn::Content 
        && app.selected_parent.is_some() 
        && app.content_state.selected().is_some() {
        if let Some(parent_index) = app.selected_parent {
            if let Some(parent) = app.parents.get(parent_index) {
                if let Some(child_index) = app.content_state.selected() {
                    if child_index < parent.children.len() {
                        // Show detail preview instead of list
                        draw_detail_preview(f, area, app, modal_visible);
                        return;
                    }
                }
            }
        }
    }
    
    // Default rendering
    match mode_to_render {
        ViewMode::List => draw_list_view(f, area, app, modal_visible),
        ViewMode::HierarchicalList => draw_hierarchical_list(f, area, app, modal_visible),
        ViewMode::Add => draw_add_view(f, area, app, modal_visible),
        // ... other view modes
    }
}

fn draw_list_view(f: &mut Frame, area: Rect, app: &mut App, modal_visible: bool) {
    let is_active = app.active_column == ActiveColumn::Content && !modal_visible;
    
    // Convert data to ItemRow format
    let items: Vec<ItemRow> = app.data.iter().map(|item| {
        ItemRow {
            line1: format!("{}", item.name),
            line2: Some(format!("   Details: {}", item.details)),
            status_icon: Some(if item.active { "✓".to_string() } else { "○".to_string() }),
        }
    }).collect();
    
    // REQUIRED: Use list_panel component
    crate::components::list_panel::draw_list_panel(
        f,
        area,
        &format!(" Items ({}) ", app.data.len()),
        &items,
        &mut app.content_state,
        is_active,
        modal_visible,
        &crate::components::list_panel::ListPanelTheme::default(),
    );
}
```

## Popup Rendering

### Standard Popup Pattern

**REQUIRED**: Popup module MUST export `draw_popup()` function:

```rust
// In popup.rs
pub fn draw_popup(f: &mut Frame, area: Rect, popup: &Popup) {
    match popup {
        Popup::Confirm { title, message, selected } => {
            draw_confirm(f, area, title, message, *selected);
        }
        Popup::Input { title, prompt, input, cursor_pos } => {
            draw_input(f, area, title, prompt, input, *cursor_pos);
        }
        Popup::Error { title, message } => {
            draw_error(f, area, title, message);
        }
        Popup::Info { title, message, .. } => {
            draw_info(f, area, title, message);
        }
    }
}

// In ui.rs main function
pub fn ui(f: &mut Frame, app: &mut App) {
    // ... render main UI ...
    
    // Draw popup last (overlays everything)
    if let Some(popup) = &app.popup {
        popup::draw_popup(f, area, popup);  // REQUIRED: Call draw_popup()
    }
}
```

## Toast Rendering

### Standard Toast Pattern

**REQUIRED**: Toasts MUST be rendered in bottom status area, bottom-right position:

```rust
fn draw_toasts(f: &mut Frame, area: Rect, app: &App) {
    use crate::components::ToastType;
    
    if app.toasts.is_empty() {
        return;
    }
    
    // Calculate the maximum width of all toasts
    let mut max_width = 0usize;
    let mut toast_data: Vec<(String, Color, String)> = Vec::new();
    
    for toast in &app.toasts {
        let (icon, fg_color) = match toast.toast_type {
            ToastType::Success => ("✓", Color::Green),
            ToastType::Error => ("✗", Color::Red),
            ToastType::Info => ("ℹ", Color::Cyan),
        };
        
        let content = format!("{} {}", icon, toast.message);
        max_width = max_width.max(content.len());
        toast_data.push((content, fg_color, icon.to_string()));
    }
    
    // Add 3 spaces total for padding (2 on left, 1 on right minimum)
    max_width += 3;
    
    // Position offsets: start 1 line lower (down), very close to right edge
    let y_start_offset = 1u16;
    let x_padding_from_edge = 0u16;
    
    // Start from the bottom, going up
    let mut y_offset = 0u16;
    
    for (content, fg_color, _) in toast_data.iter().rev() {
        // Left-pad content to match max width
        let content_len = content.len();
        let left_padding = max_width.saturating_sub(content_len).saturating_sub(1).max(2);
        
        let mut padded_text = format!("{}{} ", " ".repeat(left_padding), content);
        
        // Pad to exact width if needed
        while padded_text.len() < max_width {
            padded_text.push(' ');
        }
        if padded_text.len() > max_width {
            padded_text.truncate(max_width);
        }
        
        let toast_height = 1u16;
        
        // Position on bottom right
        let toast_area = Rect {
            x: area.width.saturating_sub(max_width as u16 + x_padding_from_edge),
            y: (area.y + y_start_offset).saturating_sub(y_offset + toast_height),
            width: max_width as u16,
            height: toast_height,
        };
        
        // Clear the area first
        f.render_widget(Clear, toast_area);
        
        // Render toast
        let toast_widget = Paragraph::new(padded_text)
            .style(Style::default()
                .fg(*fg_color)
                .bg(hex_color(0x0A0A0A))
                .add_modifier(Modifier::BOLD));
        
        f.render_widget(toast_widget, toast_area);
        
        y_offset += toast_height;
    }
}
```

## Hierarchical Views and Detail Previews

### Two-Level Navigation Pattern

When implementing hierarchical views (e.g., scripts → files), Column 3 should update dynamically:

1. **Level 1**: Show parent list (e.g., scripts)
2. **Level 2**: When parent selected, show child list (e.g., files)
3. **Level 3**: When child selected and Content column active, show detail preview

### Detail Preview Implementation

```rust
fn draw_detail_preview(f: &mut Frame, area: Rect, app: &App, modal_visible: bool) {
    let border_color = if modal_visible {
        hex_color(0x222222)
    } else {
        Color::White
    };
    
    let block = Block::default()
        .title(" Detail Preview ")
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(border_color));
    
    f.render_widget(block, area);
    
    let content_area = Rect {
        x: area.x + 2,
        y: area.y + 2,
        width: area.width.saturating_sub(4),
        height: area.height.saturating_sub(4),
    };
    
    // Get selected item details
    if let Some(parent_index) = app.selected_parent {
        if let Some(parent) = app.parents.get(parent_index) {
            if let Some(child_index) = app.content_state.selected() {
                if let Some(child) = parent.children.get(child_index) {
                    // Display detailed information
                    let lines = vec![
                        Line::from(vec![
                            Span::styled("Name: ", Style::default().fg(hex_color(0x888888))),
                            Span::styled(&child.name, Style::default().fg(Color::White).add_modifier(Modifier::BOLD)),
                        ]),
                        Line::from(""),
                        Line::from(vec![
                            Span::styled("Status: ", Style::default().fg(hex_color(0x888888))),
                            Span::styled(&child.status, Style::default().fg(child.status_color)),
                        ]),
                        // ... more detail lines
                    ];
                    
                    let para = Paragraph::new(lines);
                    f.render_widget(para, content_area);
                    return;
                }
            }
        }
    }
    
    // Fallback message
    let para = Paragraph::new("Select an item to view details")
        .style(Style::default().fg(Color::DarkGray));
    f.render_widget(para, content_area);
}
```

### Navigation Handling for Hierarchical Views

```rust
// In events.rs - handle Enter key
pub fn handle_enter(&mut self) {
    match self.active_column {
        ActiveColumn::Content => {
            match self.view_mode {
                ViewMode::HierarchicalList => {
                    if self.selected_parent.is_none() {
                        // Select parent from list
                        if let Some(selected) = self.content_state.selected() {
                            if selected < self.parents.len() {
                                self.selected_parent = Some(selected);
                                self.update_parent_status(selected);
                                // Reset to start of child list
                                self.content_state.select(Some(0));
                            }
                        }
                    }
                    // If parent selected, content_state navigates through children
                }
                // ... other view modes
            }
        }
        // ... other columns
    }
}

// Back navigation (Left/Backspace)
KeyCode::Left | KeyCode::Char('h') | KeyCode::Backspace => {
    if app.view_mode == ViewMode::HierarchicalList && app.selected_parent.is_some() {
        // Go back from child list to parent list
        app.selected_parent = None;
        app.content_state.select(Some(0));
    } else {
        app.navigate_prev_column();
    }
}
```

## Implementation Checklist

When implementing UI rendering:

- [ ] Name main UI function `ui()` (not `draw()`)
- [ ] Use rounded borders for title bar
- [ ] Display status information in title bar
- [ ] Add arrows (►) to all views in view column
- [ ] Add conditional arrows to actions with sub-panels
- [ ] Use empty highlight symbol for action column
- [ ] Use `list_panel` component for content lists
- [ ] Use `get_current_actions()` for action column
- [ ] Use `view_mode_from_index()` for view mode mapping
- [ ] Export `draw_popup()` from popup module
- [ ] Render toasts in bottom status area
- [ ] Render popups last (overlays everything)
- [ ] For hierarchical views: Implement detail preview updates
- [ ] For hierarchical views: Handle two-level navigation (parent → child)
- [ ] For hierarchical views: Update Column 3 preview when navigating children

## Reference

- **Component Patterns**: See `04-component-patterns.md` for component usage
- **Layout Patterns**: See `03-layout-patterns.md` for layout structure
- **State Management**: See `06-state-management.md` for state patterns
- **Project Structure**: See `07-project-structure.md` for module organization
- **Implementation**: See Detour package for reference implementation

