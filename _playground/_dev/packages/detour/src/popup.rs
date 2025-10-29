// Popup and dialog management

use ratatui::{
    layout::{Alignment, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph, BorderType, Clear},
    Frame,
};

fn hex_color(hex: u32) -> Color {
    Color::Rgb(
        ((hex >> 16) & 0xFF) as u8,
        ((hex >> 8) & 0xFF) as u8,
        (hex & 0xFF) as u8,
    )
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
        }
    }
    
    pub fn handle_left(&mut self) {
        if let Popup::Confirm { selected, .. } = self {
            *selected = (*selected + 1) % 2;
        }
    }
    
    pub fn handle_right(&mut self) {
        if let Popup::Confirm { selected, .. } = self {
            *selected = (*selected + 1) % 2;
        }
    }
    
    pub fn handle_char(&mut self, c: char) {
        if let Popup::Input { input, cursor_pos, .. } = self {
            input.insert(*cursor_pos, c);
            *cursor_pos += 1;
        }
    }
    
    pub fn handle_backspace(&mut self) {
        if let Popup::Input { input, cursor_pos, .. } = self {
            if *cursor_pos > 0 {
                input.remove(*cursor_pos - 1);
                *cursor_pos -= 1;
            }
        }
    }
    
    pub fn handle_delete(&mut self) {
        if let Popup::Input { input, cursor_pos, .. } = self {
            if *cursor_pos < input.len() {
                input.remove(*cursor_pos);
            }
        }
    }
    
    pub fn move_cursor_left(&mut self) {
        if let Popup::Input { cursor_pos, .. } = self {
            if *cursor_pos > 0 {
                *cursor_pos -= 1;
            }
        }
    }
    
    pub fn move_cursor_right(&mut self) {
        if let Popup::Input { input, cursor_pos, .. } = self {
            if *cursor_pos < input.len() {
                *cursor_pos += 1;
            }
        }
    }
    
    pub fn get_input(&self) -> Option<String> {
        if let Popup::Input { input, .. } = self {
            Some(input.clone())
        } else {
            None
        }
    }
    
    pub fn is_yes_selected(&self) -> bool {
        if let Popup::Confirm { selected, .. } = self {
            *selected == 0
        } else {
            false
        }
    }
}

pub fn draw_popup(f: &mut Frame, area: Rect, popup: &Popup) {
    // Darken background
    let bg = Block::default().style(Style::default().bg(hex_color(0x000000)));
    f.render_widget(bg, area);
    
    match popup {
        Popup::Confirm { title, message, selected } => {
            draw_confirm_popup(f, area, title, message, *selected);
        }
        Popup::Input { title, prompt, input, cursor_pos } => {
            draw_input_popup(f, area, title, prompt, input, *cursor_pos);
        }
        Popup::Error { title, message } => {
            draw_message_popup(f, area, title, message, Color::Red);
        }
        Popup::Info { title, message } => {
            draw_message_popup(f, area, title, message, Color::Cyan);
        }
    }
}

fn draw_confirm_popup(f: &mut Frame, area: Rect, title: &str, message: &str, selected: usize) {
    let popup_width = message.len().max(30).min(area.width as usize - 4) as u16 + 4;
    let popup_height = 9u16;
    
    let popup_x = (area.width.saturating_sub(popup_width)) / 2;
    let popup_y = (area.height.saturating_sub(popup_height)) / 2;
    
    let popup_area = Rect {
        x: popup_x,
        y: popup_y,
        width: popup_width,
        height: popup_height,
    };
    
    // Clear area
    f.render_widget(Clear, popup_area);
    
    // Draw box
    let block = Block::default()
        .title(format!(" {} ", title))
        .borders(Borders::ALL)
        .border_type(BorderType::Double)
        .border_style(Style::default().fg(Color::White))
        .style(Style::default().bg(hex_color(0x0A0A0A)));
    
    f.render_widget(block, popup_area);
    
    // Content
    let content_area = Rect {
        x: popup_area.x + 2,
        y: popup_area.y + 2,
        width: popup_area.width.saturating_sub(4),
        height: popup_area.height.saturating_sub(4),
    };
    
    let yes_style = if selected == 0 {
        Style::default().fg(Color::Green).add_modifier(Modifier::BOLD)
    } else {
        Style::default().fg(hex_color(0x666666))
    };
    
    let no_style = if selected == 1 {
        Style::default().fg(Color::Red).add_modifier(Modifier::BOLD)
    } else {
        Style::default().fg(hex_color(0x666666))
    };
    
    let lines = vec![
        Line::from(""),
        Line::from(Span::styled(message, Style::default().fg(Color::White))),
        Line::from(""),
        Line::from(""),
        Line::from(vec![
            Span::raw("    "),
            Span::styled("[ Yes ]", yes_style),
            Span::raw("    "),
            Span::styled("[ No ]", no_style),
        ]),
    ];
    
    let paragraph = Paragraph::new(lines).alignment(Alignment::Center);
    f.render_widget(paragraph, content_area);
}

fn draw_input_popup(f: &mut Frame, area: Rect, title: &str, prompt: &str, input: &str, cursor_pos: usize) {
    let popup_width = 60u16.min(area.width - 4);
    let popup_height = 7u16;
    
    let popup_x = (area.width.saturating_sub(popup_width)) / 2;
    let popup_y = (area.height.saturating_sub(popup_height)) / 2;
    
    let popup_area = Rect {
        x: popup_x,
        y: popup_y,
        width: popup_width,
        height: popup_height,
    };
    
    // Clear area
    f.render_widget(Clear, popup_area);
    
    // Draw box
    let block = Block::default()
        .title(format!(" {} ", title))
        .borders(Borders::ALL)
        .border_type(BorderType::Double)
        .border_style(Style::default().fg(Color::White))
        .style(Style::default().bg(hex_color(0x0A0A0A)));
    
    f.render_widget(block, popup_area);
    
    // Content
    let content_area = Rect {
        x: popup_area.x + 2,
        y: popup_area.y + 2,
        width: popup_area.width.saturating_sub(4),
        height: popup_area.height.saturating_sub(4),
    };
    
    // Build input line with cursor
    let mut input_spans = vec![Span::raw(" ")];
    
    if cursor_pos == 0 {
        input_spans.push(Span::styled("█", Style::default().fg(Color::Yellow)));
        input_spans.push(Span::styled(input, Style::default().fg(Color::White)));
    } else if cursor_pos >= input.len() {
        input_spans.push(Span::styled(input, Style::default().fg(Color::White)));
        input_spans.push(Span::styled("█", Style::default().fg(Color::Yellow)));
    } else {
        input_spans.push(Span::styled(&input[..cursor_pos], Style::default().fg(Color::White)));
        input_spans.push(Span::styled("█", Style::default().fg(Color::Yellow)));
        input_spans.push(Span::styled(&input[cursor_pos..], Style::default().fg(Color::White)));
    }
    
    let lines = vec![
        Line::from(Span::styled(prompt, Style::default().fg(hex_color(0x888888)))),
        Line::from(""),
        Line::from(input_spans),
    ];
    
    let paragraph = Paragraph::new(lines);
    f.render_widget(paragraph, content_area);
}

fn draw_message_popup(f: &mut Frame, area: Rect, title: &str, message: &str, color: Color) {
    let popup_width = message.len().max(30).min(area.width as usize - 4) as u16 + 4;
    let popup_height = 7u16;
    
    let popup_x = (area.width.saturating_sub(popup_width)) / 2;
    let popup_y = (area.height.saturating_sub(popup_height)) / 2;
    
    let popup_area = Rect {
        x: popup_x,
        y: popup_y,
        width: popup_width,
        height: popup_height,
    };
    
    // Clear area
    f.render_widget(Clear, popup_area);
    
    // Draw box
    let block = Block::default()
        .title(format!(" {} ", title))
        .borders(Borders::ALL)
        .border_type(BorderType::Double)
        .border_style(Style::default().fg(color))
        .style(Style::default().bg(hex_color(0x0A0A0A)));
    
    f.render_widget(block, popup_area);
    
    // Content
    let content_area = Rect {
        x: popup_area.x + 2,
        y: popup_area.y + 2,
        width: popup_area.width.saturating_sub(4),
        height: popup_area.height.saturating_sub(4),
    };
    
    let lines = vec![
        Line::from(""),
        Line::from(Span::styled(message, Style::default().fg(Color::White))),
        Line::from(""),
        Line::from(Span::styled("[Enter] to close", Style::default().fg(hex_color(0x666666)))),
    ];
    
    let paragraph = Paragraph::new(lines).alignment(Alignment::Center);
    f.render_widget(paragraph, content_area);
}







