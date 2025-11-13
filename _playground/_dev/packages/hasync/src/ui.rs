// UI rendering for hasync TUI - Horizontal 3-column layout

use crate::app::{App, ActiveColumn, ViewMode};
use crate::popup;
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
    // For ScriptsList view, column 2 shows scripts, so calculate width based on scripts
    let col2_width = if app.view_mode == ViewMode::ScriptsList {
        calculate_scripts_width(app)
    } else {
        calculate_action_width(app)
    };
    
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
    
    // Bottom status area (5 lines high)
    let status_area = Rect {
        x: area.x,
        y: area.y + area.height.saturating_sub(5),
        width: area.width,
        height: 5,
    };
    draw_bottom_status(f, status_area, app);
    
    // Render modals/overlays
    if let Some(popup) = &app.popup {
        popup::draw_popup(f, area, popup);
    }
    
    if app.file_browser.is_some() {
        // File browser rendering (if needed)
    }
    
    // Render toasts (simple rendering at bottom right)
    if !app.toasts.is_empty() {
        draw_toasts(f, area, &app.toasts);
    }
}

fn draw_minimal_ui(f: &mut Frame, _app: &mut App) {
    let area = f.size();
    
    let size_text = format!("Terminal too small: {}x{} (min: 120x16)", area.width, area.height);
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
    
    // Build dynamic title with status information
    let dashboards_count = app.dashboards.len();
    let scripts_count = app.scripts.len();
    let synced_dashboards = app.dashboards.iter().filter(|d| {
        matches!(d.sync_status.status, crate::sync::FileStatus::Synced)
    }).count();
    let synced_scripts = app.scripts.iter().filter(|s| {
        matches!(s.sync_status.status, crate::sync::FileStatus::Synced)
    }).count();
    
    let title_text = format!(
        " hasync  |  Dashboards: {}/{} synced  |  Scripts: {}/{} synced  |  Status: {} ",
        synced_dashboards,
        dashboards_count,
        synced_scripts,
        scripts_count,
        if synced_dashboards == dashboards_count && synced_scripts == scripts_count {
            "✓ All synced"
        } else {
            "⚠ Needs sync"
        }
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

fn calculate_scripts_width(app: &App) -> u16 {
    // Calculate width based on longest script name (without "Home Assistant Scripts" prefix)
    let max_len = app.scripts
        .iter()
        .map(|s| {
            let replaced = s.name.replace("Home Assistant Scripts", "");
            let trimmed = replaced.trim();
            let display_name_len = if trimmed.is_empty() {
                s.name.len()
            } else {
                trimmed.len()
            };
            display_name_len + 4 // +4 for status icon and spacing (" ✔ name")
        })
        .max()
        .unwrap_or(20);
    (max_len + 6) as u16 // +2 padding, +2 borders, +2 margin
}

fn draw_view_column(f: &mut Frame, area: Rect, app: &mut App) {
    let modal_visible = app.is_modal_visible();
    let is_active = app.active_column == ActiveColumn::Views && !modal_visible;
    
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
    
    let items: Vec<ListItem> = app.views.iter().map(|view| {
        ListItem::new(format!(" {}", view)).style(Style::default().fg(text_color))
    }).collect();
    
    let highlight_style = if modal_visible {
        Style::default()
            .bg(hex_color(0x0D0D0D))
            .fg(hex_color(0x444444))
    } else {
        get_selection_style(is_active)
    };
    
    let list = List::new(items)
        .block(Block::default()
            .borders(Borders::ALL)
            .border_type(border_type)
            .border_style(border_style))
        .highlight_style(highlight_style);
    
    f.render_stateful_widget(list, area, &mut app.view_state);
}

fn draw_action_column(f: &mut Frame, area: Rect, app: &mut App) {
    let modal_visible = app.is_modal_visible();
    let is_active = app.active_column == ActiveColumn::Actions && !modal_visible;
    
    // For ScriptsList view, show scripts instead of actions
    if app.view_mode == ViewMode::ScriptsList {
        draw_scripts_action_column(f, area, app, modal_visible, is_active);
        return;
    }
    
    // Default: show actions
    let actions = app.get_current_actions();
    
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
            "List" | "Sync YAML→JSON" | "Sync JSON→YAML" | "Check Status" | "Show Diff"
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
    
    f.render_stateful_widget(list, area, &mut app.action_state);
}

fn draw_scripts_action_column(f: &mut Frame, area: Rect, app: &mut App, modal_visible: bool, is_active: bool) {
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
    
    // Collect all files from all scripts with their script context
    #[derive(Clone)]
    struct FileWithScript {
        script_name: String,
        script_index: usize,
        file: crate::app::ScriptFileInfo,
    }
    
    let mut all_files: Vec<FileWithScript> = Vec::new();
    for (script_idx, script) in app.scripts.iter().enumerate() {
        for file in &script.files {
            // Extract script name without "Home Assistant Scripts" prefix for display
            let replaced = script.name.replace("Home Assistant Scripts", "");
            let trimmed = replaced.trim();
            let script_display_name = if trimmed.is_empty() {
                script.name.clone()
            } else {
                trimmed.to_string()
            };
            
            all_files.push(FileWithScript {
                script_name: script_display_name,
                script_index: script_idx,
                file: file.clone(),
            });
        }
    }
    
    // Sort files by script name, then by file name
    all_files.sort_by(|a, b| {
        a.script_name.cmp(&b.script_name)
            .then_with(|| a.file.name.cmp(&b.file.name))
    });
    
    // Build file list items with status icons and arrow indicators
    let max_width = all_files.iter().map(|f| f.file.name.len()).max().unwrap_or(20);
    
    let items: Vec<ListItem> = all_files.iter().map(|file_ctx| {
        // Determine status icon and color for this individual file:
        // ✘ (dimmed red) = dest missing (no destination mtime)
        // ✔ (dimmed green) = same timestamp (synced)
        // ⚠ (dimmed yellow) = different timestamps (needs sync)
        let (status_icon, icon_color) = if file_ctx.file.dest_mtime.is_none() {
            ("✘", hex_color(0xAA6666))  // Dimmed red - Destination missing
        } else if file_ctx.file.needs_sync {
            ("⚠", hex_color(0xAAAA66))  // Dimmed yellow - Needs sync
        } else {
            ("✔", hex_color(0x66AA66))  // Dimmed green - Synced
        };
        
        // Add padding and arrow indicator with colored icon
        let padding = max_width.saturating_sub(file_ctx.file.name.len());
        let display = format!(" {} {}{} ► ", status_icon, file_ctx.file.name, " ".repeat(padding));
        
        // Create spans with colored icon
        let mut spans = vec![
            Span::styled(status_icon, Style::default().fg(icon_color)),
            Span::raw(" "),
            Span::styled(&file_ctx.file.name, Style::default().fg(text_color)),
            Span::raw(format!("{} ► ", " ".repeat(padding))),
        ];
        
        ListItem::new(Line::from(spans))
    }).collect();
    
    let highlight_style = if modal_visible {
        Style::default()
            .bg(hex_color(0x0D0D0D))
            .fg(hex_color(0x444444))
    } else {
        get_selection_style(is_active)
    };
    
    let list = List::new(items)
        .block(Block::default()
            .title(" Scripts ")
            .borders(Borders::ALL)
            .border_type(border_type)
            .border_style(border_style))
        .highlight_style(highlight_style)
        .highlight_symbol("");
    
    // Render list with scrolling support
    f.render_stateful_widget(list, area, &mut app.action_state);
}

fn draw_content_column(f: &mut Frame, area: Rect, app: &mut App) {
    let modal_visible = app.is_modal_visible();
    
    // Determine what to render based on active column and selection
    let current_view_mode = app.view_mode;
    let mode_to_render = match app.active_column {
        ActiveColumn::Views => {
            // Column 1 (Views) is active - show preview based on selected view
            App::view_mode_from_index(app.view_state.selected().unwrap_or(0))
        }
        ActiveColumn::Actions => {
            // Column 2 (Actions) is active - show preview based on selected action
            // For now, use current view mode (could be enhanced to show action-specific previews)
            current_view_mode
        }
        ActiveColumn::Content => {
            // Column 3 (Content) is active - always show current view mode content
            current_view_mode
        }
    };
    
    // Default rendering
    match mode_to_render {
        ViewMode::DashboardList => draw_dashboard_list(f, area, app, modal_visible),
        ViewMode::ScriptsList => draw_scripts_list(f, area, app, modal_visible),
        ViewMode::SyncStatus => draw_sync_status(f, area, app, modal_visible),
        ViewMode::SyncHistory => draw_sync_history(f, area, app, modal_visible),
    }
}

fn draw_dashboard_list(f: &mut Frame, area: Rect, app: &mut App, modal_visible: bool) {
    let is_active = app.active_column == ActiveColumn::Content && !modal_visible;
    let items: Vec<crate::components::list_panel::ItemRow> = if app.dashboards.is_empty() {
        vec![]
    } else {
        app.dashboards.iter().map(|dashboard| {
            let status_text = match &dashboard.sync_status.status {
                crate::sync::FileStatus::Synced => "Synced",
                crate::sync::FileStatus::YamlNewer => "YAML newer",
                crate::sync::FileStatus::JsonNewer => "JSON newer",
                crate::sync::FileStatus::Error(_) => "Error",
            };
            
            let yaml_time = dashboard.sync_status.yaml_mtime
                .and_then(|t| {
                    t.duration_since(std::time::UNIX_EPOCH).ok()
                        .and_then(|d| chrono::DateTime::<chrono::Utc>::from_timestamp(d.as_secs() as i64, 0))
                        .map(|dt| dt.with_timezone(&chrono::Local).format("%Y-%m-%d %H:%M:%S").to_string())
                })
                .unwrap_or_else(|| "N/A".to_string());
            
            let json_time = dashboard.sync_status.json_mtime
                .and_then(|t| {
                    t.duration_since(std::time::UNIX_EPOCH).ok()
                        .and_then(|d| chrono::DateTime::<chrono::Utc>::from_timestamp(d.as_secs() as i64, 0))
                        .map(|dt| dt.with_timezone(&chrono::Local).format("%Y-%m-%d %H:%M:%S").to_string())
                })
                .unwrap_or_else(|| "N/A".to_string());
            
            let status_icon = match &dashboard.sync_status.status {
                crate::sync::FileStatus::Synced => Some("✓".to_string()),
                crate::sync::FileStatus::YamlNewer | crate::sync::FileStatus::JsonNewer => Some("⚠".to_string()),
                crate::sync::FileStatus::Error(_) => None,
            };
            
            crate::components::list_panel::ItemRow {
                line1: format!("{}", dashboard.name),
                line2: Some(format!("   Status: {}  |  YAML: {}  |  JSON: {}", 
                    status_text,
                    yaml_time,
                    json_time
                )),
                status_icon,
            }
        }).collect()
    };

    // Update selected_dashboard when content selection changes
    if let Some(selected) = app.content_state.selected() {
        if selected < app.dashboards.len() {
            app.selected_dashboard = Some(selected);
        }
    }
    
    crate::components::list_panel::draw_list_panel(
        f,
        area,
        &format!(" Dashboards ({}) ", app.dashboards.len()),
        &items,
        &mut app.content_state,
        is_active,
        modal_visible,
        &crate::components::list_panel::ListPanelTheme::default(),
    );
}

fn draw_scripts_list(f: &mut Frame, area: Rect, app: &mut App, modal_visible: bool) {
    let is_active = app.active_column == ActiveColumn::Content && !modal_visible;
    
    // Collect all files from all scripts to find the selected one
    #[derive(Clone)]
    struct FileWithScript {
        script_name: String,
        script_index: usize,
        file_index: usize,
        file: crate::app::ScriptFileInfo,
    }
    
    let mut all_files: Vec<FileWithScript> = Vec::new();
    for (script_idx, script) in app.scripts.iter().enumerate() {
        for (file_idx, file) in script.files.iter().enumerate() {
            all_files.push(FileWithScript {
                script_name: script.name.clone(),
                script_index: script_idx,
                file_index: file_idx,
                file: file.clone(),
            });
        }
    }
    
    // Sort files by script name, then by file name (same as Column 2)
    all_files.sort_by(|a, b| {
        a.script_name.cmp(&b.script_name)
            .then_with(|| a.file.name.cmp(&b.file.name))
    });
    
    // Get selected file from action_state (column 2)
    if let Some(selected_file_idx) = app.action_state.selected() {
        if selected_file_idx < all_files.len() {
            let file_ctx = &all_files[selected_file_idx];
            app.selected_script = Some(file_ctx.script_index);
            
            // Show details for the selected file only
            // Pass is_active from Content column active state
            draw_script_file_details(f, area, &file_ctx.file, app, modal_visible, is_active);
            return;
        }
    }
    
    // No file selected in Column 2
    let block = Block::default()
        .title(" Script Details ")
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(if modal_visible { hex_color(0x222222) } else { Color::White }));
    
    f.render_widget(block, area);
    
    let content_area = Rect {
        x: area.x + 2,
        y: area.y + 1,  // No empty line - start right after top border
        width: area.width.saturating_sub(4),
        height: area.height.saturating_sub(2),
    };
    
    let para = Paragraph::new("Select a script file in Column 2 to view details")
        .style(Style::default().fg(Color::DarkGray));
    f.render_widget(para, content_area);
}

fn draw_script_file_details(f: &mut Frame, area: Rect, file: &crate::app::ScriptFileInfo, app: &mut App, modal_visible: bool, is_active: bool) {
    let border_color = if modal_visible {
        hex_color(0x222222)
    } else if is_active {
        Color::White
    } else {
        hex_color(0x333333)
    };
    
    let border_type = if is_active && !modal_visible {
        BorderType::Thick
    } else {
        BorderType::Plain
    };
    
    let block = Block::default()
        .title(" Script Details ")
        .borders(Borders::ALL)
        .border_type(border_type)
        .border_style(Style::default().fg(border_color));
    
    f.render_widget(block, area);
    
    // Content area with single margin from left border, no top margin (y starts at border + 1)
    let content_area = Rect {
        x: area.x + 2,  // Single margin (2 = 1 char border + 1 char margin)
        y: area.y + 1,  // No empty line - start right after top border
        width: area.width.saturating_sub(4),
        height: area.height.saturating_sub(2),  // Only top and bottom borders
    };
    
    // Store path strings - use directory paths from the script, not file paths
    // Get the script this file belongs to
    let script = if let Some(script_idx) = app.selected_script {
        app.scripts.get(script_idx)
    } else {
        None
    };
    
    let source_path_str = script.map(|s| s.source.display().to_string())
        .unwrap_or_else(|| file.source_path.display().to_string());
    let dest_path_str = script.map(|s| s.destination.display().to_string())
        .unwrap_or_else(|| file.dest_path.display().to_string());
    let file_name = file.name.clone();
    
    // Format timestamps
    let source_time = file.source_mtime
        .and_then(|t| {
            t.duration_since(std::time::UNIX_EPOCH).ok()
                .and_then(|d| chrono::DateTime::<chrono::Utc>::from_timestamp(d.as_secs() as i64, 0))
                .map(|dt| dt.with_timezone(&chrono::Local).format("%Y-%m-%d %H:%M:%S").to_string())
        })
        .unwrap_or_else(|| "N/A".to_string());
    
    let dest_time = file.dest_mtime
        .and_then(|t| {
            t.duration_since(std::time::UNIX_EPOCH).ok()
                .and_then(|d| chrono::DateTime::<chrono::Utc>::from_timestamp(d.as_secs() as i64, 0))
                .map(|dt| dt.with_timezone(&chrono::Local).format("%Y-%m-%d %H:%M:%S").to_string())
        })
        .unwrap_or_else(|| "Missing".to_string());
    
    // Build content lines for the selected file
    // Format:
    // Source: {{path of source dir}}
    // - Name: {{filename}}
    // - Timestamp: {{timestamp}}
    // (blank line)
    // Dest: {{path of dest dir}}
    // - Name: {{filename}}
    // - Timestamp: {{timestamp}}
    let lines = vec![
        Line::from(vec![
            Span::styled("Source: ", Style::default().fg(hex_color(0x888888)).add_modifier(Modifier::BOLD)),
            Span::styled(&source_path_str, Style::default().fg(Color::White)),
        ]),
        Line::from(vec![
            Span::raw(" - "),
            Span::styled("Name: ", Style::default().fg(hex_color(0x888888))),
            Span::styled(&file_name, Style::default().fg(Color::White)),
        ]),
        Line::from(vec![
            Span::raw(" - "),
            Span::styled("Timestamp: ", Style::default().fg(hex_color(0x888888))),
            Span::styled(&source_time, Style::default().fg(hex_color(0x666666))),
        ]),
        Line::from(""),  // Blank line between source and dest
        Line::from(vec![
            Span::styled("Dest: ", Style::default().fg(hex_color(0x888888)).add_modifier(Modifier::BOLD)),
            Span::styled(&dest_path_str, Style::default().fg(Color::White)),
        ]),
        Line::from(vec![
            Span::raw(" - "),
            Span::styled("Name: ", Style::default().fg(hex_color(0x888888))),
            Span::styled(&file_name, Style::default().fg(Color::White)),
        ]),
        Line::from(vec![
            Span::raw(" - "),
            Span::styled("Timestamp: ", Style::default().fg(hex_color(0x888888))),
            Span::styled(&dest_time, Style::default().fg(hex_color(0x666666))),
        ]),
    ];
    
    // Only scroll if content exceeds visible area
    let content_height = lines.len() as u16;
    let visible_height = content_area.height;
    let needs_scrolling = content_height > visible_height;
    
    // Store needs_scrolling in app state for event handler
    app.script_details_needs_scrolling = needs_scrolling;
    
    // Create scrollable paragraph (only scroll if needed)
    let scroll = if needs_scrolling {
        app.script_details_scroll
    } else {
        // Reset scroll if all content is visible
        app.script_details_scroll = 0;
        0
    };
    
    let para = Paragraph::new(lines.clone())
        .wrap(ratatui::widgets::Wrap { trim: true })
        .scroll((scroll, 0));
    
    f.render_widget(para, content_area);
    
    // Render scrollbar only if content exceeds area
    if needs_scrolling {
        let max_scroll = (content_height.saturating_sub(visible_height)) as u16;
        let scroll_position = scroll.min(max_scroll);
        
        let mut scroll_state = ratatui::widgets::ScrollbarState::default()
            .content_length(lines.len())
            .position(scroll_position as usize);
        
        let scrollbar = ratatui::widgets::Scrollbar::default()
            .orientation(ratatui::widgets::ScrollbarOrientation::VerticalRight)
            .begin_symbol(Some("↑"))
            .end_symbol(Some("↓"));
        
        f.render_stateful_widget(scrollbar, content_area, &mut scroll_state);
    }
}

fn draw_sync_status(f: &mut Frame, area: Rect, app: &App, modal_visible: bool) {
    let border_color = if modal_visible {
        hex_color(0x222222)
    } else {
        Color::White
    };
    
    let block = Block::default()
        .title(" Sync Status ")
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
    
    if let Some(dashboard_idx) = app.selected_dashboard {
        if let Some(dashboard) = app.dashboards.get(dashboard_idx) {
            // Store path strings to avoid temporary value issues
            let yaml_path_str = dashboard.sync_status.yaml_path.display().to_string();
            let json_path_str = dashboard.sync_status.json_path.display().to_string();
            
            let yaml_time = dashboard.sync_status.yaml_mtime
                .and_then(|t| {
                    t.duration_since(std::time::UNIX_EPOCH).ok()
                        .and_then(|d| chrono::DateTime::<chrono::Utc>::from_timestamp(d.as_secs() as i64, 0))
                        .map(|dt| dt.with_timezone(&chrono::Local).format("%Y-%m-%d %H:%M:%S").to_string())
                })
                .unwrap_or_else(|| "N/A".to_string());
            
            let json_time = dashboard.sync_status.json_mtime
                .and_then(|t| {
                    t.duration_since(std::time::UNIX_EPOCH).ok()
                        .and_then(|d| chrono::DateTime::<chrono::Utc>::from_timestamp(d.as_secs() as i64, 0))
                        .map(|dt| dt.with_timezone(&chrono::Local).format("%Y-%m-%d %H:%M:%S").to_string())
                })
                .unwrap_or_else(|| "N/A".to_string());
            
            let lines = vec![
                Line::from(vec![
                    Span::styled("Dashboard: ", Style::default().fg(hex_color(0x888888))),
                    Span::styled(&dashboard.name, Style::default().fg(Color::White).add_modifier(Modifier::BOLD)),
                ]),
                Line::from(""),
                Line::from(vec![
                    Span::styled("Status: ", Style::default().fg(hex_color(0x888888))),
                    Span::styled(
                        match &dashboard.sync_status.status {
                            crate::sync::FileStatus::Synced => "Synced",
                            crate::sync::FileStatus::YamlNewer => "YAML newer",
                            crate::sync::FileStatus::JsonNewer => "JSON newer",
                            crate::sync::FileStatus::Error(_) => "Error",
                        },
                        Style::default().fg(Color::Green)
                    ),
                ]),
                Line::from(""),
                Line::from(vec![
                    Span::styled("YAML: ", Style::default().fg(hex_color(0x888888))),
                    Span::styled(&yaml_path_str, Style::default().fg(Color::White)),
                ]),
                Line::from(vec![
                    Span::styled("      ", Style::default().fg(hex_color(0x888888))),
                    Span::styled(&yaml_time, Style::default().fg(hex_color(0x666666))),
                ]),
                Line::from(""),
                Line::from(vec![
                    Span::styled("JSON: ", Style::default().fg(hex_color(0x888888))),
                    Span::styled(&json_path_str, Style::default().fg(Color::White)),
                ]),
                Line::from(vec![
                    Span::styled("      ", Style::default().fg(hex_color(0x888888))),
                    Span::styled(&json_time, Style::default().fg(hex_color(0x666666))),
                ]),
            ];
            
            let para = Paragraph::new(lines);
            f.render_widget(para, content_area);
            return;
        }
    }
    
    let para = Paragraph::new("Select a dashboard to view sync status")
        .style(Style::default().fg(Color::DarkGray));
    f.render_widget(para, content_area);
}

fn draw_sync_history(f: &mut Frame, area: Rect, _app: &App, modal_visible: bool) {
    let border_color = if modal_visible {
        hex_color(0x222222)
    } else {
        Color::White
    };
    
    let block = Block::default()
        .title(" Sync History ")
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
    
    let para = Paragraph::new("Sync history not yet implemented")
        .style(Style::default().fg(Color::DarkGray));
    f.render_widget(para, content_area);
}

fn draw_bottom_status(f: &mut Frame, area: Rect, app: &App) {
    let modal_visible = app.is_modal_visible();
    
    // Draw toast notifications stacked on bottom right
    draw_toasts(f, area, &app.toasts);
    
    // Line 1: Global (grey) + Panel-specific (white) bindings
    let global_text = "[↑↓←→] Navigate  [Tab] Next Column  [Enter] Select  [q] Quit";
    let panel_text = get_panel_help(app);
    let spans = vec![
        Span::styled(global_text, Style::default().fg(if modal_visible { hex_color(0x333333) } else { hex_color(0x777777) })),
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

fn get_panel_help(app: &App) -> String {
    match app.view_mode {
        ViewMode::DashboardList => "Q: Quit".to_string(),
        ViewMode::ScriptsList => "Q: Quit".to_string(),
        ViewMode::SyncStatus => "Q: Quit".to_string(),
        ViewMode::SyncHistory => "Q: Quit".to_string(),
    }
}

fn draw_toasts(f: &mut Frame, area: Rect, toasts: &[crate::components::Toast]) {
    if toasts.is_empty() {
        return;
    }
    
    // Show the most recent toast at the bottom right
    if let Some(toast) = toasts.last() {
        let message = &toast.message;
        let color = match toast.toast_type {
            crate::components::ToastType::Success => Color::Green,
            crate::components::ToastType::Error => Color::Red,
            crate::components::ToastType::Info => Color::Cyan,
        };
        
        let lines: Vec<Line> = message.lines().map(|line| {
            Line::from(Span::styled(line, Style::default().fg(color)))
        }).collect();
        
        let para = Paragraph::new(lines)
            .block(Block::default()
                .borders(Borders::ALL)
                .border_type(BorderType::Rounded)
                .border_style(Style::default().fg(color)));
        
        // Calculate toast size
        let max_width = message.lines().map(|l| l.len()).max().unwrap_or(0).min(50);
        let height = message.lines().count().min(5);
        
        let toast_area = Rect {
            x: area.x + area.width.saturating_sub((max_width + 4) as u16),
            y: area.y + area.height.saturating_sub((height + 2) as u16),
            width: (max_width + 4) as u16,
            height: (height + 2) as u16,
        };
        
        f.render_widget(para, toast_area);
    }
}

