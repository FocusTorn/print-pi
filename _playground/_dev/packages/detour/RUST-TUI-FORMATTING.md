# Rust TUI Formatting Guide

## Overview
This document defines the complete visual design system for the Detour TUI, ensuring consistency across all UI components, states, and interactions.

---

## Color Palette

### Primary Colors (Hex Format)
```rust
fn hex_color(hex: u32) -> Color {
    Color::Rgb(
        ((hex >> 16) & 0xFF) as u8,
        ((hex >> 8) & 0xFF) as u8,
        (hex & 0xFF) as u8,
    )
}
```

| Color | Hex Value | Usage |
|-------|-----------|-------|
| Background | `0x0A0A0A` | Main TUI background |
| Panel Background | `0x141420` | Solid panel/modal background |
| Active Selection BG | `0x1A2A2A` | Highlighted item background (focused) |
| Inactive Selection BG | `0x151515` | Highlighted item background (unfocused) |
| Modal Dimmed Border | `0x222222` | Borders when modal is visible |
| Modal Dimmed Text | `0x444444` | Text when modal is visible |
| Inactive Border | `0x333333` | Panel borders when not focused |
| Inactive Text | `0x777777` | Text in unfocused panels |
| Accent Cyan | `Color::Cyan` | Primary accent color |
| White Text | `0xFFFFFF` or `Color::White` | Active panel text |
| Grey Text | `Color::Gray` | Inactive form fields |
| Placeholder | `Color::DarkGray` | Empty field placeholders |

### Semantic Colors
- **Success**: `Color::Green` (bold used in status line)
- **Error**: `Color::Red` (bold used in status line)
- **Warning**: `Color::Yellow`
- **Info**: `Color::Cyan`

---

## Universal Styling Helpers

### Selection Style (All Columns)
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

### Selection Style When Modal Visible
```rust
// Columns 1 and 2 selection while a modal/report is visible
let highlight_style = Style::default()
    .bg(hex_color(0x0D0D0D))
    .fg(hex_color(0x444444));
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

---

## Border Styling

### Standard Panel Borders
```rust
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
```

### Special Border Types
- **Title Bar**: `BorderType::Rounded` (always)
- **Validation Report**: `BorderType::Double`; dims other UI
- **Modal/Popup**: `BorderType::Rounded` with cyan borders
- **File Browser**: `BorderType::Rounded` with cyan borders
- **Content Panels**: `BorderType::Thick` (focused) or `BorderType::Plain` (unfocused)

---

## Text Styling

### Text Color Logic
```rust
let text_color = if modal_visible {
    hex_color(0x444444)  // Dimmed grey when modal visible
} else if is_active {
    hex_color(0xFFFFFF)  // White when panel is focused
} else {
    hex_color(0x777777)  // Grey when panel is unfocused
};
```

### Title Styling
```rust
let title = Span::styled(
    " Title Text ",
    if is_active { 
        accent_color()  // Cyan when focused
    } else { 
        Style::default().fg(text_color)  // Grey when unfocused
    }
);
```

---

## Column Layout & Navigation

### Column 1: Views
- **Width**: Dynamic based on longest view name + arrow padding
- **Arrow**: Static `►` with proper padding
  ```rust
  let max_width = views.iter().map(|v| v.len()).max().unwrap_or(8);
  let display = format!(" {}{} ► ", view, " ".repeat(padding));
  ```
- **Selection**: Uses `get_selection_style(is_active)`
- **Symbol**: No highlight symbol (empty string)

### Column 2: Actions
- **Width**: Dynamic based on longest action name + arrow padding
- **Arrow**: Static `►` only for actions with sub-panels; "Validate" has no arrow
  ```rust
  let has_subpanel = matches!(action.as_str(), 
      "List" | "Add" | "Edit" | "Add Include" | "Export"
  );
  let display = if has_subpanel {
      format!(" {}{} ► ", action, " ".repeat(padding))
  } else {
      format!(" {}{}", action, " ".repeat(padding))
  };
  ```
- **Selection**: Uses `get_selection_style(is_active)`
- **Symbol**: `highlight_symbol("")` - NO arrow indicator

#### Detours Actions Content
- Detours: `List`, `Validate` (no `Backup`/`Restore`)

### Column 3: Content
- **Width**: Remaining space after Column 1 and 2
- **Selection**: Uses `get_selection_style(is_active)`
- **Title**: Uses `accent_color()` when focused, `text_color` when unfocused

### Arrow Padding Rules
1. Calculate max width of all items
2. Add 1 space padding before arrow
3. Add 1 space padding after arrow
4. Formula: `" {item}{padding} ► "`

---

## Form Input Styling

### Input Field States
```rust
// Active field with content
if is_active && app.form.active_field == field_index {
    let mut text = app.form.field_value.clone();
    let is_empty = text.is_empty();
    
    if is_empty {
        text = "placeholder text here".to_string();
    }
    
    // Insert cursor at current position
    text.insert(app.form.cursor_pos.min(text.len()), '█');
    
    let color = if !is_active {
        text_color  // Grey when panel not focused
    } else if is_empty {
        Color::DarkGray  // Placeholder is dark grey
    } else {
        Color::White  // Active input is white
    };
    
    (text, color)
}
```

### Field Label Styling
```rust
let label_style = if is_active && app.form.active_field == field_index {
    bold_accent_color()  // Cyan + bold for active field
} else {
    Style::default().fg(text_color)  // Grey for inactive
};
```

### Cursor Behavior
- **Visible**: Only when `is_active && active_field == current_field`
- **Character**: `█` (full block)
- **Position**: Inserted at `cursor_pos` within the text string
- **Hidden**: When panel is not focused or field is not active

### Placeholder Text Rules
1. Show when field is empty
2. Style with `Color::DarkGray`
3. Replace with user input as they type
4. Cursor still visible when editing empty field

---

## Modal & Popup Styling

### Modal Dimming Effect
When any modal/report is visible, do not draw an overlay. Instead, conditionally dim all non-modal UI using `app.is_modal_visible()`:

All UI elements adjust their colors:
- Borders: `hex_color(0x222222)` (dark grey)
- Text: `hex_color(0x444444)` (dim grey)
- Status line: Also dimmed

### File Browser Modal
```rust
// 1. Clear browser area for solid background
f.render_widget(Clear, browser_area);

// 2. Render browser with solid background
let block = Block::default()
    .borders(Borders::ALL)
    .border_type(BorderType::Rounded)
    .border_style(Style::default().fg(Color::Cyan))
    .style(Style::default().bg(hex_color(0x141420)));
```

### Popup Dimensions

#### **Content-Based Width (Confirm & Message Popups)**
```rust
// Calculate width based on content, not fixed percentage
let max_line_len = message.lines().map(|l| l.len()).max().unwrap_or(30);
let popup_width = (max_line_len as u16 + 8)  // Content + padding
    .max(40)                                   // Minimum width
    .min((area.width as f32 * 0.60) as u16)   // Maximum 60% screen
    .min(area.width - 4);                      // Screen bounds
```

#### **Dynamic Height**
```rust
// Confirm popup
let popup_height = (wrapped_lines.len() as u16 + 7).min(area.height - 4);
// Breakdown: 2 borders + 2 padding + 1 top space + content + 1 spacing + 1 buttons

// Message popup  
let popup_height = (wrapped_lines.len() as u16 + 7).min(area.height - 4);
// Breakdown: 2 borders + 2 padding + 1 top space + content + 1 spacing + 1 help text
```

#### **File Browser**
- **Width**: 70% of screen
- **Height**: 88% of screen (slightly shorter for top/bottom padding)
- **Alignment**: Centered using `centered_rect(70, 88, area)`

#### **Validation Report Panel**
- **Border**: `BorderType::Double`
- **Modal**: Other UI dimmed via `app.is_modal_visible()`
- **Height**: ~89% of screen
- **Padding**: 1 column between text and side borders
- **Close**: Press `Enter` to close; no dismiss timer

---

## List Rendering

### Multi-line List Items
```rust
let items: Vec<ListItem> = data.iter().map(|item| {
    let line1 = format!("Main content");
    let line2 = format!("   Secondary info");
    
    ListItem::new(vec![
        Line::from(line1),
        Line::from(Span::styled(line2, Style::default().fg(hex_color(0x888888)))),
    ]).style(Style::default().fg(text_color))
}).collect();
```

### Status Icons
- **Active/Enabled**: `✓` (checkmark)
- **Inactive/Disabled**: `○` (empty circle)
- **Directory**: `📁` (folder emoji)
- **File**: `📄` (document emoji)
- **Parent Dir**: `↑` (up arrow)

### Empty States
```rust
vec![ListItem::new(" No items configured")
    .style(Style::default().fg(Color::DarkGray))]
```

---

## Scrollbar Styling

### When to Show
```rust
if entries.len() > visible_height {
    // Show scrollbar
}
```

### Scrollbar Rendering
```rust
let scrollbar_height = list_area.height as usize;
let total_items = entries.len();
let scrollbar_position = (scroll_offset * scrollbar_height) / total_items;
let scrollbar_size = (scrollbar_height * scrollbar_height) / total_items.max(1);
let scrollbar_size = scrollbar_size.max(1);

for i in 0..scrollbar_height {
    let is_scrollbar = i >= scrollbar_position && i < (scrollbar_position + scrollbar_size);
    let symbol = if is_scrollbar { "█" } else { "│" };
    let color = if is_scrollbar { Color::Cyan } else { Color::DarkGray };
    
    // Render at right edge of list area
}
```

### Scroll Behavior
```rust
fn adjust_scroll_to_selection(&mut self) {
    // Scroll up if selection is above visible area
    if self.selected_index < self.scroll_offset {
        self.scroll_offset = self.selected_index;
    }
    // Scroll down if selection is below visible area
    else if self.selected_index >= self.scroll_offset + self.visible_height {
        self.scroll_offset = self.selected_index.saturating_sub(self.visible_height - 1);
    }
}
```

---

## Status & Message Styling

### Title Bar
```rust
let title_text = format!(
    " Detour  |  Profile: {}  |  {} active  |  Status: {} ",
    profile, active_count, status_icon
);

let title = Paragraph::new(title_text)
    .alignment(Alignment::Center)
    .style(Style::default()
        .fg(if modal_visible { hex_color(0x444444) } else { hex_color(0xBBBBBB) })
        .add_modifier(Modifier::BOLD));
```

### Confirm Popup Buttons
```rust
// Yes button (selected)
Style::default()
    .fg(Color::Green)
    .bg(hex_color(0x0F1F0F))  // Very subtle green background

// Yes button (unselected)
Style::default().fg(hex_color(0x666666))  // Grey, no background

// No button (selected)
Style::default()
    .fg(hex_color(0xFF4444))  // Brighter red
    .bg(hex_color(0x1F0F0F))  // Very subtle red background

// No button (unselected)
Style::default().fg(hex_color(0x666666))  // Grey, no background
```

**Button Layout:**
```
    [ Yes ]    [ No ]
```
- No bold text
- Color + subtle background indicates selection
- Grey text when not selected
- Minimal padding between buttons

### Bottom Status Line
```rust
// Success message
Span::styled(
    format!(" ✓ {} ", msg),
    Style::default().fg(Color::Green).add_modifier(Modifier::BOLD)
)

// Error message
Span::styled(
    format!(" ✗ {} ", msg),
    Style::default().fg(Color::Red).add_modifier(Modifier::BOLD)
)
```

### Help Text
```rust
Line::from(vec![
    Span::styled("[Key] Action  ", Style::default().fg(Color::Gray)),
    Span::styled("[Key] Action  ", Style::default().fg(Color::Gray)),
    Span::styled("[Key] Action", Style::default().fg(Color::Gray)),
])
```

### Dynamic Description Line
```rust
let description = get_current_description();
let desc_color = if modal_visible {
    hex_color(0x333333)  // Dimmed when modal visible
} else {
    Color::White
};
```

---

## Toast Notifications

### Behavior
- Non-critical success/info use toasts (errors are popups)
- Auto-dismiss after ~2.5 seconds
- Stack at bottom-right with no vertical gaps
- Width matches the longest visible toast; others are left-padded to align
- Minimum of two spaces before and after each message
- Clear the toast area before rendering to prevent color bleed

### Positioning
- Bottom-right of the status region, slightly inset from the right edge
- Stacked upward; newest at the bottom

### Styling
- Background: `0x0A0A0A`
- Text: green for success; cyan for info
- No borders; background-only subtle box

---

## Navigation & Focus Behavior

### Arrow Key Navigation (Columns 1 & 2)
- `↑/↓` or `k/j`: **Preview** content in Column 3 (no focus change)
- `Enter` or `→` or `l`: **Execute** action and move focus to Column 3
- `←` or `h`: Move focus back to previous column

### Arrow Key Navigation (Column 3 - Lists)
- `↑/↓` or `k/j`: Navigate list items
- `Space`: Toggle active state (mount/unmount detours)
- `←` or `h`: Return focus to Column 2

### Arrow Key Navigation (Column 3 - Forms)
- `↑/↓`: Navigate between form fields
- `←/→`: Move cursor within active field
- `Home/End`: Jump to start/end of field
- `Tab`: Path completion (for path fields) or next field
- `Enter`: Submit form
- `Esc`: Cancel and return to Column 2

### File Browser Navigation
- `↑/↓` or `k/j`: Navigate files/folders
- `Enter`: Select file or enter directory
- `→`: Enter selected directory
- `←`: Go to parent directory (maintains selection context)
- `Esc`: Cancel and close browser
- **Mouse Wheel**: Scroll up/down through list

---

## Keyboard Shortcuts

### Global
- `q` or `Q` or `Esc`: Quit application
- `h/j/k/l`: Vim-style navigation
- `↑/↓/←/→`: Arrow key navigation

### Context-Specific (Detours List)
- `Space`: Toggle detour active state (mount/unmount)
- `e`: Edit selected detour
- `Delete`: Delete selected detour (with confirmation)
- `a`: Quick add detour (jump to add view)
- `d`: Show diff between original and custom files
- `v`: Validate only the selected detour (Column 3 must be focused)

### Context-Specific (Forms - Add/Edit Detour)
- `Ctrl+F`: Open file browser
- `Ctrl+V`: Paste from clipboard
- `Tab`: Path completion / Next field
- `Enter`: Save detour
- `Esc`: Cancel and return to Column 2
- `↑/↓`: Navigate between form fields
- `←/→`: Move cursor within field
- `Home/End`: Jump to start/end of field

---

## Minimum Size & Responsive Behavior

### Minimum Terminal Size
- **Width**: 120 columns
- **Height**: 16 rows

### Below Minimum
Display simplified UI with message:
```rust
if area.width < 120 || area.height < 16 {
    draw_minimal_ui(f, app);
    return;
}
```

### Dynamic Column Widths
```rust
let col1_width = calculate_view_width(app);
let col2_width = calculate_action_width(app);
let col3_width = area.width.saturating_sub(col1_x + col2_width + 2);
```

---

## Layout Structure

### Screen Division
```
┌─────────────────────────────────────────────────────────┐
│                    Title Bar (3 lines)                  │
├──────────┬──────────────┬───────────────────────────────┤
│          │              │                               │
│  Views   │   Actions    │         Content               │
│ (Col 1)  │   (Col 2)    │         (Col 3)               │
│          │              │                               │
│          │              │                               │
├──────────┴──────────────┴───────────────────────────────┤
│              Bottom Status Area (5 lines)               │
│  [Status Message or Error]                              │
│  [Context Help]                                         │
│  ─────────────────────────────────────────              │
│  [Dynamic Description]                                  │
│  [Reserved]                                             │
└─────────────────────────────────────────────────────────┘
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

---

## Best Practices

### 1. Consistent State Checks
Always check focus and modal state in this order:
```rust
let modal_visible = app.is_modal_visible();
let is_active = app.active_column == ActiveColumn::Content && !modal_visible;
```

### 2. Use Helper Functions
Prefer helpers over inline styling:
- ✅ `get_selection_style(is_active)`
- ✅ `accent_color()`
- ✅ `bold_accent_color()`
- ❌ `Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD)`

### 3. Dimming Hierarchy
1. No overlay; dimming is conditional per widget using `app.is_modal_visible()`
2. Modal/report renders at full intensity on top

### 4. Cursor Visibility
Only show cursor when:
- Panel is focused (`is_active`)
- Field is active (`active_field == current_field`)
- Use `█` character inserted at `cursor_pos`

### 5. Empty State Handling
Always provide helpful empty states:
```rust
let items = if data.is_empty() {
    vec![ListItem::new(" No items configured")
        .style(Style::default().fg(Color::DarkGray))]
} else {
    // ... render actual items
};
```

### 6. Scroll Management
Update visible height on every render:
```rust
let visible_height = inner_area.height.saturating_sub(2) as usize;
self.visible_height = visible_height;
```

### 7. Selection Persistence
When navigating to parent directory, maintain context:
```rust
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

---

## Testing Checklist

When implementing new UI components, verify:

- [ ] Focused state (white borders, cyan highlights)
- [ ] Unfocused state (grey borders, grey text)
- [ ] Modal dimmed state (all elements darkened)
- [ ] Cursor visibility (only when appropriate)
- [ ] Placeholder styling (dark grey when empty)
- [ ] Selection highlighting (consistent with other columns)
- [ ] Border types (thick when focused, plain otherwise)
- [ ] Arrow indicators (proper spacing and padding)
- [ ] Scrollbar (visible when needed, scrolls correctly)
- [ ] Empty states (helpful messages)
- [ ] Minimum size handling (graceful degradation)
- [ ] Keyboard navigation (intuitive and consistent)

---

## Detour Management Features

### Edit Detour (`e` key)
- Opens edit form with current values pre-populated
- Same form as "Add" but with "Edit Detour" title
- Tracked via `editing_index: Option<usize>` in `AddDetourForm`
- Updates existing entry in config instead of adding new

### Delete Detour (`Delete` key)
```rust
// Show confirmation popup
self.popup = Some(Popup::Confirm {
    title: "Confirm Delete".to_string(),
    message: format!("Delete this detour?\n\n{}\n→ {}", original, custom),
    selected: 1, // Default to "No" for safety
});
```
- Requires confirmation (defaults to "No")
- Removes from config and reloads
- Adjusts selection if last item deleted

### Toggle Detour (`Space` key)
- Activates: Runs `sudo mount --bind <custom> <original>`
- Deactivates: Runs `sudo umount <original>`
- Updates `enabled` field in config
- Shows success/error popup
- Real-time bind mount management

### Validate
- Column 2 "Validate": Validates ALL detours (Detours view)
- Column 3 `v`: Validates ONLY the selected detour (requires Column 3 focus)
- Validation report appears as a modal-style panel with double border and requires `Enter` to close

---

## Version History

- **v1.2** (2025-10-30): Validate UX and actions cleanup, modal dimming, toasts
  - Removed `Backup` and `Restore` from Detours actions
  - Removed arrow indicator from `Validate` in Column 2
  - Column 2 `Validate` validates all detours; `v` validates one (Column 3)
  - Validation report uses double border, dims background, adds inner padding
  - Strengthened selection dimming in Columns 1/2 when modal visible
  - Toasts: bottom-right stack, auto-dismiss, consistent width and padding, Clear to avoid bleed

- **v1.1** (2025-10-30): Updated with popup refinements and detour management
  - Content-based popup sizing (not fixed percentages)
  - Subtle button backgrounds (selected only)
  - Brighter red for "No" button (`#FF4444`)
  - No bold text on buttons
  - Compact popup heights
  - Edit and delete functionality
  - Direct mount/unmount operations
- **v1.0** (2025-10-29): Initial formatting guide based on Detour TUI implementation
  - Established color palette
  - Defined universal styling helpers
  - Documented column layout and navigation
  - Specified form input styling
  - Modal and popup behavior
  - Complete keyboard shortcuts reference


