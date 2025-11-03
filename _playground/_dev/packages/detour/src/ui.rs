// UI rendering for detour TUI - Horizontal 3-column layout

use crate::app::{App, ActiveColumn, ViewMode};
use crate::popup;
use crate::diff;
use ratatui::{
    layout::{Alignment, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, Paragraph, BorderType, Clear},
    Frame,
};

fn hex_color(hex: u32) -> Color {
    Color::Rgb(
        ((hex >> 16) & 0xFF) as u8,
        ((hex >> 8) & 0xFF) as u8,
        (hex & 0xFF) as u8,
    )
}

// Universal selection highlighting for all columns
fn get_selection_style(is_active: bool) -> Style {
    if is_active {
        // Cyan when focused
        Style::default()
            .bg(hex_color(0x1A2A2A))  // Dim cyan background
            .fg(Color::Cyan)           // Cyan text
    } else {
        // Grey when not focused (matches Column 1 and 2)
        Style::default()
            .bg(hex_color(0x151515))  // Very subtle highlight
            .fg(hex_color(0x777777))  // Grey text
    }
}

// Accent color moved to form_panel component

pub fn ui(f: &mut Frame, app: &mut App) {
    let area = f.size();
    
    // Background
    f.render_widget(
        Paragraph::new("").style(Style::default().bg(hex_color(0x0A0A0A))),
        area
    );
    
    // Check minimum size
    if area.width < 120 || area.height < 16 {
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
    
    // No global overlay; dimming handled by widgets based on is_modal_visible()

    // Draw validation report (overlays everything except popup and file browser)
    if let Some(report) = &app.validation_report {
        draw_validation_report(f, area, report);
    }
    
    // Draw diff viewer (overlays everything except popup and validation report)
    if let Some(diff) = &app.diff_viewer {
        diff::draw_diff(f, area, diff);
    }
    
    // Draw popup last (overlays everything)
    if let Some(popup) = &app.popup {
        popup::draw_popup(f, area, popup);
    }
    
    // Draw file browser (overlays everything)
    if let Some(browser) = &mut app.file_browser {
        let browser_area = centered_rect(70, 88, area);
        browser.render(f, area, browser_area);
    }
}

// Helper function to create a centered rectangle
fn draw_toasts(f: &mut Frame, area: Rect, app: &crate::app::App) {
    use crate::app::ToastType;
    
    if app.toasts.is_empty() {
        return;
    }
    
    // Calculate the maximum width of all toasts
    let mut max_width = 0usize;
    let mut toast_data: Vec<(String, Color, String)> = Vec::new();
    
    for toast in &app.toasts {
        let (icon, fg_color) = match toast.toast_type {
            ToastType::Success => ("✓", Color::Green),
            ToastType::Error => ("✗", Color::Red),
            ToastType::Info => ("ℹ", Color::Cyan),
        };
        
        let content = format!("{} {}", icon, toast.message);
        max_width = max_width.max(content.len());
        toast_data.push((content, fg_color, icon.to_string()));
    }
    
    // Add 3 spaces total for padding (2 on left, 1 on right minimum)
    max_width += 3;
    
    // Position offsets: start 1 line lower (down), very close to right edge
    let y_start_offset = 1u16;  // Move down (add to y)
    let x_padding_from_edge = 0u16;  // Right at the edge
    
    // Start from the bottom, going up
    let mut y_offset = 0u16;
    
    for (content, fg_color, _) in toast_data.iter().rev() {
        // Left-pad content to match max width, ensuring 2 col minimum left padding
        // The format adds 1 space on the right
        let content_len = content.len();
        let left_padding = max_width.saturating_sub(content_len).saturating_sub(1).max(2);
        
        // Ensure the text exactly fills the width
        let mut padded_text = format!("{}{} ", " ".repeat(left_padding), content);
        
        // Pad to exact width if needed
        while padded_text.len() < max_width {
            padded_text.push(' ');
        }
        // Trim if too long
        if padded_text.len() > max_width {
            padded_text.truncate(max_width);
        }
        
        let toast_height = 1u16;
        
        // Position on bottom right with offsets
        let toast_area = Rect {
            x: area.width.saturating_sub(max_width as u16 + x_padding_from_edge),
            y: (area.y + y_start_offset).saturating_sub(y_offset + toast_height),
            width: max_width as u16,
            height: toast_height,
        };
        
        // Clear the area first to prevent color bleeding
        f.render_widget(Clear, toast_area);
        
        // Render with background covering the entire width
        let toast_widget = Paragraph::new(padded_text)
            .style(Style::default()
                .fg(*fg_color)
                .bg(hex_color(0x0A0A0A))  // Match UI background
                .add_modifier(Modifier::BOLD));
        
        f.render_widget(toast_widget, toast_area);
        
        y_offset += toast_height;  // No gap between toasts
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

//

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
    
    let message = "Terminal too small! Minimum: 120x16";
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
    let modal_visible = app.is_modal_visible();
    
    let title_text = format!(
        " Detour  |  Profile: {}  |  {} active  |  Status: {} ",
        app.profile,
        app.active_detours_count(),
        app.status_icon()
    );
    
    let border_color = if modal_visible {
        hex_color(0x222222)
    } else {
        hex_color(0x666666)
    };
    let text_color = if modal_visible {
        hex_color(0x444444)
    } else {
        hex_color(0xBBBBBB)
    };
    
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
    let modal_visible = app.is_modal_visible();
    let is_active = app.active_column == ActiveColumn::Views && !modal_visible;
    
    let border_style = if modal_visible {
        Style::default().fg(hex_color(0x222222)) // Dimmed when modal visible
    } else if is_active {
        Style::default().fg(Color::White)
    } else {
        Style::default().fg(hex_color(0x333333))
    };
    let border_type = if is_active { BorderType::Thick } else { BorderType::Plain };
    let text_color = if modal_visible {
        hex_color(0x444444) // Dimmed when modal visible
    } else if is_active {
        hex_color(0xFFFFFF)
    } else {
        hex_color(0x777777)
    };
    
    // All views have associated panels, so all get arrows with proper padding
    let max_width = app.views.iter().map(|v| v.len()).max().unwrap_or(8);
    let items: Vec<ListItem> = app.views.iter().map(|view| {
        let padding = max_width - view.len();
        let display = format!(" {}{} ► ", view, " ".repeat(padding));
        ListItem::new(display).style(Style::default().fg(text_color))
    }).collect();
    
    let mut state = app.view_state.clone();
    
    // When modal is visible, use the dimmed inactive style
    let highlight_style = if modal_visible {
        Style::default()
            .bg(hex_color(0x0D0D0D))  // Nearly invisible highlight
            .fg(hex_color(0x444444))  // Dimmed grey text
    } else {
        get_selection_style(is_active)
    };
    
    let list = List::new(items)
        .block(Block::default()
            .borders(Borders::ALL)
            .border_type(border_type)
            .border_style(border_style))
        .highlight_style(highlight_style);
    
    f.render_stateful_widget(list, area, &mut state);
}

fn draw_action_column(f: &mut Frame, area: Rect, app: &mut App) {
    let modal_visible = app.is_modal_visible();
    let actions = app.get_current_actions();
    let is_active = app.active_column == ActiveColumn::Actions && !modal_visible;
    
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
    
    // Actions that open sub-panels get arrows with proper padding
    let max_width = actions.iter().map(|a| a.len()).max().unwrap_or(15);
    let items: Vec<ListItem> = actions.iter().map(|action| {
        let has_subpanel = matches!(action.as_str(),
            "List" | "Add" | "Edit" | "Add Include" | "Export"
        );
        let padding = max_width - action.len();
        let display = if has_subpanel {
            format!(" {}{} ► ", action, " ".repeat(padding))
        } else {
            format!(" {}{}", action, " ".repeat(padding))
        };
        ListItem::new(display).style(Style::default().fg(text_color))
    }).collect();
    
    // Selection in column 2 uses subtle cyan highlight, no arrow indicator
    let mut state = app.action_state.clone();
    
    // When modal is visible, use the dimmed inactive style
    let highlight_style = if modal_visible {
        Style::default()
            .bg(hex_color(0x0D0D0D))  // Nearly invisible highlight
            .fg(hex_color(0x444444))  // Dimmed grey text
    } else {
        get_selection_style(is_active)
    };
    
    let list = List::new(items)
        .block(Block::default()
            .borders(Borders::ALL)
            .border_type(border_type)
            .border_style(border_style))
        .highlight_style(highlight_style)
        .highlight_symbol("");  // Empty string = no arrow indicator
    
    f.render_stateful_widget(list, area, &mut state);
}

fn draw_content_column(f: &mut Frame, area: Rect, app: &mut App) {
    let modal_visible = app.is_modal_visible();
    
    // Determine what to render based on active column and selection
    let current_view_mode = app.view_mode;
    let mode_to_render = match app.active_column {
        crate::app::ActiveColumn::Views => {
            // Column 1 (Views) is active - show preview based on selected view
            // Use helper to map index to ViewMode (matches app.rs logic)
            use crate::app::App;
            App::view_mode_from_index(app.selected_view)
        }
        crate::app::ActiveColumn::Actions => {
            // Column 2 (Actions) is active - show preview based on selected action
            let actions = app.get_current_actions();
            if let Some(selected_action) = actions.get(app.selected_action) {
                match selected_action.as_str() {
                    "List" => current_view_mode,  // Show the list view
                    "Verify All" | "Activate All" => {
                        // For other actions, show the list view
                        match current_view_mode {
                            ViewMode::DetoursList => ViewMode::DetoursList,
                            ViewMode::InjectionsList => ViewMode::InjectionsList,
                            ViewMode::MirrorsList => ViewMode::MirrorsList,
                            ViewMode::ServicesList => ViewMode::ServicesList,
                            _ => current_view_mode,
                        }
                    }
                    _ => current_view_mode,
                }
            } else {
                current_view_mode
            }
        }
        _ => current_view_mode,  // Column 3 (Content) or other - use current view mode
    };
    
    // Render based on the determined mode
    match mode_to_render {
        ViewMode::DetoursList => draw_detours_list(f, area, app, modal_visible),
        ViewMode::DetoursAdd => draw_detours_add(f, area, app, modal_visible),
        ViewMode::DetoursEdit => draw_detours_edit(f, area, app, modal_visible),
        ViewMode::InjectionsAdd => draw_injections_add(f, area, app, modal_visible),
        ViewMode::InjectionsList => draw_injections_list(f, area, app, modal_visible),
        ViewMode::MirrorsList => draw_mirrors_list(f, area, app, modal_visible),
        ViewMode::MirrorsAdd => draw_mirrors_add(f, area, app, modal_visible),
        ViewMode::MirrorsEdit => draw_mirrors_edit(f, area, app, modal_visible),
        ViewMode::ServicesList => draw_services_list(f, area, app, modal_visible),
        ViewMode::StatusOverview => draw_status_overview(f, area, app, modal_visible),
        ViewMode::LogsLive => draw_logs_live(f, area, app, modal_visible),
        ViewMode::ConfigEdit => draw_config_edit(f, area, app),
    }
}

fn draw_detours_list(f: &mut Frame, area: Rect, app: &mut App, modal_visible: bool) {
    let is_active = app.active_column == ActiveColumn::Content && !modal_visible;
    let items: Vec<crate::components::list_panel::ItemRow> = if app.detours.is_empty() {
        vec![]
    } else {
        app.detours.iter().map(|detour| {
            let size_str = detour.size_display();
            let status_text = detour.status_text();
            crate::components::list_panel::ItemRow {
                line1: format!("{} {} ← {}", 
                    if detour.active { "✓" } else { "○" },
                    detour.original,
                    detour.custom
                ),
                line2: Some(format!("   📝 {}  |  📏 {}  |  {}", 
                    detour.modified_ago(),
                    size_str,
                    status_text
                )),
                status_icon: Some(if detour.active { "✓".to_string() } else { "○".to_string() }),
            }
        }).collect()
    };

    crate::components::list_panel::draw_list_panel(
        f,
        area,
        &format!(" Detours ({}) ", app.detours.len()),
        &items,
        &mut app.detour_state,
        is_active,
        modal_visible,
        &crate::components::list_panel::ListPanelTheme::default(),
    );
}

fn draw_detours_add(f: &mut Frame, area: Rect, app: &App, modal_visible: bool) {
    let is_active = app.active_column == ActiveColumn::Content && !modal_visible;
    let fields = vec![
        crate::components::form_panel::FormField { label: "Original Path:".to_string(), value: app.add_form.original_path.clone(), placeholder: "/path/to/original/file".to_string() },
        crate::components::form_panel::FormField { label: "Custom Path:".to_string(), value: app.add_form.custom_path.clone(), placeholder: "/path/to/custom/file".to_string() },
        crate::components::form_panel::FormField { label: "Description (optional):".to_string(), value: app.add_form.description.clone(), placeholder: "Brief description of this detour".to_string() },
    ];
    let state = crate::components::form_panel::FormState { active_field: app.add_form.active_field, cursor_pos: app.add_form.cursor_pos };
    let title = if app.add_form.editing_index.is_some() {
        " Edit Detour "
    } else {
        " Add New Detour "
    };
    crate::components::form_panel::draw_form_panel(
        f,
        area,
        title,
        &fields,
        &state,
        is_active,
        modal_visible,
    );
}

fn draw_detours_edit(f: &mut Frame, area: Rect, app: &App, modal_visible: bool) {
    // Reuse the same form component, title will be set based on editing_index
    draw_detours_add(f, area, app, modal_visible);
}

fn draw_injections_add(f: &mut Frame, area: Rect, app: &App, modal_visible: bool) {
    let is_active = app.active_column == ActiveColumn::Content && !modal_visible;
    let fields = vec![
        crate::components::form_panel::FormField { label: "Target Path:".to_string(), value: app.injection_form.target_path.clone(), placeholder: "/path/to/target".to_string() },
        crate::components::form_panel::FormField { label: "Injection File:".to_string(), value: app.injection_form.include_path.clone(), placeholder: "/path/to/injection.yaml".to_string() },
        crate::components::form_panel::FormField { label: "Description (optional):".to_string(), value: app.injection_form.description.clone(), placeholder: "Brief description of this injection".to_string() },
    ];
    let state = crate::components::form_panel::FormState { active_field: app.injection_form.active_field, cursor_pos: app.injection_form.cursor_pos };
    let title = if app.injection_form.editing_index.is_some() {
        " Edit Injection "
    } else {
        " Add Injection "
    };
    crate::components::form_panel::draw_form_panel(
        f,
        area,
        title,
        &fields,
        &state,
        is_active,
        modal_visible,
    );
}

fn draw_injections_list(f: &mut Frame, area: Rect, app: &mut App, modal_visible: bool) {
    let is_active = app.active_column == ActiveColumn::Content && !modal_visible;
    let items: Vec<crate::components::list_panel::ItemRow> = if app.injections.is_empty() {
        vec![]
    } else {
        app.injections.iter().map(|inc| {
            // Use cached values (only updated on reload)
            let size_str = if inc.size > 1024 * 1024 {
                format!("{:.1} MB", inc.size as f64 / 1024.0 / 1024.0)
            } else if inc.size > 1024 {
                format!("{:.1} KB", inc.size as f64 / 1024.0)
            } else {
                format!("{} B", inc.size)
            };
            let status_text = if inc.active { "✓ Active" } else { "○ Inactive" };
            crate::components::list_panel::ItemRow {
                line1: format!("{} ← {}", inc.target, inc.include_file),
                line2: Some(format!("   📝 {}  |  📏 {}  |  {}", inc.modified, size_str, status_text)),
                status_icon: Some(if inc.active { "✓".to_string() } else { "○".to_string() }),
            }
        }).collect()
    };

    crate::components::list_panel::draw_list_panel(
        f,
        area,
        &format!(" Injections ({}) ", app.injections.len()),
        &items,
        &mut app.injection_state,
        is_active,
        modal_visible,
        &crate::components::list_panel::ListPanelTheme::default(),
    );
}

fn draw_mirrors_list(f: &mut Frame, area: Rect, app: &mut App, modal_visible: bool) {
    let is_active = app.active_column == ActiveColumn::Content && !modal_visible;
    let items: Vec<crate::components::list_panel::ItemRow> = if app.mirrors.is_empty() {
        vec![]
    } else {
        app.mirrors.iter().map(|mirror| {
            let size_str = if mirror.size > 1024 * 1024 {
                format!("{:.1} MB", mirror.size as f64 / 1024.0 / 1024.0)
            } else if mirror.size > 1024 {
                format!("{:.1} KB", mirror.size as f64 / 1024.0)
            } else {
                format!("{} B", mirror.size)
            };
            let status_text = if mirror.active { "✓ Active" } else { "○ Inactive" };
            crate::components::list_panel::ItemRow {
                line1: format!("{} {} → {}", 
                    if mirror.active { "✓" } else { "○" },
                    mirror.source,
                    mirror.target
                ),
                line2: Some(format!("   📝 {}  |  📏 {}  |  {}", mirror.modified, size_str, status_text)),
                status_icon: Some(if mirror.active { "✓".to_string() } else { "○".to_string() }),
            }
        }).collect()
    };

    crate::components::list_panel::draw_list_panel(
        f,
        area,
        &format!(" Mirrors ({}) ", app.mirrors.len()),
        &items,
        &mut app.mirror_state,
        is_active,
        modal_visible,
        &crate::components::list_panel::ListPanelTheme::default(),
    );
}

fn draw_mirrors_add(f: &mut Frame, area: Rect, app: &App, modal_visible: bool) {
    let is_active = app.active_column == ActiveColumn::Content && !modal_visible;
    let fields = vec![
        crate::components::form_panel::FormField { label: "Source Path:".to_string(), value: app.mirror_form.source_path.clone(), placeholder: "/home/pi/_playground/path/to/source".to_string() },
        crate::components::form_panel::FormField { label: "Target Path:".to_string(), value: app.mirror_form.target_path.clone(), placeholder: "/path/to/target/symlink".to_string() },
        crate::components::form_panel::FormField { label: "Description:".to_string(), value: app.mirror_form.description.clone(), placeholder: "Optional description".to_string() },
    ];
    let state = crate::components::form_panel::FormState { 
        active_field: app.mirror_form.active_field, 
        cursor_pos: app.mirror_form.cursor_pos 
    };
    
    crate::components::form_panel::draw_form_panel(
        f,
        area,
        " Add Mirror ",
        &fields,
        &state,
        is_active,
        modal_visible,
    );
}

fn draw_mirrors_edit(f: &mut Frame, area: Rect, app: &App, modal_visible: bool) {
    let is_active = app.active_column == ActiveColumn::Content && !modal_visible;
    let fields = vec![
        crate::components::form_panel::FormField { label: "Source Path:".to_string(), value: app.mirror_form.source_path.clone(), placeholder: "/home/pi/_playground/path/to/source".to_string() },
        crate::components::form_panel::FormField { label: "Target Path:".to_string(), value: app.mirror_form.target_path.clone(), placeholder: "/path/to/target/symlink".to_string() },
        crate::components::form_panel::FormField { label: "Description:".to_string(), value: app.mirror_form.description.clone(), placeholder: "Optional description".to_string() },
    ];
    let state = crate::components::form_panel::FormState { 
        active_field: app.mirror_form.active_field, 
        cursor_pos: app.mirror_form.cursor_pos 
    };
    
    crate::components::form_panel::draw_form_panel(
        f,
        area,
        " Edit Mirror ",
        &fields,
        &state,
        is_active,
        modal_visible,
    );
}

fn draw_services_list(f: &mut Frame, area: Rect, app: &mut App, modal_visible: bool) {
    let is_active = app.active_column == ActiveColumn::Content && !modal_visible;
    
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
    
    let title = Span::styled(
        format!(" Services ({}) ", app.services.len()),
        Style::default().fg(if is_active { Color::Cyan } else { text_color })
    );
    
    let items: Vec<ListItem> = if app.services.is_empty() {
        vec![ListItem::new(" No services configured").style(Style::default().fg(Color::DarkGray))]
    } else {
        app.services.iter().map(|service| {
            let line1 = format!("{} → {}", service.name, service.action);
            let line2 = format!("   Status: {}", service.status);
            ListItem::new(vec![
                Line::from(line1),
                Line::from(Span::styled(line2, Style::default().fg(hex_color(0x888888)))),
            ]).style(Style::default().fg(text_color))
        }).collect()
    };
    
    let highlight_style = if modal_visible {
        Style::default()
            .bg(hex_color(0x0D0D0D))
            .fg(hex_color(0x444444))
    } else {
        get_selection_style(is_active)
    };
    
    let list = List::new(items)
        .block(Block::default()
            .title(title)
            .borders(Borders::ALL)
            .border_type(border_type)
            .border_style(border_style))
        .highlight_style(highlight_style);
    
    f.render_stateful_widget(list, area, &mut app.service_state);
}

fn draw_status_overview(f: &mut Frame, area: Rect, app: &App, modal_visible: bool) {
    let border_color = if modal_visible {
        hex_color(0x222222)
    } else {
        Color::White
    };
    
    let block = Block::default()
        .title(" System Status ")
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(border_color));
    
    f.render_widget(block, area);
    
    let content_area = Rect {
        x: area.x + 2,
        y: area.y + 2,
        width: area.width.saturating_sub(4),
        height: area.height.saturating_sub(4),
    };
    
    let active_count = app.detours.iter().filter(|d| d.active).count();
    let total_count = app.detours.len();
    let injection_count = app.injections.iter().filter(|i| i.active).count();
    let service_count = app.services.len();
    
    let overall_status = if active_count == total_count && total_count > 0 {
        ("✓ All Active", Color::Green)
    } else if active_count > 0 {
        ("⚠ Partial", Color::Yellow)
    } else {
        ("○ None Active", Color::DarkGray)
    };
    
    let lines = vec![
        Line::from(vec![
            Span::styled("Overall: ", Style::default().fg(hex_color(0x888888))),
            Span::styled(overall_status.0, Style::default().fg(overall_status.1).add_modifier(Modifier::BOLD)),
        ]),
        Line::from(""),
        Line::from(vec![
            Span::styled("Detours:  ", Style::default().fg(hex_color(0x888888))),
            Span::styled(format!("{}/{} active", active_count, total_count), Style::default().fg(Color::White)),
        ]),
        Line::from(vec![
            Span::styled("Injections: ", Style::default().fg(hex_color(0x888888))),
            Span::styled(format!("{} active", injection_count), Style::default().fg(Color::White)),
        ]),
        Line::from(vec![
            Span::styled("Services: ", Style::default().fg(hex_color(0x888888))),
            Span::styled(format!("{} configured", service_count), Style::default().fg(Color::White)),
        ]),
        Line::from(""),
        Line::from(vec![
            Span::styled("Profile:  ", Style::default().fg(hex_color(0x888888))),
            Span::styled(&app.profile, Style::default().fg(Color::Cyan)),
        ]),
        Line::from(vec![
            Span::styled("Config:   ", Style::default().fg(hex_color(0x888888))),
            Span::styled(&app.config_path, Style::default().fg(hex_color(0x666666))),
        ]),
    ];
    
    let paragraph = Paragraph::new(lines);
    f.render_widget(paragraph, content_area);
}

fn draw_logs_live(f: &mut Frame, area: Rect, app: &App, modal_visible: bool) {
    let border_color = if modal_visible {
        hex_color(0x222222)
    } else {
        Color::White
    };
    
    let block = Block::default()
        .title(format!(" Logs ({}) ", app.logs.len()))
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(border_color));
    
    f.render_widget(block, area);
    
    let content_area = Rect {
        x: area.x + 1,
        y: area.y + 1,
        width: area.width.saturating_sub(2),
        height: area.height.saturating_sub(2),
    };
    
    if app.logs.is_empty() {
        let message = Paragraph::new(" No logs yet")
            .style(Style::default().fg(Color::DarkGray));
        f.render_widget(message, content_area);
    } else {
        // Show last N logs that fit in the area
        let max_logs = content_area.height as usize;
        let start_idx = if app.logs.len() > max_logs {
            app.logs.len() - max_logs
        } else {
            0
        };
        
        let log_lines: Vec<Line> = app.logs[start_idx..].iter().map(|log| {
            let level_color = match log.level.as_str() {
                "ERROR" => Color::Red,
                "WARN" => Color::Yellow,
                "SUCCESS" => Color::Green,
                _ => hex_color(0x888888),
            };
            
            Line::from(vec![
                Span::styled(&log.timestamp, Style::default().fg(hex_color(0x666666))),
                Span::raw(" "),
                Span::styled(format!("[{}]", log.level), Style::default().fg(level_color)),
                Span::raw(" "),
                Span::styled(&log.message, Style::default().fg(Color::White)),
            ])
        }).collect();
        
        let paragraph = Paragraph::new(log_lines);
        f.render_widget(paragraph, content_area);
    }
}

fn draw_config_edit(f: &mut Frame, area: Rect, app: &App) {
    let modal_visible = app.is_modal_visible();
    let border_color = if modal_visible {
        hex_color(0x222222)
    } else {
        Color::White
    };
    
    let block = Block::default()
        .title(format!(" Configuration - {} ", app.config_path))
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(border_color));
    
    f.render_widget(block, area);
    
    let content_area = Rect {
        x: area.x + 2,
        y: area.y + 2,
        width: area.width.saturating_sub(4),
        height: area.height.saturating_sub(4),
    };
    
    // Read config file and display
    let config_content = std::fs::read_to_string(&app.config_path)
        .unwrap_or_else(|_| "# Config file not found\n# Create ~/.detour.conf to get started".to_string());
    
    let lines: Vec<Line> = config_content.lines()
        .take(content_area.height as usize)
        .enumerate()
        .map(|(idx, line)| {
            let line_num = format!("{:>4} │ ", idx + 1);
            let color = if line.trim().starts_with('#') {
                hex_color(0x666666)
            } else if line.trim().starts_with("detour ") {
                Color::Cyan
            } else if line.trim().starts_with("include ") {
                Color::Green
            } else if line.trim().starts_with("service ") {
                Color::Yellow
            } else {
                Color::White
            };
            
            Line::from(vec![
                Span::styled(line_num, Style::default().fg(hex_color(0x444444))),
                Span::styled(line, Style::default().fg(color)),
            ])
        }).collect();
    
    let paragraph = Paragraph::new(lines);
    f.render_widget(paragraph, content_area);
}

fn draw_validation_report(f: &mut Frame, area: Rect, report: &crate::app::ValidationReport) {
    use ratatui::layout::{Constraint, Direction, Layout};
    
    // Create centered panel (80% width, ~89% height - one more line at bottom)
    let popup_layout = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Percentage(6),
            Constraint::Percentage(89),
            Constraint::Percentage(5),
        ])
        .split(area);
    
    let popup_area = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage(10),
            Constraint::Percentage(80),
            Constraint::Percentage(10),
        ])
        .split(popup_layout[1])[1];
    
    // Clear the area
    f.render_widget(Clear, popup_area);
    
    // Title and border color based on issues
    let (title, border_color) = if report.has_issues {
        (" Validation Issues Found ", Color::Red)
    } else {
        (" Validation Passed ✓ ", Color::Green)
    };
    
    // Create bordered block with double border
    let block = Block::default()
        .title(title)
        .title_alignment(Alignment::Center)
        .borders(Borders::ALL)
        .border_type(BorderType::Double)
        .border_style(Style::default().fg(border_color));
    
    let inner_area = block.inner(popup_area);
    f.render_widget(block, popup_area);
    
    // Add 1 column padding on left and right
    let padded_area = Rect {
        x: inner_area.x + 1,
        y: inner_area.y,
        width: inner_area.width.saturating_sub(2),
        height: inner_area.height,
    };
    
    // Render content
    let paragraph = Paragraph::new(report.content.clone())
        .style(Style::default().fg(Color::White))
        .alignment(Alignment::Left);
    
    f.render_widget(paragraph, padded_area);
    
    // Help text at bottom
    let help_text = " Press [Enter] to close ";
    let help_area = Rect {
        x: popup_area.x + (popup_area.width.saturating_sub(help_text.len() as u16)) / 2,
        y: popup_area.y + popup_area.height.saturating_sub(1),
        width: help_text.len() as u16,
        height: 1,
    };
    
    let help_widget = Paragraph::new(help_text)
        .style(Style::default().fg(Color::DarkGray));
    
    f.render_widget(help_widget, help_area);
}

fn get_panel_help(app: &App) -> String {
    match app.view_mode {
        ViewMode::DetoursList => {
            match app.active_column {
                ActiveColumn::Views => "[n] New  [v] Verify All  [a] Activate All".to_string(),
                ActiveColumn::Actions => "[n] New  [v] Verify All  [a] Activate All".to_string(),
                ActiveColumn::Content => "[Space] Toggle  [n] New  [e] Edit  [Del] Remove  [d] Diff  [v] Verify".to_string(),
            }
        }
        ViewMode::InjectionsList => {
            match app.active_column {
                ActiveColumn::Views => "[n] New".to_string(),
                ActiveColumn::Actions => "[n] New".to_string(),
                ActiveColumn::Content => "[Space] Toggle  [n] New  [e] Edit  [Del] Remove  [v] Verify".to_string(),
            }
        }
        ViewMode::MirrorsList => {
            match app.active_column {
                ActiveColumn::Views => "[n] New".to_string(),
                ActiveColumn::Actions => "[n] New".to_string(),
                ActiveColumn::Content => "[Space] Toggle  [n] New  [e] Edit  [Del] Remove".to_string(),
            }
        }
        ViewMode::MirrorsAdd | ViewMode::MirrorsEdit => {
            "[Esc] Cancel  [Enter] Save  [Tab] Complete  [Ctrl+F] Browse  [Ctrl+V] Paste".to_string()
        }
        ViewMode::ServicesList => {
            "[Enter] Manage  [r] Reload".to_string()
        }
        ViewMode::LogsLive => {
            "[c] Clear  [s] Save".to_string()
        }
        ViewMode::ConfigEdit => {
            "[r] Reload  [v] Validate".to_string()
        }
        ViewMode::StatusOverview => {
            "[s] Stop All".to_string()
        }
        ViewMode::DetoursAdd | ViewMode::DetoursEdit => {
            "[Tab] Next Field  [Ctrl+F] Browse  [Ctrl+V] Paste  [Enter] Save  [Esc] Cancel".to_string()
        }
        ViewMode::InjectionsAdd => {
            "[Tab] Complete  [Ctrl+F] Browse  [Ctrl+V] Paste  [Enter] Save  [Esc] Cancel".to_string()
        }
    }
}

fn draw_bottom_status(f: &mut Frame, area: Rect, app: &App) {
    let modal_visible = app.is_modal_visible();
    
    // Draw toast notifications stacked on bottom right
    draw_toasts(f, area, app);
    
    // Line 1: Global (grey) + Panel-specific (white) bindings
    let global_text = "[↑↓←→] Navigate  [Ctrl+R] Refresh  [q] Quit  [?] Help";
    let edit_config_text = "[Ctrl+E] Edit Config";
    let panel_text = get_panel_help(app);
    let spans = vec![
        Span::styled(global_text, Style::default().fg(if modal_visible { hex_color(0x333333) } else { hex_color(0x777777) })),
        Span::raw("  "),
        Span::styled(edit_config_text, Style::default().fg(if modal_visible { hex_color(0x222222) } else { hex_color(0x555555) })),
        Span::raw("  "),
        Span::styled(panel_text, Style::default().fg(if modal_visible { hex_color(0x444444) } else { Color::White })),
    ];
    let nav_paragraph = Paragraph::new(Line::from(spans));
    f.render_widget(nav_paragraph, Rect { x: area.x, y: area.y + 1, width: area.width, height: 1 });
    
    // Line 2: Horizontal divider
    let divider_line = "─".repeat(area.width as usize);
    let divider_color = if modal_visible {
        hex_color(0x222222)
    } else {
        Color::White
    };
    let divider_paragraph = Paragraph::new(divider_line)
        .style(Style::default().fg(divider_color));
    f.render_widget(divider_paragraph, Rect {
        x: area.x,
        y: area.y + 2,
        width: area.width,
        height: 1,
    });
    
    // Line 3: Dynamic description
    let description = app.get_current_description();
    let desc_line = format!(" {:<width$} ", description, width = area.width as usize - 2);
    let desc_color = if modal_visible {
        hex_color(0x333333)
    } else {
        Color::White
    };
    let desc_paragraph = Paragraph::new(desc_line)
        .style(Style::default().fg(desc_color));
    f.render_widget(desc_paragraph, Rect {
        x: area.x,
        y: area.y + 3,
        width: area.width,
        height: 1,
    });
}

