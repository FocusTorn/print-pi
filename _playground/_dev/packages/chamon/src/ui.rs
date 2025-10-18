use crate::app::{App, ChangeType, FileStatus};
use ratatui::{ //>
    layout::{Alignment, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, Paragraph, Scrollbar, ScrollbarOrientation, BorderType},
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
    
    f.render_widget( Paragraph::new("") .style(Style::default().bg(hex_color(0x0A0A0A))), area );
    
    if area.width < 80 || area.height < 10 { //> Check if terminal is too small and show minimal UI
        draw_minimal_ui(f, app);
        return;
    } //<
    
    let max_command_width = app.actions.iter() //> Calculate the widest command text for positioning
        .map(|action| action.name.len())
        .max()
        .unwrap_or(20); //<
        
    let inner_area = Rect { //>
        x: area.x + 1,
        y: area.y + 1,
        width: area.width - 2,
        height: area.height - 2,
    }; //<
    
    let title_area = Rect { //>
        x: area.x,
        y: area.y,
        width: area.width,
        height: 3,
    };

    draw_title(f, title_area, app);  //<

    let commands_area = Rect { //>
        x: area.x + 2,
        y: area.y + 4,
        width: (max_command_width + 1) as u16,
        height: area.height.saturating_sub(6),
    };
    
    draw_commands_list(f, commands_area, app, max_command_width); //<
    
    // File list box -------->> 
    
    let tab_start_x = area.x + 1 + max_command_width as u16 + 10; // 10 spaces from command end
    let tab_width = inner_area.width - (tab_start_x - inner_area.x) - 1; // 1 space from right wall
        
    let file_box_area = Rect {
        x: tab_start_x,
        y: inner_area.y + 2, // Directly under the top border
        width: tab_width as u16,
        height: inner_area.height.saturating_sub(6), // -3 from bottom + 3 for bottom status
    };
    
    draw_file_box(f, file_box_area, app);
    
    //----------------------------------------------------<<
    
    let status_area = Rect { //>
        x: inner_area.x,
        y: inner_area.y + inner_area.height.saturating_sub(4),
        width: inner_area.width,
        height: 3,
    };
    
    draw_bottom_status(f, status_area, app); //<
    
} //<


fn draw_title(f: &mut Frame, area: Rect, app: &mut App) { //> //>
    
    let title_text = &app.config.title_bar.display;
    
    let title_block = Block::default()
    .borders(Borders::ALL)
    .border_type(BorderType::Rounded)
    .border_style(Style::default().fg(hex_color(0x666666)));
    
    let title = Paragraph::new(title_text.as_str())
        .alignment(Alignment::Center)
        .style(Style::default().fg(hex_color(0xBBBBBB)).add_modifier(Modifier::BOLD))
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

fn draw_commands_list(f: &mut Frame, area: Rect, app: &mut App, max_command_width: usize) { //>
    // Skip if area is too small
    if area.width == 0 || area.height == 0 {
        return;
    }
    
    // Calculate viewport bounds
    let viewport_height = area.height as usize;
    let total_actions = app.actions.len();
    
    //> Calculate actions visability based on viewport
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
    } //<

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
} //<

fn draw_bottom_status(f: &mut Frame, area: Rect, app: &mut App) { //>
    // Line 1: Navigation hints
    let nav_text = &app.config.help_line.text;
    let nav_paragraph = Paragraph::new(nav_text.as_str())
        .style(Style::default().fg(Color::DarkGray));
    f.render_widget(nav_paragraph, Rect {
        x: area.x,
        y: area.y+1,
        width: area.width,
        height: 1,
    });
    
    // Line 3: Horizontal divider
    let divider_line = "─".repeat(area.width as usize);
    let divider_paragraph = Paragraph::new(divider_line)
        .style(Style::default().fg(Color::White));
    f.render_widget(divider_paragraph, Rect {
        x: area.x,
        y: area.y + 2,
        width: area.width,
        height: 1,
    });
    
    // Line 4: Dynamic description
    let description = app.get_current_action_description();
    let desc_line = format!(" {:<width$} ", description, width = area.width as usize - 2);
    let desc_paragraph = Paragraph::new(desc_line)
        .style(Style::default().fg(Color::White));
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
