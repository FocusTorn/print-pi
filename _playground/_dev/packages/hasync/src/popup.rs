// Popup and dialog management

use ratatui::{
    layout::{Alignment, Rect},
    style::{Color, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph, BorderType, Clear},
    Frame,
};
use std::time::Instant;

fn hex_color(hex: u32) -> Color {
    Color::Rgb(
        ((hex >> 16) & 0xFF) as u8,
        ((hex >> 8) & 0xFF) as u8,
        (hex & 0xFF) as u8,
    )
}

// Helper function to wrap text to a given width
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

#[derive(Debug, Clone)]
pub enum Popup {
    Confirm {
        title: String,
        message: String,
        selected: usize, // 0 = Yes, 1 = No
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
        shown_at: Instant,  // For auto-dismiss
    },
}

impl Popup {
    pub fn confirm(title: impl Into<String>, message: impl Into<String>) -> Self {
        Popup::Confirm {
            title: title.into(),
            message: message.into(),
            selected: 1, // Default to "No" for safety
        }
    }
    
    pub fn input(title: impl Into<String>, prompt: impl Into<String>) -> Self {
        Popup::Input {
            title: title.into(),
            prompt: prompt.into(),
            input: String::new(),
            cursor_pos: 0,
        }
    }
    
    pub fn error(title: impl Into<String>, message: impl Into<String>) -> Self {
        Popup::Error {
            title: title.into(),
            message: message.into(),
        }
    }
    
    pub fn info(title: impl Into<String>, message: impl Into<String>) -> Self {
        Popup::Info {
            title: title.into(),
            message: message.into(),
            shown_at: Instant::now(),
        }
    }
}

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

pub fn draw_popup(f: &mut Frame, area: Rect, popup: &Popup) {
    match popup {
        Popup::Confirm { title, message, selected } => draw_confirm(f, area, title, message, *selected),
        Popup::Input { title, prompt, input, cursor_pos } => draw_input(f, area, title, prompt, input, *cursor_pos),
        Popup::Error { title, message } => draw_error(f, area, title, message),
        Popup::Info { title, message, .. } => draw_info(f, area, title, message),
    }
}

fn draw_confirm(f: &mut Frame, area: Rect, title: &str, message: &str, selected: usize) {
    // Calculate width based on content
    let max_line_len = message.lines().map(|l| l.len()).max().unwrap_or(30);
    let popup_width = (max_line_len as u16 + 8)
        .max(40)
        .min((area.width as f32 * 0.60) as u16)
        .min(area.width - 4);
    
    let wrapped_lines = wrap_text(message, (popup_width - 4) as usize);
    let popup_height = (wrapped_lines.len() as u16 + 7).min(area.height - 4);
    
    let popup_area = centered_rect(
        ((popup_width as f32 / area.width as f32) * 100.0) as u16,
        ((popup_height as f32 / area.height as f32) * 100.0) as u16,
        area,
    );
    
    f.render_widget(Clear, popup_area);
    
    let block = Block::default()
        .title(format!(" {} ", title))
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(Color::White));
    
    let inner = block.inner(popup_area);
    f.render_widget(block, popup_area);
    
    // Message
    let message_lines: Vec<Line> = wrapped_lines.iter().map(|l| Line::from(l.as_str())).collect();
    let message_para = Paragraph::new(message_lines)
        .alignment(Alignment::Left)
        .style(Style::default().fg(Color::White));
    
    let message_area = Rect {
        x: inner.x + 1,
        y: inner.y + 1,
        width: inner.width.saturating_sub(2),
        height: wrapped_lines.len() as u16,
    };
    f.render_widget(message_para, message_area);
    
    // Buttons
    let button_y = inner.y + inner.height.saturating_sub(2);
    let yes_area = Rect {
        x: inner.x + (inner.width / 2) - 10,
        y: button_y,
        width: 8,
        height: 1,
    };
    let no_area = Rect {
        x: inner.x + (inner.width / 2) + 2,
        y: button_y,
        width: 8,
        height: 1,
    };
    
    let yes_style = if selected == 0 {
        Style::default().fg(Color::Green).bg(hex_color(0x0F1F0F))
    } else {
        Style::default().fg(hex_color(0x666666))
    };
    
    let no_style = if selected == 1 {
        Style::default().fg(hex_color(0xFF4444)).bg(hex_color(0x1F0F0F))
    } else {
        Style::default().fg(hex_color(0x666666))
    };
    
    f.render_widget(Paragraph::new("  Yes  ").style(yes_style), yes_area);
    f.render_widget(Paragraph::new("  No  ").style(no_style), no_area);
}

fn draw_input(f: &mut Frame, area: Rect, title: &str, prompt: &str, input: &str, cursor_pos: usize) {
    let popup_width = 50u16.min(area.width - 4);
    let popup_height = 8u16.min(area.height - 4);
    
    let popup_area = centered_rect(
        ((popup_width as f32 / area.width as f32) * 100.0) as u16,
        ((popup_height as f32 / area.height as f32) * 100.0) as u16,
        area,
    );
    
    f.render_widget(Clear, popup_area);
    
    let block = Block::default()
        .title(format!(" {} ", title))
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(Color::White));
    
    let inner = block.inner(popup_area);
    f.render_widget(block, popup_area);
    
    // Prompt
    let prompt_para = Paragraph::new(prompt)
        .style(Style::default().fg(Color::White));
    f.render_widget(prompt_para, Rect {
        x: inner.x + 1,
        y: inner.y + 1,
        width: inner.width.saturating_sub(2),
        height: 1,
    });
    
    // Input
    let cursor = cursor_pos.min(input.len());
    let (head, tail) = input.split_at(cursor);
    let input_line = Line::from(vec![
        Span::styled(head, Style::default().fg(Color::White)),
        Span::styled("█", Style::default().fg(Color::Yellow)),
        Span::styled(tail, Style::default().fg(Color::White)),
    ]);
    let input_para = Paragraph::new(input_line);
    f.render_widget(input_para, Rect {
        x: inner.x + 1,
        y: inner.y + 3,
        width: inner.width.saturating_sub(2),
        height: 1,
    });
}

fn draw_error(f: &mut Frame, area: Rect, title: &str, message: &str) {
    draw_info(f, area, title, message);
}

fn draw_info(f: &mut Frame, area: Rect, title: &str, message: &str) {
    let max_line_len = message.lines().map(|l| l.len()).max().unwrap_or(30);
    let popup_width = (max_line_len as u16 + 8)
        .max(40)
        .min((area.width as f32 * 0.60) as u16)
        .min(area.width - 4);
    
    let wrapped_lines = wrap_text(message, (popup_width - 4) as usize);
    let popup_height = (wrapped_lines.len() as u16 + 6).min(area.height - 4);
    
    let popup_area = centered_rect(
        ((popup_width as f32 / area.width as f32) * 100.0) as u16,
        ((popup_height as f32 / area.height as f32) * 100.0) as u16,
        area,
    );
    
    f.render_widget(Clear, popup_area);
    
    let block = Block::default()
        .title(format!(" {} ", title))
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(Color::White));
    
    let inner = block.inner(popup_area);
    f.render_widget(block, popup_area);
    
    let message_lines: Vec<Line> = wrapped_lines.iter().map(|l| Line::from(l.as_str())).collect();
    let message_para = Paragraph::new(message_lines)
        .alignment(Alignment::Left)
        .style(Style::default().fg(Color::White));
    
    f.render_widget(message_para, Rect {
        x: inner.x + 1,
        y: inner.y + 1,
        width: inner.width.saturating_sub(2),
        height: wrapped_lines.len() as u16,
    });
}

