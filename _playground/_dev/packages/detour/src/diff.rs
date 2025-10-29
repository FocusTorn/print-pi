// Diff viewer for comparing files

use ratatui::{
    layout::{Alignment, Rect},
    style::{Color, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph, BorderType, Clear},
    Frame,
};
use std::fs;

fn hex_color(hex: u32) -> Color {
    Color::Rgb(
        ((hex >> 16) & 0xFF) as u8,
        ((hex >> 8) & 0xFF) as u8,
        (hex & 0xFF) as u8,
    )
}

pub struct DiffViewer {
    pub left_path: String,
    pub right_path: String,
    pub left_content: Vec<String>,
    pub right_content: Vec<String>,
    pub scroll_offset: usize,
}

impl DiffViewer {
    pub fn new(left_path: String, right_path: String) -> Result<Self, String> {
        let left_content = fs::read_to_string(&left_path)
            .map_err(|e| format!("Failed to read {}: {}", left_path, e))?
            .lines()
            .map(|s| s.to_string())
            .collect();
        
        let right_content = fs::read_to_string(&right_path)
            .map_err(|e| format!("Failed to read {}: {}", right_path, e))?
            .lines()
            .map(|s| s.to_string())
            .collect();
        
        Ok(DiffViewer {
            left_path,
            right_path,
            left_content,
            right_content,
            scroll_offset: 0,
        })
    }
    
    pub fn scroll_up(&mut self) {
        if self.scroll_offset > 0 {
            self.scroll_offset -= 1;
        }
    }
    
    pub fn scroll_down(&mut self, visible_lines: usize) {
        let max_lines = self.left_content.len().max(self.right_content.len());
        if self.scroll_offset + visible_lines < max_lines {
            self.scroll_offset += 1;
        }
    }
    
    pub fn scroll_page_up(&mut self, page_size: usize) {
        self.scroll_offset = self.scroll_offset.saturating_sub(page_size);
    }
    
    pub fn scroll_page_down(&mut self, page_size: usize, visible_lines: usize) {
        let max_lines = self.left_content.len().max(self.right_content.len());
        let max_offset = max_lines.saturating_sub(visible_lines);
        self.scroll_offset = (self.scroll_offset + page_size).min(max_offset);
    }
}

pub fn draw_diff(f: &mut Frame, area: Rect, diff: &DiffViewer) {
    // Clear area
    f.render_widget(Clear, area);
    
    // Outer block
    let block = Block::default()
        .title(" Diff Viewer ")
        .borders(Borders::ALL)
        .border_type(BorderType::Double)
        .border_style(Style::default().fg(Color::White))
        .style(Style::default().bg(hex_color(0x0A0A0A)));
    
    f.render_widget(block, area);
    
    // Split into two panels
    let content_area = Rect {
        x: area.x + 1,
        y: area.y + 1,
        width: area.width.saturating_sub(2),
        height: area.height.saturating_sub(4), // Leave room for bottom help
    };
    
    let left_width = content_area.width / 2;
    let right_width = content_area.width - left_width;
    
    // Left panel
    let left_area = Rect {
        x: content_area.x,
        y: content_area.y,
        width: left_width,
        height: content_area.height,
    };
    
    // Right panel
    let right_area = Rect {
        x: content_area.x + left_width,
        y: content_area.y,
        width: right_width,
        height: content_area.height,
    };
    
    draw_diff_panel(f, left_area, &diff.left_path, &diff.left_content, diff.scroll_offset, true);
    draw_diff_panel(f, right_area, &diff.right_path, &diff.right_content, diff.scroll_offset, false);
    
    // Bottom help
    let help_area = Rect {
        x: area.x + 2,
        y: area.y + area.height.saturating_sub(2),
        width: area.width.saturating_sub(4),
        height: 1,
    };
    
    let help_text = "[↑↓] Scroll  [PgUp/PgDn] Page  [Esc] Close";
    let help = Paragraph::new(help_text)
        .style(Style::default().fg(hex_color(0x666666)))
        .alignment(Alignment::Center);
    f.render_widget(help, help_area);
}

fn draw_diff_panel(
    f: &mut Frame,
    area: Rect,
    title: &str,
    content: &[String],
    scroll_offset: usize,
    is_left: bool,
) {
    let block = Block::default()
        .title(format!(" {} ", shorten_path(title, area.width as usize - 4)))
        .borders(Borders::ALL)
        .border_style(Style::default().fg(if is_left { Color::Cyan } else { Color::Green }));
    
    f.render_widget(block, area);
    
    let inner_area = Rect {
        x: area.x + 1,
        y: area.y + 1,
        width: area.width.saturating_sub(2),
        height: area.height.saturating_sub(2),
    };
    
    let visible_lines = inner_area.height as usize;
    let end_idx = (scroll_offset + visible_lines).min(content.len());
    
    let lines: Vec<Line> = content[scroll_offset..end_idx]
        .iter()
        .enumerate()
        .map(|(idx, line)| {
            let line_num = scroll_offset + idx + 1;
            let num_str = format!("{:>4} │ ", line_num);
            
            // Truncate long lines
            let max_line_len = (inner_area.width as usize).saturating_sub(7);
            let truncated = if line.len() > max_line_len {
                format!("{}...", &line[..max_line_len.saturating_sub(3)])
            } else {
                line.clone()
            };
            
            Line::from(vec![
                Span::styled(num_str, Style::default().fg(hex_color(0x444444))),
                Span::styled(truncated, Style::default().fg(Color::White)),
            ])
        })
        .collect();
    
    // Fill remaining lines if content is shorter than visible area
    let mut all_lines = lines;
    while all_lines.len() < visible_lines {
        all_lines.push(Line::from(Span::styled("~", Style::default().fg(hex_color(0x333333)))));
    }
    
    let paragraph = Paragraph::new(all_lines);
    f.render_widget(paragraph, inner_area);
}

fn shorten_path(path: &str, max_len: usize) -> String {
    if path.len() <= max_len {
        path.to_string()
    } else {
        let parts: Vec<&str> = path.split('/').collect();
        if parts.len() <= 2 {
            format!("...{}", &path[path.len().saturating_sub(max_len - 3)..])
        } else {
            format!(".../{}", parts.last().unwrap())
        }
    }
}

