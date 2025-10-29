// UI rendering for detour TUI - Horizontal 3-column layout

use crate::app::{App, ActiveColumn, ViewMode};
use ratatui::{
    layout::{Alignment, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, Paragraph, BorderType},
    Frame,
};

fn hex_color(hex: u32) -> Color {
    Color::Rgb(
        ((hex >> 16) & 0xFF) as u8,
        ((hex >> 8) & 0xFF) as u8,
        (hex & 0xFF) as u8,
    )
}

pub fn ui(f: &mut Frame, app: &mut App) {
    let area = f.size();
    
    // Background
    f.render_widget(
        Paragraph::new("").style(Style::default().bg(hex_color(0x0A0A0A))),
        area
    );
    
    // Check minimum size
    if area.width < 120 || area.height < 20 {
        draw_minimal_ui(f, app);
        return;
    }
    
    // Title bar (3 lines high)
    let title_area = Rect {
        x: area.x,
        y: area.y,
        width: area.width,
        height: 3,
    };
    draw_title(f, title_area, app);
    
    // Main content area
    let content_y = title_area.y + title_area.height;
    let content_height = area.height.saturating_sub(title_area.height + 5);
    
    // Calculate column widths
    let col1_width = calculate_view_width(app);
    let col2_width = calculate_action_width(app);
    
    // Column 1: Views
    let col1_area = Rect {
        x: area.x + 1,
        y: content_y,
        width: col1_width,
        height: content_height,
    };
    draw_view_column(f, col1_area, app);
    
    // Column 2: Actions
    let col2_x = col1_area.x + col1_width + 1;
    let col2_area = Rect {
        x: col2_x,
        y: content_y,
        width: col2_width,
        height: content_height,
    };
    draw_action_column(f, col2_area, app);
    
    // Column 3: Content
    let col3_x = col2_area.x + col2_width + 1;
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
    draw_bottom_status(f, status_area, app);
}

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

fn draw_minimal_ui(f: &mut Frame, _app: &mut App) {
    let area = f.size();
    
    f.render_widget(
        Paragraph::new("").style(Style::default().bg(Color::Black)),
        area,
    );
    
    let message = "Terminal too small! Minimum: 120x20";
    let message_para = Paragraph::new(message)
        .alignment(Alignment::Center)
        .style(Style::default().fg(Color::Red).add_modifier(Modifier::BOLD));
    
    f.render_widget(message_para, Rect {
        x: area.x,
        y: area.y + area.height / 2 - 1,
        width: area.width,
        height: 1,
    });
    
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

fn draw_title(f: &mut Frame, area: Rect, app: &App) {
    let title_text = format!(
        " Detour  |  Profile: {}  |  {} active  |  Status: {} ",
        app.profile,
        app.active_detours_count(),
        app.status_icon()
    );
    
    let border_color = hex_color(0x666666);
    let text_color = hex_color(0xBBBBBB);
    
    let title_block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(border_color));
    
    let title = Paragraph::new(title_text)
        .alignment(Alignment::Center)
        .style(Style::default().fg(text_color).add_modifier(Modifier::BOLD))
        .block(title_block);
    
    f.render_widget(title, area);
}

fn draw_view_column(f: &mut Frame, area: Rect, app: &mut App) {
    let is_active = app.active_column == ActiveColumn::Views;
    
    let border_style = if is_active {
        Style::default().fg(Color::White)
    } else {
        Style::default().fg(hex_color(0x333333))
    };
    let border_type = if is_active { BorderType::Thick } else { BorderType::Plain };
    let text_color = if is_active {
        hex_color(0xFFFFFF)
    } else {
        hex_color(0x777777)
    };
    
    // Calculate max width for padding
    let max_width = app.views.iter().map(|v| v.len()).max().unwrap_or(8);
    
    let items: Vec<ListItem> = app.views.iter().map(|view| {
        let padding = max_width - view.len();
        let padded = format!(" {}{} ", view, " ".repeat(padding));
        ListItem::new(padded).style(Style::default().fg(text_color))
    }).collect();
    
    let mut state = app.view_state.clone();
    
    let highlight_style = Style::default()
        .bg(hex_color(0x2A2A2A))
        .fg(hex_color(0xFFFFFF))
        .add_modifier(Modifier::BOLD);
    
    let list = List::new(items)
        .block(Block::default()
            .borders(Borders::ALL)
            .border_type(border_type)
            .border_style(border_style))
        .highlight_style(highlight_style);
    
    f.render_stateful_widget(list, area, &mut state);
}

fn draw_action_column(f: &mut Frame, area: Rect, app: &mut App) {
    let actions = app.get_current_actions();
    let is_active = app.active_column == ActiveColumn::Actions;
    let is_content_active = app.active_column == ActiveColumn::Content;
    
    let border_style = if is_active {
        Style::default().fg(Color::White)
    } else {
        Style::default().fg(hex_color(0x333333))
    };
    let border_type = if is_active { BorderType::Thick } else { BorderType::Plain };
    let text_color = if is_active {
        hex_color(0xFFFFFF)
    } else {
        hex_color(0x777777)
    };
    
    // Calculate max width for padding
    let max_width = actions.iter().map(|a| a.len()).max().unwrap_or(15);
    
    let items: Vec<ListItem> = actions.iter().map(|action| {
        let padding = max_width - action.len();
        let padded = format!(" {}{} ", action, " ".repeat(padding));
        ListItem::new(padded).style(Style::default().fg(text_color))
    }).collect();
    
    let show_highlight = app.active_column != ActiveColumn::Views;
    let mut state = app.action_state.clone();
    
    let highlight_style = if is_active || is_content_active {
        Style::default()
            .bg(hex_color(0x2A2A2A))
            .fg(hex_color(0xFFFFFF))
            .add_modifier(Modifier::BOLD)
    } else if show_highlight {
        Style::default()
            .bg(hex_color(0x1A1A1A))
            .fg(hex_color(0xAAAAAA))
    } else {
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
    
    // Draw select indicator
    for (idx, _action) in actions.iter().enumerate() {
        if idx == app.selected_action {
            let indicator_x = area.x + area.width - 3;
            let indicator_y = area.y + (idx as u16) + 1;
            
            let color = if is_active || is_content_active {
                Color::White
            } else {
                hex_color(0x666666)
            };
            
            let indicator = Paragraph::new("◄")
                .style(Style::default().fg(color));
            f.render_widget(indicator, Rect {
                x: indicator_x,
                y: indicator_y,
                width: 2,
                height: 1,
            });
        }
    }
}

fn draw_content_column(f: &mut Frame, area: Rect, app: &mut App) {
    match app.view_mode {
        ViewMode::DetoursList => draw_detours_list(f, area, app),
        ViewMode::DetoursAdd => draw_detours_add(f, area, app),
        ViewMode::IncludesList => draw_includes_list(f, area, app),
        ViewMode::ServicesList => draw_services_list(f, area, app),
        ViewMode::StatusOverview => draw_status_overview(f, area, app),
        ViewMode::LogsLive => draw_logs_live(f, area, app),
        ViewMode::ConfigEdit => draw_config_edit(f, area, app),
    }
}

fn draw_detours_list(f: &mut Frame, area: Rect, app: &mut App) {
    let is_active = app.active_column == ActiveColumn::Content;
    
    let border_style = if is_active {
        Style::default().fg(Color::White)
    } else {
        Style::default().fg(hex_color(0x333333))
    };
    let border_type = if is_active { BorderType::Thick } else { BorderType::Plain };
    let text_color = if is_active {
        hex_color(0xFFFFFF)
    } else {
        hex_color(0x777777)
    };
    
    let title = format!(" Active Detours ({}) ", app.detours.len());
    
    let items: Vec<ListItem> = if app.detours.is_empty() {
        vec![ListItem::new(" No detours configured").style(Style::default().fg(Color::DarkGray))]
    } else {
        app.detours.iter().map(|detour| {
            let status_icon = if detour.active { "✓" } else { "○" };
            let line1 = format!("{} {} → {}", 
                status_icon,
                detour.original,
                detour.custom
            );
            let line2 = format!("   📝 {}  |  📏 {}  |  {}", 
                detour.modified_ago(),
                detour.size_display(),
                detour.status_text()
            );
            ListItem::new(vec![
                Line::from(line1),
                Line::from(Span::styled(line2, Style::default().fg(hex_color(0x888888)))),
            ]).style(Style::default().fg(text_color))
        }).collect()
    };
    
    let highlight_style = if is_active {
        Style::default()
            .bg(hex_color(0x2A2A2A))
            .fg(hex_color(0xFFFFFF))
            .add_modifier(Modifier::BOLD)
    } else {
        Style::default()
            .bg(hex_color(0x1A1A1A))
            .fg(hex_color(0xAAAAAA))
    };
    
    let list = List::new(items)
        .block(Block::default()
            .title(title)
            .borders(Borders::ALL)
            .border_type(border_type)
            .border_style(border_style))
        .highlight_style(highlight_style);
    
    f.render_stateful_widget(list, area, &mut app.detour_state);
}

fn draw_detours_add(f: &mut Frame, area: Rect, _app: &App) {
    let block = Block::default()
        .title(" Add New Detour ")
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(Color::White));
    
    f.render_widget(block, area);
    
    let content_area = Rect {
        x: area.x + 2,
        y: area.y + 2,
        width: area.width.saturating_sub(4),
        height: area.height.saturating_sub(4),
    };
    
    let lines = vec![
        Line::from(""),
        Line::from("Original Path:  /home/pi/homeassistant/configuration.yaml█"),
        Line::from("                [Tab] suggestions  [Ctrl+F] Browse"),
        Line::from(""),
        Line::from("Custom Path:    /home/pi/_playground/homeassistant/configuration.yaml"),
        Line::from(Span::styled("                ✓ File exists (3.8 KB, modified today)", Style::default().fg(Color::Green))),
        Line::from(""),
        Line::from(""),
        Line::from("              [Esc] Cancel          [Enter] Apply Detour"),
    ];
    
    let paragraph = Paragraph::new(lines);
    f.render_widget(paragraph, content_area);
}

fn draw_includes_list(f: &mut Frame, area: Rect, _app: &App) {
    let block = Block::default()
        .title(" Includes ")
        .borders(Borders::ALL)
        .border_style(Style::default().fg(hex_color(0x333333)));
    
    f.render_widget(block, area);
}

fn draw_services_list(f: &mut Frame, area: Rect, _app: &App) {
    let block = Block::default()
        .title(" Services ")
        .borders(Borders::ALL)
        .border_style(Style::default().fg(hex_color(0x333333)));
    
    f.render_widget(block, area);
}

fn draw_status_overview(f: &mut Frame, area: Rect, _app: &App) {
    let block = Block::default()
        .title(" System Status ")
        .borders(Borders::ALL)
        .border_style(Style::default().fg(hex_color(0x333333)));
    
    f.render_widget(block, area);
}

fn draw_logs_live(f: &mut Frame, area: Rect, _app: &App) {
    let block = Block::default()
        .title(" Detour Logs ")
        .borders(Borders::ALL)
        .border_style(Style::default().fg(hex_color(0x333333)));
    
    f.render_widget(block, area);
}

fn draw_config_edit(f: &mut Frame, area: Rect, _app: &App) {
    let block = Block::default()
        .title(" Configuration ")
        .borders(Borders::ALL)
        .border_style(Style::default().fg(hex_color(0x333333)));
    
    f.render_widget(block, area);
}

fn draw_bottom_status(f: &mut Frame, area: Rect, app: &App) {
    // Line 1: Navigation hints
    let nav_text = "[Tab] Next  [↑↓/jk] Navigate  [Enter] Select  [?] Help  [q] Quit";
    let nav_paragraph = Paragraph::new(nav_text)
        .style(Style::default().fg(Color::DarkGray));
    f.render_widget(nav_paragraph, Rect {
        x: area.x,
        y: area.y + 1,
        width: area.width,
        height: 1,
    });
    
    // Line 2: Horizontal divider
    let divider_line = "─".repeat(area.width as usize);
    let divider_paragraph = Paragraph::new(divider_line)
        .style(Style::default().fg(Color::White));
    f.render_widget(divider_paragraph, Rect {
        x: area.x,
        y: area.y + 2,
        width: area.width,
        height: 1,
    });
    
    // Line 3: Dynamic description
    let description = app.get_current_description();
    let desc_line = format!(" {:<width$} ", description, width = area.width as usize - 2);
    let desc_paragraph = Paragraph::new(desc_line)
        .style(Style::default().fg(Color::White));
    f.render_widget(desc_paragraph, Rect {
        x: area.x,
        y: area.y + 3,
        width: area.width,
        height: 1,
    });
}

