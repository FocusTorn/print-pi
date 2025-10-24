use crate::app::{App, ActiveColumn, ChangeType, ViewMode};
use ratatui::{ //>
    layout::{Alignment, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, Paragraph, BorderType},
    Frame,
}; //<

fn hex_color(hex: u32) -> Color { //>
    Color::Rgb(
        ((hex >> 16) & 0xFF) as u8,
        ((hex >> 8) & 0xFF) as u8,
        (hex & 0xFF) as u8,
    )
} //<

pub fn ui(f: &mut Frame, app: &mut App) { //>
    let area = f.area();
    
    f.render_widget(Paragraph::new("").style(Style::default().bg(hex_color(0x0A0A0A))), area);
    
    if area.width < 80 || area.height < 10 {
        draw_minimal_ui(f, app);
        return;
    }
    
    // Title bar at top
    let title_area = Rect {
        x: area.x,
        y: area.y,
        width: area.width,
        height: 3,
    };
    draw_title(f, title_area, app);
    
    // Main content area (below title, above status)
    let content_y = title_area.y + title_area.height;
    let content_height = area.height.saturating_sub(title_area.height + 5);
    
    // Calculate Column 1 width based on primary command names
    let max_view_width = app.primary_commands.iter()
        .map(|cmd| cmd.name.len())
        .max()
        .unwrap_or(10);
    let col1_width = (max_view_width + 4) as u16; // +1 left space, +1 right space, +2 borders
    
    // Calculate Column 2 width based on CURRENT view's visible commands only
    let current_commands = app.get_current_commands();
    let max_command_width = current_commands.iter()
        .map(|cmd| cmd.name.len())
        .max()
        .unwrap_or(15);
    let col2_width = (max_command_width + 6) as u16; // +1 left, +1 right, +2 borders, +2 for thumper space
    
    // Column 1: View Selector
    let col1_area = Rect {
        x: area.x + 1,
        y: content_y,
        width: col1_width,
        height: content_height,
    };
    draw_view_selector(f, col1_area, app);
    
    // Column 2: Commands
    let col2_x = col1_area.x + col1_width + 1;
    let col2_area = Rect {
        x: col2_x,
        y: content_y,
        width: col2_width,
        height: content_height,
    };
    draw_commands_column(f, col2_area, app);
    
    // Select indicator or Throbber (inside Column 2, to the right of commands)
    let commands = app.get_current_commands();
    for (idx, cmd) in commands.iter().enumerate() {
        let indicator_x = col2_area.x + col2_area.width - 3; // Inside border, in the +2 space
        let indicator_y = col2_area.y + (idx as u16) + 1;
        
        // Throbber takes priority over select indicator
        if app.creating_baseline && idx == app.selected_command {
            let throbber_char = app.get_throbber();
            let thumper = Paragraph::new(throbber_char)
                .style(Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD));
            f.render_widget(thumper, Rect {
                x: indicator_x,
                y: indicator_y,
                width: 2,
                height: 1,
            });
        } else if cmd.select.is_some() {
            // Show select indicator using unified config - always visible
            let popup_visible = app.popup.is_some();
            let is_active = app.active_column == ActiveColumn::Commands;
            let is_content_active = app.active_column == ActiveColumn::Content;
            let is_selected = idx == app.selected_command;
            
            // Color follows the styling of the command line
            let color = if popup_visible {
                if is_selected {
                    hex_color(0x555555) // Dimmed when popup is visible and selected
                } else {
                    hex_color(0x444444) // Even more dimmed when not selected
                }
            } else if is_selected && (is_active || is_content_active) {
                Color::White // Bright white when selected and column is active
            } else if is_selected {
                hex_color(0x666666) // Grey when selected but column not active
            } else if is_active || is_content_active {
                hex_color(0x777777) // Light grey when not selected but in active column
            } else {
                hex_color(0x444444) // Dark grey when not selected and not active
            };
            
            let indicator = Paragraph::new(&*app.config.secondary_commands_panel.select_indicator)
                .style(Style::default().fg(color));
            f.render_widget(indicator, Rect {
                x: indicator_x,
                y: indicator_y,
                width: 2,
                height: 1,
            });
        }
    }
    
    // Column 3: Content (files or baselines)
    let col3_x = col2_area.x + col2_area.width + 1;
    let col3_width = area.width.saturating_sub(col3_x + 1);
    let col3_area = Rect {
        x: col3_x,
        y: content_y,
        width: col3_width,
        height: content_height,
    };
    draw_content_column(f, col3_area, app);
    
    // Bottom status area
    let status_area = Rect {
        x: area.x,
        y: area.y + area.height.saturating_sub(5),
        width: area.width,
        height: 5,
    };
    draw_bottom_status(f, status_area, app, col3_x);
    
    // Draw popup last (overlays everything)
    if app.popup.is_some() {
        draw_popup(f, area, app);
    }
} //<


fn draw_title(f: &mut Frame, area: Rect, app: &mut App) { //> //>
    let popup_visible = app.popup.is_some();
    let title_text = &app.config.title_bar.display;
    
    let border_color = if popup_visible { hex_color(0x222222) } else { hex_color(0x666666) };
    let text_color = if popup_visible { hex_color(0x444444) } else { hex_color(0xBBBBBB) };
    
    let title_block = Block::default()
    .borders(Borders::ALL)
    .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(border_color));
    
    let title = Paragraph::new(title_text.as_str())
        .alignment(Alignment::Center)
        .style(Style::default().fg(text_color).add_modifier(Modifier::BOLD))
        .block(title_block);
    
    f.render_widget(title, Rect {
        x: area.x,
        y: area.y,
        width: area.width,
        height: 3,
    });
    
    
    
    
    
    
    
    

    // // Line 1: Navigation hints
    // let nav_text = &app.config.help_line.text;
    // let nav_paragraph = Paragraph::new(nav_text.as_str())
    //     .style(Style::default().fg(Color::DarkGray));
    // f.render_widget(nav_paragraph, Rect {
    //     x: area.x,
    //     y: area.y+1,
    //     width: area.width,
    //     height: 1,
    // });
    
    // // Line 3: Horizontal divider
    // let divider_line = "─".repeat(area.width as usize);
    // let divider_paragraph = Paragraph::new(divider_line)
    //     .style(Style::default().fg(Color::White));
    // f.render_widget(divider_paragraph, Rect {
    //     x: area.x,
    //     y: area.y + 2,
    //     width: area.width,
    //     height: 1,
    // });
    
    // // Line 4: Dynamic description
    // let description = app.get_current_action_description();
    // let desc_line = format!(" {:<width$} ", description, width = area.width as usize - 2);
    // let desc_paragraph = Paragraph::new(desc_line)
    //     .style(Style::default().fg(Color::White));
    // f.render_widget(desc_paragraph, Rect {
    //     x: area.x,
    //     y: area.y + 3,
    //     width: area.width,
    //     height: 1,
    // });
} //< //<

fn get_panel_help_line(app: &App) -> String { //>
    // Return panel-specific help line based on active view and column
    if app.view_mode == ViewMode::Baseline && app.active_column == ActiveColumn::Content {
        // Show baseline panel help line
        let help_line = &app.config.baseline_panel.help_line;
        let bindings_text: Vec<String> = help_line.bindings.iter()
            .map(|b| b.name.clone())
            .collect();
        
        format!("{}{}{}", 
            help_line.pre_text,
            bindings_text.join(" "),
            help_line.post_text
        )
    } else {
        // No panel-specific help line for other views/panels yet
        String::new()
    }
} //<

fn draw_bottom_status(f: &mut Frame, area: Rect, app: &mut App, col3_x: u16) { //>
    let popup_visible = app.popup.is_some();
    
    // Line 1: Navigation hints
    let nav_text = &app.config.help_line.text;
    let nav_color = if popup_visible { hex_color(0x333333) } else { Color::DarkGray };
    let nav_paragraph = Paragraph::new(nav_text.as_str())
        .style(Style::default().fg(nav_color));
    f.render_widget(nav_paragraph, Rect {
        x: area.x,
        y: area.y+1,
        width: area.width,
        height: 1,
    });
    
    // Line 3: Horizontal divider
    let divider_line = "─".repeat(area.width as usize);
    let divider_color = if popup_visible { hex_color(0x222222) } else { Color::White };
    let divider_paragraph = Paragraph::new(divider_line)
        .style(Style::default().fg(divider_color));
    f.render_widget(divider_paragraph, Rect {
        x: area.x,
        y: area.y + 2,
        width: area.width,
        height: 1,
    });
    
    // Line 0: Panel-specific help line (left-aligned to col3) + Baseline status (right)
    // Panel help line (grey, aligned to column 3 left border)
    let panel_help_text = get_panel_help_line(app);
    let panel_help_color = if popup_visible { hex_color(0x333333) } else { hex_color(0x666666) }; // Grey
    let panel_help_paragraph = Paragraph::new(panel_help_text)
        .style(Style::default().fg(panel_help_color));
    f.render_widget(panel_help_paragraph, Rect {
        x: col3_x,
        y: area.y,
        width: area.width.saturating_sub(col3_x - area.x), // From col3 to end
        height: 1,
    });
    
    // Baseline status (right-aligned)
    let baseline_info = format!("Baseline: {} ", app.baseline_status); // Space at end for padding
    let baseline_color = if popup_visible { hex_color(0x444444) } else { Color::White };
    let baseline_paragraph = Paragraph::new(baseline_info)
        .alignment(Alignment::Right)
        .style(Style::default().fg(baseline_color));
    f.render_widget(baseline_paragraph, Rect {
        x: area.x,
        y: area.y,
        width: area.width,
        height: 1,
    });
    
    // Line 4: Dynamic description (removed progress bar - now shown in progress panel)
    let description = app.get_current_command_description();
    let desc_line = format!(" {:<width$} ", description, width = area.width as usize - 2);
    let desc_color = if popup_visible { hex_color(0x444444) } else { Color::White };
    let desc_paragraph = Paragraph::new(desc_line)
        .style(Style::default().fg(desc_color));
    f.render_widget(desc_paragraph, Rect {
        x: area.x,
        y: area.y + 3,
        width: area.width,
        height: 1,
    });
} //<

fn draw_minimal_ui(f: &mut Frame, _app: &mut App) { //>
    let area = f.area();
    
    // Clear the screen
    f.render_widget(
        Paragraph::new("").style(Style::default().bg(Color::Black)),
        area,
    );
    
    // Show resize message
    let message = "Terminal too small! Please resize to at least 80x20";
    let message_para = Paragraph::new(message)
        .alignment(Alignment::Center)
        .style(Style::default().fg(Color::Red).add_modifier(Modifier::BOLD));
    
    f.render_widget(message_para, Rect {
        x: area.x,
        y: area.y + area.height / 2 - 1,
        width: area.width,
        height: 1,
    });
    
    // Show current size
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
    
    // Show quit instruction
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
} //<

fn draw_view_selector(f: &mut Frame, area: Rect, app: &mut App) { //>
    let popup_visible = app.popup.is_some();
    let is_active = app.active_column == ActiveColumn::ViewSelector && !popup_visible;
    
    let border_style = if is_active {
        Style::default().fg(Color::White)
    } else if popup_visible {
        Style::default().fg(hex_color(0x222222))
    } else {
        Style::default().fg(hex_color(0x333333))
    };
    let border_type = if is_active { BorderType::Thick } else { BorderType::Plain };
    let text_color = if is_active {
        hex_color(0xFFFFFF)
    } else if popup_visible {
        hex_color(0x444444) // Darker when popup shown
    } else {
        hex_color(0x777777)
    };
    
    // Calculate max width for padding
    let max_width = app.primary_commands.iter().map(|cmd| cmd.name.len()).max().unwrap_or(10);
    
    let items: Vec<ListItem> = app.primary_commands.iter().map(|cmd| {
        // One space before, pad to max width, one space after
        let padding = max_width - cmd.name.len();
        let padded = format!(" {}{} ", cmd.name, " ".repeat(padding));
        ListItem::new(padded).style(Style::default().fg(text_color))
    }).collect();
    
    // Always show selection in Column 1
    let mut state = app.view_state.clone();
    
    let highlight_style = if popup_visible {
        // Dimmed when popup is visible
        Style::default()
            .bg(hex_color(0x0F0F0F))
            .fg(hex_color(0x555555))
    } else {
        Style::default()
            .bg(hex_color(0x2A2A2A))
            .fg(hex_color(0xFFFFFF))
            .add_modifier(Modifier::BOLD)
    };
    
    let list = List::new(items)
        .block(Block::default()
            .borders(Borders::ALL)
            .border_type(border_type)
            .border_style(border_style))
        .highlight_style(highlight_style);
    
    f.render_stateful_widget(list, area, &mut state);
} //<

fn draw_commands_column(f: &mut Frame, area: Rect, app: &mut App) { //>
    let commands = app.get_current_commands();
    
    let popup_visible = app.popup.is_some();
    let is_active = app.active_column == ActiveColumn::Commands && !popup_visible;
    let is_content_active = app.active_column == ActiveColumn::Content && !popup_visible;
    
    let border_style = if is_active {
        Style::default().fg(Color::White)
    } else if popup_visible {
        Style::default().fg(hex_color(0x222222))
    } else {
        Style::default().fg(hex_color(0x333333))
    };
    let border_type = if is_active { BorderType::Thick } else { BorderType::Plain };
    let text_color = if is_active {
        hex_color(0xFFFFFF)
    } else if popup_visible {
        hex_color(0x444444)
    } else {
        hex_color(0x777777)
    };
    
    // Calculate max width for padding
    let max_width = commands.iter().map(|cmd| cmd.name.len()).max().unwrap_or(15);
    
    let items: Vec<ListItem> = commands.iter().map(|cmd| {
        // One space before, pad to max width, one space after
        let padding = max_width - cmd.name.len();
        let padded = format!(" {}{} ", cmd.name, " ".repeat(padding));
        
        // Gray out baseline:generate if no initial baseline exists
        let item_color = if cmd.command == "baseline:generate" && app.initial_baseline_path.is_none() {
            hex_color(0x444444) // Grayed out
        } else {
            text_color
        };
        
        ListItem::new(padded).style(Style::default().fg(item_color))
    }).collect();
    
    // Show/hide selection based on active column
    let mut state = app.command_state.clone();
    let show_highlight = app.active_column != ActiveColumn::ViewSelector;
    
    // Use BOLD highlight when Column 2 OR Column 3 is active
    let highlight_style = if popup_visible {
        // Dimmed highlight when popup is visible
        Style::default()
            .bg(hex_color(0x0F0F0F))
            .fg(hex_color(0x555555))
    } else if is_active || is_content_active {
        Style::default()
            .bg(hex_color(0x2A2A2A))
            .fg(hex_color(0xFFFFFF))
            .add_modifier(Modifier::BOLD)
    } else if show_highlight {
        // Subtle highlight when should be visible but not active
        Style::default()
            .bg(hex_color(0x1A1A1A))
            .fg(hex_color(0xAAAAAA))
    } else {
        // No highlight
        Style::default()
    };
    
    if !show_highlight {
        state.select(None);
    }
    
    let list = List::new(items)
        .block(Block::default()
            .borders(Borders::ALL)
            .border_type(border_type)
            .border_style(border_style))
        .highlight_style(highlight_style);
    
    f.render_stateful_widget(list, area, &mut state);
} //<

fn draw_content_column(f: &mut Frame, area: Rect, app: &mut App) { //>
    match app.view_mode {
        ViewMode::Changes => draw_file_changes(f, area, app),
        ViewMode::Baseline => draw_baseline_list(f, area, app),
    }
} //<

fn draw_file_changes(f: &mut Frame, area: Rect, app: &mut App) { //>
    let popup_visible = app.popup.is_some();
    let is_active = app.active_column == ActiveColumn::Content && !popup_visible;
    
    // Clear the entire area first to prevent leftover text
    f.render_widget(
        Paragraph::new("").style(Style::default().bg(hex_color(0x0A0A0A))),
        area
    );
    
    let border_style = if is_active {
        Style::default().fg(Color::White)
    } else if popup_visible {
        Style::default().fg(hex_color(0x222222))
    } else {
        Style::default().fg(hex_color(0x333333))
    };
    let border_type = if is_active { BorderType::Thick } else { BorderType::Plain };
    let text_color = if is_active {
        hex_color(0xFFFFFF)
    } else if popup_visible {
        hex_color(0x444444)
    } else {
        hex_color(0x777777)
    };
    
    // Draw the full border first
    let main_block = Block::default()
        .borders(Borders::ALL)
        .border_type(border_type)
        .border_style(border_style);
    
    f.render_widget(main_block, area);
    
    // Layer the tab line OVER the top border
    draw_file_tabs_border(f, area, app);
    
    // Layer the toggles OVER the bottom border
    draw_file_toggles_border(f, area, app);
    
    // Content area (inside the border)
    let content_area = Rect {
        x: area.x + 1,
        y: area.y + 1,
        width: area.width.saturating_sub(2),
        height: area.height.saturating_sub(2),
    };
    
    let items: Vec<ListItem> = if app.file_changes.is_empty() {
        vec![ListItem::new(" No changes detected").style(Style::default().fg(Color::DarkGray))]
    } else {
        app.file_changes.iter().map(|change| {
            let icon = match change.change_type {
                ChangeType::Modified => "M",
                ChangeType::New => "N",
            };
            ListItem::new(format!("[{}] {}", icon, change.path))
                .style(Style::default().fg(text_color))
        }).collect()
    };
    
    // Always show selection, but style differently based on active state
    let highlight_style = if popup_visible {
        // Dimmed when popup is visible
        Style::default()
            .bg(hex_color(0x0F0F0F))
            .fg(hex_color(0x555555))
    } else if is_active {
        Style::default()
            .bg(hex_color(0x2A2A2A))
            .fg(hex_color(0xFFFFFF))
            .add_modifier(Modifier::BOLD)
    } else {
        // Subtle highlight when inactive
        Style::default()
            .bg(hex_color(0x1A1A1A))
            .fg(hex_color(0xAAAAAA))
    };
    
    let list = List::new(items)
        .highlight_style(highlight_style);
    
    f.render_stateful_widget(list, content_area, &mut app.file_state);
} //<

fn draw_file_tabs_border(f: &mut Frame, area: Rect, app: &App) { //>
    let popup_visible = app.popup.is_some();
    let is_active = app.active_column == ActiveColumn::Content && !popup_visible;
    let border_color = if is_active {
        Color::White
    } else if popup_visible {
        hex_color(0x222222)
    } else {
        hex_color(0x333333)
    };
    
    let active_tab = app.active_file_view_index;
    
    // Build the top border line: ┌── tab1 ─ tab2 ─ tab3 ───────
    let mut border_line = String::from("┌──");
    
    // Add view type tabs
    for (idx, view) in app.config.files_panel.view_type.iter().enumerate() {
        border_line.push_str(&format!(" {} ", view.name));
        
        if idx < app.config.files_panel.view_type.len() - 1 {
            border_line.push_str("─");
        }
    }
    let _ = active_tab; // For future active tab highlighting
    
    // Fill rest with dashes
    let current_len = border_line.len();
    let total_width = area.width as usize;
    if current_len < total_width {
        let remaining = total_width - current_len;
        border_line.push_str(&format!(" {}", "─".repeat(remaining.saturating_sub(1))));
    }
    
    let top_border = Paragraph::new(border_line)
        .style(Style::default().fg(border_color));
    
    f.render_widget(top_border, Rect {
        x: area.x,
        y: area.y,
        width: area.width,
        height: 1,
    });
} //<

fn draw_file_toggles_border(f: &mut Frame, area: Rect, app: &App) { //>
    let is_focused = app.active_column == ActiveColumn::Content;
    let border_color = if is_focused { Color::White } else { hex_color(0x333333) };
    
    let mut spans = vec![Span::styled("└──", Style::default().fg(border_color))];
    
    // Add each toggle with color based on on/off and focus
    for (idx, toggle) in app.config.files_panel.toggles.iter().enumerate() {
        let is_on = app.active_toggles.get(idx).copied().unwrap_or(false);
        
        let toggle_style = match (is_on, is_focused) {
            (true, true) => Style::default().fg(Color::Green).add_modifier(Modifier::BOLD),
            (true, false) => Style::default().fg(hex_color(0x006600)), // Dark green
            (false, true) => Style::default().fg(Color::Red).add_modifier(Modifier::BOLD),
            (false, false) => Style::default().fg(hex_color(0x660000)), // Dark red
        };
        
        spans.push(Span::styled(format!("[ {} ]", toggle.name), toggle_style));
    }
    
    // Fill remaining with border color dashes
    let text_len: usize = 3 + app.config.files_panel.toggles.iter()
        .map(|t| t.name.len() + 4) // "[ name ]"
        .sum::<usize>();
    let total_width = area.width as usize;
    if text_len < total_width {
        let remaining = total_width - text_len;
        spans.push(Span::styled("─".repeat(remaining), Style::default().fg(border_color)));
    }
    
    let bottom_border = Paragraph::new(Line::from(spans));
    
    f.render_widget(bottom_border, Rect {
        x: area.x,
        y: area.y + area.height - 1,
        width: area.width,
        height: 1,
    });
} //<

fn draw_baseline_list(f: &mut Frame, area: Rect, app: &mut App) { //>
    let popup_visible = app.popup.is_some();
    let is_active = app.active_column == ActiveColumn::Content && !popup_visible;
    
    // Clear the entire area first to prevent leftover text
    f.render_widget(
        Paragraph::new("").style(Style::default().bg(hex_color(0x0A0A0A))),
        area
    );
    
    // If creating baseline, show split progress panels instead of baseline list
    if app.creating_baseline {
        // Split area vertically: top 30% for workers, bottom 70% for completed (scrollable)
        let worker_height = (area.height as f32 * 0.3).max(8.0) as u16; // At least 8 lines for workers
        
        let worker_area = Rect {
            x: area.x,
            y: area.y,
            width: area.width,
            height: worker_height,
        };
        
        let completed_area = Rect {
            x: area.x,
            y: area.y + worker_height,
            width: area.width,
            height: area.height.saturating_sub(worker_height),
        };
        
        draw_worker_panel(f, worker_area, app);
        draw_completed_panel(f, completed_area, app);
        return;
    }
    
    let border_style = if is_active {
        Style::default().fg(Color::White)
    } else if popup_visible {
        Style::default().fg(hex_color(0x222222))
    } else {
        Style::default().fg(hex_color(0x333333))
    };
    let border_type = if is_active { BorderType::Thick } else { BorderType::Plain };
    let text_color = if is_active {
        hex_color(0xFFFFFF)
    } else if popup_visible {
        hex_color(0x444444)
    } else {
        hex_color(0x777777)
    };
    
    // Build list items - delta baselines first, then Initial Baseline at bottom (chronological order)
    let mut items: Vec<ListItem> = Vec::new();
    
    // Add delta baselines (newest first)
    for (idx, metadata) in app.baseline_versions.iter().enumerate() {
        // Active baseline indicator (→)
        let indicator = if idx == app.active_baseline { " → " } else { "   " };
        let count_label = if metadata.is_delta {
            format!(" ({} changes)", metadata.file_count)
        } else {
            format!(" ({} files)", metadata.file_count)
        };
        items.push(ListItem::new(format!("{}{}{}", indicator, metadata.version, count_label))
            .style(Style::default().fg(text_color)));
    }
    
    // Always show "Initial Baseline" at bottom (oldest = last index)
    let initial_color = if popup_visible {
        hex_color(0x555555)
    } else {
        hex_color(0x00AAAA) // Cyan to differentiate
    };
    
    let initial_index = app.baseline_versions.len(); // Initial is at this index
    let initial_indicator = if initial_index == app.active_baseline { " → " } else { "   " };
    
    let initial_text = match (&app.initial_baseline_path, &app.initial_baseline_remap_to, &app.initial_baseline_file_count) {
        (Some(scan_path), Some(remap_to), Some(count)) if scan_path != remap_to => {
            format!("{}Initial Baseline: {} → {} ({} files)", initial_indicator, scan_path, remap_to, count)
        }
        (Some(path), _, Some(count)) => {
            format!("{}Initial Baseline: {} ({} files)", initial_indicator, path, count)
        }
        (Some(scan_path), Some(remap_to), None) if scan_path != remap_to => {
            format!("{}Initial Baseline: {} → {}", initial_indicator, scan_path, remap_to)
        }
        (Some(path), _, None) => {
            format!("{}Initial Baseline: {}", initial_indicator, path)
        }
        _ => {
            format!("{}Initial Baseline (not created)", initial_indicator)
        }
    };
    
    items.push(ListItem::new(initial_text)
        .style(Style::default().fg(initial_color).add_modifier(Modifier::DIM)));
    
    // Always show selection, but style differently based on active state
    let highlight_style = if popup_visible {
        // Dimmed when popup is visible
        Style::default()
            .bg(hex_color(0x0F0F0F))
            .fg(hex_color(0x555555))
    } else if is_active {
        Style::default()
            .bg(hex_color(0x2A2A2A))
            .fg(hex_color(0xFFFFFF))
            .add_modifier(Modifier::BOLD)
    } else {
        // Subtle highlight when inactive
        Style::default()
            .bg(hex_color(0x1A1A1A))
            .fg(hex_color(0xAAAAAA))
    };
    
    // Title with Initial baseline path (show remapping if different)
    let title = match (&app.initial_baseline_path, &app.initial_baseline_remap_to) {
        (Some(scan_path), Some(remap_to)) if scan_path != remap_to => {
            format!(" Baselines (Initial: {} → {}) ", scan_path, remap_to)
        }
        (Some(path), _) => {
            format!(" Baselines (Initial: {}) ", path)
        }
        _ => {
            " Baselines (No Initial) ".to_string()
        }
    };
    
    let list = List::new(items)
        .block(Block::default()
            .title(title)
            .borders(Borders::ALL)
            .border_type(border_type)
            .border_style(border_style))
        .highlight_style(highlight_style);
    
    f.render_stateful_widget(list, area, &mut app.baseline_list_state);
} //<

fn draw_popup(f: &mut Frame, area: Rect, app: &App) { //>
    use crate::app::PopupType;
    
    if let Some(popup) = &app.popup {
        match &popup.popup_type {
            PopupType::ConfirmDeleteBaseline { version, selected_option } => {
                let lines = vec![
                    format!("Delete baseline: {}?", version),
                ];
                draw_confirmation_popup(f, area, &lines, *selected_option);
            }
            PopupType::ConfirmOverwriteInitial { selected_option, from_remove, has_deltas } => {
                let lines = if *from_remove {
                    // User tried to remove Initial Baseline
                    if *has_deltas {
                        vec![
                            "Cannot Delete Initial Baseline".to_string(),
                            "".to_string(),
                            "Would you like to overwrite it instead?".to_string(),
                            "".to_string(),
                            "WARNING: This will delete ALL generated baselines!".to_string(),
                        ]
                    } else {
                        vec![
                            "Cannot Delete Initial Baseline".to_string(),
                            "".to_string(),
                            "Would you like to overwrite it instead?".to_string(),
                        ]
                    }
                } else {
                    // User clicked "Overwrite Initial" command
                    if *has_deltas {
                        vec![
                            "Overwrite Initial Baseline?".to_string(),
                            "".to_string(),
                            "WARNING: This will delete ALL generated baselines!".to_string(),
                        ]
                    } else {
                        vec![
                            "Overwrite Initial Baseline?".to_string(),
                        ]
                    }
                };
                draw_confirmation_popup(f, area, &lines, *selected_option);
            }
            PopupType::InputDirectory { prompt, input, cursor_pos } => {
                draw_input_popup(f, area, prompt, input, *cursor_pos);
            }
            PopupType::InputRemapPath { prompt, input, cursor_pos, .. } => {
                draw_input_popup(f, area, prompt, input, *cursor_pos);
            }
        }
    }
} //<

fn draw_confirmation_popup(f: &mut Frame, area: Rect, content_lines: &[String], selected_option: usize) { //>
    // Calculate popup dimensions
    let content_width = content_lines.iter()
        .map(|line| line.len())
        .max()
        .unwrap_or(30)
        .max(30); // Minimum width
    
    let popup_width = (content_width + 4) as u16; // +4 for padding and borders
    let popup_height = (content_lines.len() + 5) as u16; // +2 empty lines, +2 borders, +1 for buttons
    
    // Center the popup
    let popup_x = (area.width.saturating_sub(popup_width)) / 2;
    let popup_y = (area.height.saturating_sub(popup_height)) / 2;
    
    let popup_area = Rect {
        x: popup_x,
        y: popup_y,
        width: popup_width,
        height: popup_height,
    };
    
    // Draw semi-transparent background (darken the screen behind popup)
    let bg_block = Block::default()
        .style(Style::default().bg(hex_color(0x000000)));
    f.render_widget(bg_block, area);
    
    // Build popup content with double-line box
    let mut popup_lines = Vec::new();
    
    // Top border
    popup_lines.push(Line::from(Span::styled(
        format!("┏{}┓", "━".repeat(popup_width as usize - 2)),
        Style::default().fg(Color::White)
    )));
    
    // Empty line
    popup_lines.push(Line::from(Span::styled(
        format!("┃{}┃", " ".repeat(popup_width as usize - 2)),
        Style::default().fg(Color::White)
    )));
    
    // Content lines (centered)
    for line in content_lines {
        let padding = (popup_width as usize - 2).saturating_sub(line.len());
        let left_pad = padding / 2;
        let right_pad = padding - left_pad;
        let centered = format!("┃{}{}{}┃", " ".repeat(left_pad), line, " ".repeat(right_pad));
        popup_lines.push(Line::from(Span::styled(centered, Style::default().fg(Color::White))));
    }
    
    // Button line: Yes / No (no background, just white+bold when selected)
    let yes_style = if selected_option == 0 {
        Style::default().fg(Color::White).add_modifier(Modifier::BOLD)
    } else {
        Style::default().fg(hex_color(0x777777))
    };
    
    let no_style = if selected_option == 1 {
        Style::default().fg(Color::White).add_modifier(Modifier::BOLD)
    } else {
        Style::default().fg(hex_color(0x777777))
    };
    
    let yes_text = "Yes";
    let no_text = "No";
    let buttons = format!("{}  {}", yes_text, no_text);
    
    let button_padding = (popup_width as usize - 2).saturating_sub(buttons.len());
    let left_pad = button_padding / 2;
    let right_pad = button_padding - left_pad;
    
    let mut button_spans = vec![Span::styled("┃", Style::default().fg(Color::White))];
    button_spans.push(Span::raw(" ".repeat(left_pad)));
    button_spans.push(Span::styled(yes_text, yes_style));
    button_spans.push(Span::raw("  "));
    button_spans.push(Span::styled(no_text, no_style));
    button_spans.push(Span::raw(" ".repeat(right_pad)));
    button_spans.push(Span::styled("┃", Style::default().fg(Color::White)));
    
    popup_lines.push(Line::from(button_spans));
    
    // Empty line
    popup_lines.push(Line::from(Span::styled(
        format!("┃{}┃", " ".repeat(popup_width as usize - 2)),
        Style::default().fg(Color::White)
    )));
    
    // Bottom border
    popup_lines.push(Line::from(Span::styled(
        format!("┗{}┛", "━".repeat(popup_width as usize - 2)),
        Style::default().fg(Color::White)
    )));
    
    let popup = Paragraph::new(popup_lines)
        .style(Style::default().bg(hex_color(0x0A0A0A)));
    
    f.render_widget(popup, popup_area);
} //<

fn draw_input_popup(f: &mut Frame, area: Rect, prompt: &str, input: &str, cursor_pos: usize) { //>
    let popup_width = 60u16.min(area.width - 4);
    let popup_height = 6u16;  // Fixed: was 7, causing blank line after bottom border
    
    let popup_x = (area.width.saturating_sub(popup_width)) / 2;
    let popup_y = (area.height.saturating_sub(popup_height)) / 2;
    
    let popup_area = Rect {
        x: popup_x,
        y: popup_y,
        width: popup_width,
        height: popup_height,
    };
    
    // Darken background
    let bg_block = Block::default()
        .style(Style::default().bg(hex_color(0x000000)));
    f.render_widget(bg_block, area);
    
    let mut popup_lines = Vec::new();
    
    // Top border
    popup_lines.push(Line::from(Span::styled(
        format!("┏{}┓", "━".repeat(popup_width as usize - 2)),
        Style::default().fg(Color::White)
    )));
    
    // Empty line
    popup_lines.push(Line::from(Span::styled(
        format!("┃{}┃", " ".repeat(popup_width as usize - 2)),
        Style::default().fg(Color::White)
    )));
    
    // Prompt
    let padding = (popup_width as usize - 2).saturating_sub(prompt.len());
    let left_pad = padding / 2;
    let right_pad = padding - left_pad;
    let centered_prompt = format!("┃{}{}{}┃", " ".repeat(left_pad), prompt, " ".repeat(right_pad));
    popup_lines.push(Line::from(Span::styled(centered_prompt, Style::default().fg(Color::White))));
    
    // Input field with cursor
    let input_display = if input.len() > (popup_width as usize - 6) {
        // Truncate if too long
        &input[..popup_width as usize - 6]
    } else {
        input
    };
    
    let mut input_spans = vec![Span::styled("┃ ", Style::default().fg(Color::White))];
    
    // Show text with cursor
    if cursor_pos == 0 {
        input_spans.push(Span::styled("█", Style::default().fg(Color::Yellow)));
        input_spans.push(Span::styled(input_display, Style::default().fg(Color::White)));
    } else if cursor_pos >= input.len() {
        input_spans.push(Span::styled(input_display, Style::default().fg(Color::White)));
        input_spans.push(Span::styled("█", Style::default().fg(Color::Yellow)));
    } else {
        input_spans.push(Span::styled(&input[..cursor_pos], Style::default().fg(Color::White)));
        input_spans.push(Span::styled("█", Style::default().fg(Color::Yellow)));
        input_spans.push(Span::styled(&input[cursor_pos..], Style::default().fg(Color::White)));
    }
    
    // Pad to fill width
    // Total width = "┃ " (2) + input text + cursor (1) + padding + "┃" (1) = popup_width
    let text_len = input.len() + 4; // "┃ " (2) + cursor (1) + "┃" (1)
    if text_len < popup_width as usize {
        let padding = (popup_width as usize) - text_len;
        input_spans.push(Span::raw(" ".repeat(padding)));
    }
    input_spans.push(Span::styled("┃", Style::default().fg(Color::White)));
    
    popup_lines.push(Line::from(input_spans));
    
    // Empty line
    popup_lines.push(Line::from(Span::styled(
        format!("┃{}┃", " ".repeat(popup_width as usize - 2)),
        Style::default().fg(Color::White)
    )));
    
    // Bottom border
    popup_lines.push(Line::from(Span::styled(
        format!("┗{}┛", "━".repeat(popup_width as usize - 2)),
        Style::default().fg(Color::White)
    )));
    
    let popup = Paragraph::new(popup_lines)
        .style(Style::default().bg(hex_color(0x0A0A0A)));
    
    f.render_widget(popup, popup_area);
} //<

fn draw_worker_panel(f: &mut Frame, area: Rect, app: &App) { //>
    let popup_visible = app.popup.is_some();
    
    let border_style = if popup_visible {
        Style::default().fg(hex_color(0x222222))
    } else {
        Style::default().fg(Color::Yellow) // Yellow border during scanning
    };
    let border_type = BorderType::Rounded;
    
    // Title with summary
    let active_files: usize = app.baseline_progress.iter().map(|(_, count, _)| count).sum();
    let completed_files: usize = app.baseline_completed.iter().map(|(_, count)| count).sum();
    let total_files = active_files + completed_files;
    
    let title = if app.creating_initial {
        format!(" Creating Initial | {} files | {} workers active ", total_files, app.baseline_progress.len())
    } else {
        format!(" Generating Delta | {} files | {} workers active ", total_files, app.baseline_progress.len())
    };
    
    let block = Block::default()
        .title(title)
        .borders(Borders::ALL)
        .border_type(border_type)
        .border_style(border_style);
    
    f.render_widget(block, area);
    
    // Content area (inside border)
    let content_area = Rect {
        x: area.x + 1,
        y: area.y + 1,
        width: area.width.saturating_sub(2),
        height: area.height.saturating_sub(2),
    };
    
    let mut lines = Vec::new();
    
    // Show active threads or completion message
    if !app.baseline_progress.is_empty() {
        for (thread_name, file_count, current_path) in &app.baseline_progress {
            let thread_color = if popup_visible { hex_color(0x555555) } else { hex_color(0xAAFFAA) };
            let path_color = if popup_visible { hex_color(0x333333) } else { hex_color(0x888888) };
            
            // Get throbber
            let throbber = app.get_throbber();
            
            // Calculate space for path truncation
            let prefix_len = thread_name.len() + file_count.to_string().len() + 15; // throbber + ": " + " files | "
            let max_path_len = (content_area.width as usize).saturating_sub(prefix_len);
            let display_path = if current_path.len() > max_path_len {
                format!("...{}", &current_path[current_path.len().saturating_sub(max_path_len.saturating_sub(3))..])
            } else {
                current_path.clone()
            };
            
            // All on one line: throbber + thread_name + file_count + path
            lines.push(Line::from(vec![
                Span::styled(format!("{} ", throbber), Style::default().fg(Color::Yellow)),
                Span::styled(
                    format!("{}: ", thread_name),
                    Style::default().fg(thread_color).add_modifier(Modifier::BOLD)
                ),
                Span::styled(
                    format!("{} files", file_count),
                    Style::default().fg(Color::White)
                ),
                Span::styled(
                    format!(" | {}", display_path),
                    Style::default().fg(path_color).add_modifier(Modifier::DIM)
                ),
            ]));
        }
        
        let paragraph = Paragraph::new(lines)
            .alignment(Alignment::Left);
        
        f.render_widget(paragraph, content_area);
    } else if app.creating_baseline {
        // All directories completed, waiting for final results
        let throbber = app.get_throbber();
        let lines = vec![
            Line::from(Span::styled(
                format!("{} Finalizing baseline...", throbber),
                Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)
            )),
        ];
        
        let paragraph = Paragraph::new(lines)
            .alignment(Alignment::Center);
        
        f.render_widget(paragraph, Rect {
            x: content_area.x,
            y: content_area.y + content_area.height / 2,
            width: content_area.width,
            height: 1,
        });
    } else {
        // Not creating baseline, show "no progress" message
        let lines = vec![
            Line::from(Span::styled(
                "No baseline creation in progress",
                Style::default().fg(hex_color(0x666666)).add_modifier(Modifier::DIM)
            )),
        ];
        
        let paragraph = Paragraph::new(lines)
            .alignment(Alignment::Center);
        
        f.render_widget(paragraph, Rect {
            x: content_area.x,
            y: content_area.y + content_area.height / 2,
            width: content_area.width,
            height: 1,
        });
    }
} //<

fn draw_completed_panel(f: &mut Frame, area: Rect, app: &App) { //>
    let popup_visible = app.popup.is_some();
    
    let border_style = if popup_visible {
        Style::default().fg(hex_color(0x222222))
    } else {
        Style::default().fg(hex_color(0x44AA44)) // Green border for completed
    };
    let border_type = BorderType::Rounded;
    
    // Title with count
    let title = format!(" Completed ({}) ", app.baseline_completed.len());
    
    let block = Block::default()
        .title(title)
        .borders(Borders::ALL)
        .border_type(border_type)
        .border_style(border_style);
    
    f.render_widget(block, area);
    
    // Content area (inside border)
    let content_area = Rect {
        x: area.x + 1,
        y: area.y + 1,
        width: area.width.saturating_sub(2),
        height: area.height.saturating_sub(2),
    };
    
    if !app.baseline_completed.is_empty() {
        let completed_color = if popup_visible { hex_color(0x444444) } else { hex_color(0x44AA44) };
        
        let items: Vec<ListItem> = app.baseline_completed.iter().map(|(dir_name, file_count)| {
            let line = Line::from(vec![
                Span::styled("  ✓ ", Style::default().fg(Color::Green)),
                Span::styled(
                    format!("{}: ", dir_name),
                    Style::default().fg(completed_color)
                ),
                Span::styled(
                    format!("{} files", file_count),
                    Style::default().fg(hex_color(0x888888))
                ),
            ]);
            ListItem::new(line)
        }).collect();
        
        // TODO: Add scrolling support with ListState if needed
        let list = List::new(items);
        f.render_widget(list, content_area);
    } else {
        // No completed yet
        let lines = vec![
            Line::from(Span::styled(
                "No directories completed yet",
                Style::default().fg(hex_color(0x666666)).add_modifier(Modifier::DIM)
            )),
        ];
        
        let paragraph = Paragraph::new(lines)
            .alignment(Alignment::Center);
        
        f.render_widget(paragraph, Rect {
            x: content_area.x,
            y: content_area.y + content_area.height / 2,
            width: content_area.width,
            height: 1,
        });
    }
} //<







// OLD FUNCTIONS - COMMENTED OUT FOR NEW 3-COLUMN LAYOUT  //>
/*

fn draw_commands_list_OLD(f: &mut Frame, area: Rect, app: &mut App, max_command_width: usize) { //>
    // Skip if area is too small
    if area.width == 0 || area.height == 0 {
        return;
    }
    
    // Calculate viewport bounds
    let viewport_height = area.height as usize;
    let total_actions = app.actions.len();
    
    // Calculate actions visability based on viewport
    let start_index = if app.selected_action >= viewport_height {
        app.selected_action - viewport_height + 1
    } else {
        0
    };
    let end_index = (start_index + viewport_height).min(total_actions);
    
    
    // Render visible actions only
    for (viewport_i, action_index) in (start_index..end_index).enumerate() {
        if let Some(action) = app.actions.get(action_index) {
            let command_text = action.name.clone();
            
            // Calculate padding to extend to scrollbar
            let scrollbar_x = area.x + (max_command_width + 8) as u16;
            let available_width = scrollbar_x - area.x;
            let padding_width = available_width.saturating_sub(command_text.len() as u16);
            let padding = " ".repeat(padding_width as usize);
            
            // Apply highlight style to entire line if this is the selected item
            let line_style = if action_index == app.selected_action {
                Style::default()
                    .fg(Color::White)
                    .bg(Color::DarkGray)
                    .add_modifier(Modifier::BOLD)
            } else {
                Style::default().fg(Color::White)
            };
            
            // Create the full line text
            let full_line = format!("{}{}", command_text, padding);
            
            // Render the line
            let line_paragraph = Paragraph::new(full_line)
                .style(line_style);
            
            f.render_widget(line_paragraph, Rect {
                x: area.x,
                y: area.y + viewport_i as u16,
                width: available_width - 1,
                height: 1,
            });
        }
    }

    // Show scrollbar for actions if there are more items than visible
    if total_actions > viewport_height {
        // Update scrollbar state with current viewport and position
        app.action_scrollbar = app.action_scrollbar.content_length(total_actions);
        app.action_scrollbar = app.action_scrollbar.viewport_content_length(viewport_height);
        app.action_scrollbar = app.action_scrollbar.position(app.selected_action);
        
        // Create separate scrollbar area positioned at max_command_width + 8
        let scrollbar_area = Rect {
            x: area.x + (max_command_width + 8) as u16,
            y: area.y,
            width: 1,
            height: area.height,
        };
        
        f.render_stateful_widget(
            Scrollbar::default()
                .orientation(ScrollbarOrientation::VerticalRight)
                .begin_symbol(Some("↑"))
                .end_symbol(Some("↓"))
                .track_symbol(Some("│"))
                .thumb_symbol("█"),
            scrollbar_area,
            &mut app.action_scrollbar,
        );
    }
} //<

fn draw_file_box(f: &mut Frame, area: Rect, app: &mut App) { //>
    if area.width == 0 || area.height == 0 {
        return;
    }

    let box_width = area.width;
    // let box_height = area.height;
    
    // Create the main file box with border
    let file_block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(Color::Rgb(0x66, 0x66, 0x66)));
    
    // Draw the file list content with the border block
    let file_list_items: Vec<ListItem> = if app.file_changes.is_empty() {
        vec![ListItem::new(" No file changes detected")]
    } else {
        app.file_changes.iter().enumerate().map(|(_i, file_change)| {
            let status_icon = match file_change.status {
                FileStatus::Tracked => "✓",
                FileStatus::Untracked => "!",
                FileStatus::Modified => "M",
            };
            
            let change_type_icon = match file_change.change_type {
                ChangeType::Modified => "MOD",
                ChangeType::New => "NEW",
            };
            
            let content = format!(" [{}] {} {} {}", 
                file_change.timestamp, 
                change_type_icon, 
                status_icon, 
                file_change.path
            );
            
            ListItem::new(content)
        }).collect()
    };
    
    let file_list = List::new(file_list_items)
        .block(file_block)
        .highlight_style(Style::default().add_modifier(Modifier::REVERSED));
    f.render_stateful_widget(file_list, area, &mut app.file_state);
    
    let tab_spans = build_tab_spans(app, box_width as usize);
    let top_border_paragraph = Paragraph::new(Line::from(tab_spans));
    
    f.render_widget(top_border_paragraph, Rect {
        x: area.x,
        y: area.y,
        width: box_width,
        height: 1,
    });
} //<

fn build_tab_spans(app: &App, box_width: usize) -> Vec<Span> { //>
    let mut tab_spans = vec![Span::raw("┌─── ")];
    
    for (i, file_view) in app.file_views.iter().enumerate() {
        if i > 0 {
            tab_spans.push(Span::raw(" ─ "));
        }
        
        let style = if i == app.active_file_view_index {
            Style::default().fg(Color::White).add_modifier(Modifier::BOLD)
        } else {
            Style::default().fg(Color::DarkGray)
        };
        
        tab_spans.push(Span::styled(file_view.name.clone(), style));
    }
    
    // Calculate remaining space for dashes
    let tab_text_len: usize = app.file_views.iter()
        .map(|fv| fv.name.len())
        .sum::<usize>() + (app.file_views.len() - 1) * 3; // " ─ " between tabs
    let available_space = box_width.saturating_sub(8); // Account for corners and padding
    let remaining_space = available_space.saturating_sub(tab_text_len);
    let middle_dashes = "─".repeat(remaining_space.max(1));
    let end_part = format!(" ─{}{}", middle_dashes, "┐");
    
    tab_spans.push(Span::raw(end_part));
    tab_spans
}
*/
//<====================================================


//<=========================================================================
