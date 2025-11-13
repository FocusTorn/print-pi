# Universal Rust TUI Event Handling Patterns

## Purpose

This document defines universal event handling patterns for Rust TUI applications, ensuring consistent and predictable behavior across all TUI projects.

## Event Loop Pattern

### Standard Event Loop

```rust
pub fn handle_events(app: &mut App) -> std::io::Result<()> {
    // Auto-dismiss toasts (2.5 seconds)
    app.toasts.retain(|toast| {
        toast.shown_at.elapsed().map(|d| d.as_secs_f32() <= 2.5).unwrap_or(false)
    });
    
    if event::poll(Duration::from_millis(100))? {
        match event::read()? {
            Event::Key(key) => handle_key_event(key, app),
            Event::Mouse(mouse) => handle_mouse_event(mouse, app),
            _ => {}
        }
    }
    Ok(())
}
```

## Event Routing Hierarchy

### Priority-Based Routing

Events are handled in priority order:

1. **Overlays** (highest priority) - File browser, popups, reports, diff viewer
2. **Forms** - When form is active and content column is focused
3. **Global Navigation** - Column switching, quit, etc.
4. **View-Specific** - View-specific key bindings

### Implementation Pattern

```rust
fn handle_key_event(key: KeyEvent, app: &mut App) {
    // Priority 1: Overlays (highest priority)
    if app.file_browser.is_some() {
        handle_file_browser_keys(key, app);
        return;
    }
    
    if app.popup.is_some() {
        handle_popup_keys(key, app);
        return;
    }
    
    if app.validation_report.is_some() {
        handle_validation_report_keys(key, app);
        return;
    }
    
    if app.diff_viewer.is_some() {
        handle_diff_keys(key, app);
        return;
    }
    
    // Priority 2: Forms
    if matches!(app.view_mode, ViewMode::FormAdd | ViewMode::FormEdit)
        && app.active_column == ActiveColumn::Content {
        handle_form_keys(key, app);
        return;
    }
    
    // Priority 3: Global navigation
    match key.code {
        KeyCode::Esc | KeyCode::Char('q') => app.should_quit = true,
        KeyCode::Up | KeyCode::Char('k') => app.navigate_up(),
        KeyCode::Down | KeyCode::Char('j') => app.navigate_down(),
        KeyCode::Left | KeyCode::Char('h') => app.navigate_prev_column(),
        KeyCode::Right | KeyCode::Char('l') => app.navigate_next_column(),
        KeyCode::Enter => app.handle_enter(),
        _ => {}
    }
}
```

## Global Navigation Keys

### Standard Global Keys

```rust
match key.code {
    // Quit
    KeyCode::Esc | KeyCode::Char('q') | KeyCode::Char('Q') => {
        app.should_quit = true;
    }
    KeyCode::Char('c') if key.modifiers.contains(KeyModifiers::CONTROL) => {
        app.should_quit = true;
    }
    
    // Navigation - Up/Down
    KeyCode::Up | KeyCode::Char('k') => {
        app.navigate_up();
    }
    KeyCode::Down | KeyCode::Char('j') => {
        app.navigate_down();
    }
    
    // Navigation - Left/Right (columns)
    KeyCode::Left | KeyCode::Char('h') => {
        app.navigate_prev_column();
    }
    KeyCode::Right | KeyCode::Char('l') => {
        app.navigate_next_column();
    }
    
    // Actions
    KeyCode::Enter => {
        app.handle_enter();
    }
    KeyCode::Char(' ') => {
        app.handle_space();
    }
}
```

## Column Navigation Pattern

### Column 1 & 2 Navigation

```rust
// Up/Down: Preview content (no focus change)
KeyCode::Up | KeyCode::Char('k') => {
    app.navigate_up();  // Updates preview in Column 3
}

// Enter/Right: Execute action and move focus to Column 3
KeyCode::Enter | KeyCode::Right | KeyCode::Char('l') => {
    app.handle_enter();  // Executes action, moves focus to Column 3
}

// Left: Move focus back to previous column
KeyCode::Left | KeyCode::Char('h') => {
    app.navigate_prev_column();
}
```

### Column 3 Navigation

```rust
// Lists
KeyCode::Up | KeyCode::Char('k') => {
    // Navigate list items
}
KeyCode::Down | KeyCode::Char('j') => {
    // Navigate list items
}
KeyCode::Left | KeyCode::Char('h') => {
    // Return focus to Column 2
}

// Forms
KeyCode::Up => {
    // Navigate to previous field
}
KeyCode::Down => {
    // Navigate to next field
}
KeyCode::Left => {
    // Move cursor left
}
KeyCode::Right => {
    // Move cursor right
}
```

## Form Input Handling

### Standard Form Keys

```rust
fn handle_form_keys(key: KeyEvent, app: &mut App) {
    if let Some(form) = &mut app.form {
        match key.code {
            // Field navigation
            KeyCode::Up => {
                if form.active_field > 0 {
                    form.active_field -= 1;
                    form.cursor_pos = form.get_current_field_value().len();
                }
            }
            KeyCode::Down => {
                if form.active_field < form.fields.len() - 1 {
                    form.active_field += 1;
                    form.cursor_pos = form.get_current_field_value().len();
                }
            }
            
            // Cursor movement
            KeyCode::Left => {
                if form.cursor_pos > 0 {
                    form.cursor_pos -= 1;
                }
            }
            KeyCode::Right => {
                let value = form.get_current_field_value();
                if form.cursor_pos < value.len() {
                    form.cursor_pos += 1;
                }
            }
            KeyCode::Home => {
                form.cursor_pos = 0;
            }
            KeyCode::End => {
                form.cursor_pos = form.get_current_field_value().len();
            }
            
            // Input
            KeyCode::Char(c) => {
                let value = form.get_current_field_value_mut();
                value.insert(form.cursor_pos, c);
                form.cursor_pos += 1;
            }
            KeyCode::Backspace => {
                let value = form.get_current_field_value_mut();
                if form.cursor_pos > 0 {
                    value.remove(form.cursor_pos - 1);
                    form.cursor_pos -= 1;
                }
            }
            KeyCode::Delete => {
                let value = form.get_current_field_value_mut();
                if form.cursor_pos < value.len() {
                    value.remove(form.cursor_pos);
                }
            }
            
            // Actions
            KeyCode::Tab => {
                // Path completion or next field
                if key.modifiers.contains(KeyModifiers::CONTROL) {
                    // Handle completion
                } else {
                    form.active_field = (form.active_field + 1) % form.fields.len();
                    form.cursor_pos = form.get_current_field_value().len();
                }
            }
            KeyCode::Enter => {
                app.submit_form();
            }
            KeyCode::Esc => {
                app.form = None;
                app.active_column = ActiveColumn::Actions;
            }
            _ => {}
        }
    }
}
```

## Popup Event Handling

### Confirm Popup

```rust
fn handle_confirm_popup_keys(key: KeyEvent, popup: &mut Popup) {
    match key.code {
        KeyCode::Left | KeyCode::Right | KeyCode::Tab => {
            // Toggle between Yes/No
            if let Popup::Confirm { selected, .. } = popup {
                *selected = (*selected + 1) % 2;
            }
        }
        KeyCode::Enter => {
            // Confirm selection
        }
        KeyCode::Esc => {
            // Cancel (defaults to No)
        }
        _ => {}
    }
}
```

### Input Popup

```rust
fn handle_input_popup_keys(key: KeyEvent, popup: &mut Popup) {
    if let Popup::Input { input, cursor_pos, .. } = popup {
        match key.code {
            KeyCode::Char(c) => {
                input.insert(*cursor_pos, c);
                *cursor_pos += 1;
            }
            KeyCode::Backspace => {
                if *cursor_pos > 0 {
                    input.remove(*cursor_pos - 1);
                    *cursor_pos -= 1;
                }
            }
            KeyCode::Left => {
                if *cursor_pos > 0 {
                    *cursor_pos -= 1;
                }
            }
            KeyCode::Right => {
                if *cursor_pos < input.len() {
                    *cursor_pos += 1;
                }
            }
            KeyCode::Enter => {
                // Submit input
            }
            KeyCode::Esc => {
                // Cancel
            }
            _ => {}
        }
    }
}
```

## File Browser Event Handling

```rust
fn handle_file_browser_keys(key: KeyEvent, browser: &mut FileBrowser) {
    match key.code {
        KeyCode::Up | KeyCode::Char('k') => {
            browser.navigate_up();
        }
        KeyCode::Down | KeyCode::Char('j') => {
            browser.navigate_down();
        }
        KeyCode::Enter | KeyCode::Right => {
            browser.enter_directory();
        }
        KeyCode::Left => {
            browser.go_to_parent();
        }
        KeyCode::Esc => {
            // Close browser
        }
        _ => {}
    }
}
```

## Mouse Event Handling

### Mouse Click Handling

```rust
fn handle_mouse_event(mouse: MouseEvent, app: &mut App) {
    match mouse.kind {
        MouseEventKind::ScrollUp => {
            // Scroll up
        }
        MouseEventKind::ScrollDown => {
            // Scroll down
        }
        MouseEventKind::Down(button) => {
            // Handle click
        }
        _ => {}
    }
}
```

## Navigation Implementation

### Navigate Up/Down

```rust
impl App {
    pub fn navigate_up(&mut self) {
        match self.active_column {
            ActiveColumn::Views => {
                if let Some(selected) = self.view_state.selected() {
                    if selected > 0 {
                        self.view_state.select(Some(selected - 1));
                        self.update_view_mode();
                    }
                }
            }
            ActiveColumn::Actions => {
                if let Some(selected) = self.action_state.selected() {
                    if selected > 0 {
                        self.action_state.select(Some(selected - 1));
                    }
                }
            }
            ActiveColumn::Content => {
                self.navigate_content_up();
            }
        }
    }
}
```

### Navigate Next Column

```rust
impl App {
    pub fn navigate_next_column(&mut self) {
        match self.active_column {
            ActiveColumn::Views => {
                self.active_column = ActiveColumn::Actions;
            }
            ActiveColumn::Actions => {
                self.active_column = ActiveColumn::Content;
            }
            ActiveColumn::Content => {
                // Stay in content
            }
        }
    }
}
```

## Best Practices

1. **Priority Order**: Handle overlays before forms, forms before navigation
2. **Early Return**: Use early return after handling overlay events
3. **Consistent Key Bindings**: Use standard keys (h/j/k/l, arrows, Enter, Esc)
4. **Context Awareness**: Handle keys based on current context
5. **State Updates**: Update state immutably when possible
6. **User Feedback**: Provide immediate visual feedback for actions

## Implementation Checklist

When implementing event handling:

- [ ] Implement priority-based routing
- [ ] Handle overlays first (file browser, popups, etc.)
- [ ] Handle forms when active
- [ ] Handle global navigation
- [ ] Handle view-specific keys
- [ ] Use standard key bindings
- [ ] Provide visual feedback
- [ ] Update state correctly
- [ ] Handle edge cases
- [ ] Test all key combinations

## Reference

- **State Management**: See `06-state-management.md` for state update patterns
- **Component Patterns**: See `04-component-patterns.md` for component events
- **Layout Patterns**: See `03-layout-patterns.md` for navigation context
- **Implementation**: See Detour package for reference implementation

