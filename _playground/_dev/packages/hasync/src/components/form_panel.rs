// Universal form panel component

use ratatui::{
    layout::Rect,
    style::{Color, Style},
    text::{Line, Span},
    widgets::{Block, BorderType, Borders, Paragraph},
    Frame,
};

fn hex_color(hex: u32) -> Color {
    Color::Rgb(
        ((hex >> 16) & 0xFF) as u8,
        ((hex >> 8) & 0xFF) as u8,
        (hex & 0xFF) as u8,
    )
}

fn accent_color() -> Style { Style::default().fg(Color::Cyan) }

pub struct FormField {
    pub label: String,
    pub value: String,
    pub placeholder: String,
}

pub struct FormState {
    pub active_field: usize,
    pub cursor_pos: usize,
}

pub fn draw_form_panel(
    f: &mut Frame,
    area: Rect,
    title: &str,
    fields: &[FormField],
    state: &FormState,
    is_active: bool,
    modal_visible: bool,
) {
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

    let title_span = Span::styled(
        format!(" {} ", title),
        if is_active { accent_color() } else { Style::default().fg(text_color) },
    );

    let block = Block::default()
        .title(title_span)
        .borders(Borders::ALL)
        .border_type(border_type)
        .border_style(border_style);
    f.render_widget(block, area);

    let content_area = Rect { x: area.x + 2, y: area.y + 2, width: area.width.saturating_sub(4), height: area.height.saturating_sub(4) };

    let use_compact = content_area.height < 20;
    let mut lines: Vec<Line> = vec![];

    for (idx, field) in fields.iter().enumerate() {
        let is_placeholder = field.value.is_empty();
        let label_style = if is_active && state.active_field == idx { accent_color() } else { Style::default().fg(text_color) };

        if use_compact {
            // Compact mode: single line with label: value
            if is_active && state.active_field == idx {
                let display_text = if is_placeholder { field.placeholder.clone() } else { field.value.clone() };
                let cursor = state.cursor_pos.min(display_text.len());
                let text_fg = if is_placeholder { Color::DarkGray } else { Color::White };
                let (head, tail) = display_text.split_at(cursor);
                lines.push(Line::from(vec![
                    Span::styled(field.label.clone(), label_style),
                    Span::raw(" "),
                    Span::styled(head.to_string(), Style::default().fg(text_fg)),
                    Span::styled("█", Style::default().fg(Color::White)),
                    Span::styled(tail.to_string(), Style::default().fg(text_fg)),
                ]));
            } else {
                let display_text = if is_placeholder { field.placeholder.clone() } else { field.value.clone() };
                let value_color = if !is_active { text_color } else if is_placeholder { Color::DarkGray } else if state.active_field == idx { Color::White } else { Color::Gray };
                lines.push(Line::from(vec![
                    Span::styled(field.label.clone(), label_style),
                    Span::raw(" "),
                    Span::styled(display_text, Style::default().fg(value_color)),
                ]));
            }
        } else {
            // Normal mode: label on one line, value on next line
            lines.push(Line::from(Span::styled(field.label.clone(), label_style)));

            if is_active && state.active_field == idx {
                let display_text = if is_placeholder { field.placeholder.clone() } else { field.value.clone() };
                let cursor = state.cursor_pos.min(display_text.len());
                let text_fg = if is_placeholder { Color::DarkGray } else { Color::White };
                let (head, tail) = display_text.split_at(cursor);
                lines.push(Line::from(vec![
                    Span::raw("  "),
                    Span::styled(head.to_string(), Style::default().fg(text_fg)),
                    Span::styled("█", Style::default().fg(Color::White)),
                    Span::styled(tail.to_string(), Style::default().fg(text_fg)),
                ]));
            } else {
                let display_text = if is_placeholder { field.placeholder.clone() } else { field.value.clone() };
                let color = if !is_active { text_color } else if is_placeholder { Color::DarkGray } else if state.active_field == idx { Color::White } else { Color::Gray };
                lines.push(Line::from(Span::styled(format!("  {}", display_text), Style::default().fg(color))));
            }

            lines.push(Line::from(""));
        }
    }

    f.render_widget(Paragraph::new(lines), content_area);
}
