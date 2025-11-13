// Shared helper functions for TUI components

use ratatui::style::{Color, Style};

/// Convert a hex color value (0xRRGGBB) to a ratatui Color
pub fn hex_color(hex: u32) -> Color {
    Color::Rgb(
        ((hex >> 16) & 0xFF) as u8,
        ((hex >> 8) & 0xFF) as u8,
        (hex & 0xFF) as u8,
    )
}

/// Get selection style based on active state
pub fn get_selection_style(is_active: bool) -> Style {
    if is_active {
        Style::default().bg(hex_color(0x1A2A2A)).fg(Color::Cyan)
    } else {
        Style::default().bg(hex_color(0x151515)).fg(hex_color(0x777777))
    }
}

/// Get accent color style (cyan)
pub fn accent_color() -> Style {
    Style::default().fg(Color::Cyan)
}

/// Create a centered rectangle within a parent rectangle
pub fn centered_rect(percent_x: u16, percent_y: u16, r: ratatui::layout::Rect) -> ratatui::layout::Rect {
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

