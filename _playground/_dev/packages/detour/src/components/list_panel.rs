use ratatui::{
    style::{Color, Style},
    text::{Line, Span},
    widgets::{Block, BorderType, Borders, List, ListItem},
    Frame,
};
use ratatui::widgets::ListState;
use ratatui::layout::Rect;

fn hex_color(hex: u32) -> Color {
    Color::Rgb(
        ((hex >> 16) & 0xFF) as u8,
        ((hex >> 8) & 0xFF) as u8,
        (hex & 0xFF) as u8,
    )
}

fn get_selection_style(is_active: bool) -> Style {
    if is_active {
        Style::default().bg(hex_color(0x1A2A2A)).fg(Color::Cyan)
    } else {
        Style::default().bg(hex_color(0x151515)).fg(hex_color(0x777777))
    }
}

pub struct ItemRow {
    pub line1: String,
    pub line2: Option<String>,
    pub status_icon: Option<String>,
}

pub struct ListPanelTheme {
    pub secondary_text: Color,
}

impl Default for ListPanelTheme {
    fn default() -> Self {
        Self { secondary_text: hex_color(0x888888) }
    }
}

pub fn draw_list_panel(
    f: &mut Frame,
    area: Rect,
    title: &str,
    items: &[ItemRow],
    state: &mut ListState,
    is_active: bool,
    modal_visible: bool,
    theme: &ListPanelTheme,
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
        if is_active { Style::default().fg(Color::Cyan) } else { Style::default().fg(text_color) },
    );

    let list_items: Vec<ListItem> = if items.is_empty() {
        vec![ListItem::new(" No items").style(Style::default().fg(Color::DarkGray))]
    } else {
        items
            .iter()
            .map(|row| {
                let mut lines: Vec<Line> = Vec::new();
                let mut line1 = String::new();
                if let Some(icon) = &row.status_icon {
                    line1.push_str(icon);
                    line1.push(' ');
                }
                line1.push_str(&row.line1);
                lines.push(Line::from(line1));
                if let Some(second) = &row.line2 {
                    lines.push(Line::from(Span::styled(second.clone(), Style::default().fg(theme.secondary_text))));
                }
                ListItem::new(lines).style(Style::default().fg(text_color))
            })
            .collect()
    };

    let highlight_style = if modal_visible {
        Style::default()
            .bg(hex_color(0x0D0D0D))
            .fg(hex_color(0x444444))
    } else {
        get_selection_style(is_active)
    };

    let list = List::new(list_items)
        .block(
            Block::default()
                .title(title_span)
                .borders(Borders::ALL)
                .border_type(border_type)
                .border_style(border_style),
        )
        .highlight_style(highlight_style);

    f.render_stateful_widget(list, area, state);
}


