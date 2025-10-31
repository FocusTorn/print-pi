// File browser for selecting files in the TUI

use std::fs;
use std::path::{Path, PathBuf};
use ratatui::{
    layout::Rect,
    style::{Color, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, BorderType, Clear, Paragraph},
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
pub struct FileBrowser {
    pub current_dir: PathBuf,
    pub entries: Vec<FileEntry>,
    pub selected_index: usize,
    pub scroll_offset: usize,
    pub visible_height: usize,
}

#[derive(Debug, Clone)]
pub struct FileEntry {
    pub name: String,
    pub path: PathBuf,
    pub is_dir: bool,
    pub size: u64,
}

impl FileBrowser {
    pub fn new(start_path: &str) -> Self {
        let mut browser = Self {
            current_dir: PathBuf::from(start_path),
            entries: vec![],
            selected_index: 0,
            scroll_offset: 0,
            visible_height: 20, // Default, will be updated on render
        };
        browser.load_entries();
        browser
    }
    
    pub fn load_entries(&mut self) {
        self.entries.clear();
        self.selected_index = 0;
        self.scroll_offset = 0;
        
        // Add parent directory entry
        if self.current_dir.parent().is_some() {
            self.entries.push(FileEntry {
                name: "..".to_string(),
                path: self.current_dir.parent().unwrap().to_path_buf(),
                is_dir: true,
                size: 0,
            });
        }
        
        // Read directory entries
        if let Ok(entries) = fs::read_dir(&self.current_dir) {
            let mut dirs = vec![];
            let mut files = vec![];
            
            for entry in entries.flatten() {
                if let Ok(metadata) = entry.metadata() {
                    let name = entry.file_name().to_string_lossy().to_string();
                    
                    let file_entry = FileEntry {
                        name: name.clone(),
                        path: entry.path(),
                        is_dir: metadata.is_dir(),
                        size: metadata.len(),
                    };
                    
                    if metadata.is_dir() {
                        dirs.push(file_entry);
                    } else {
                        files.push(file_entry);
                    }
                }
            }
            
            // Sort directories and files alphabetically
            dirs.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
            files.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
            
            // Add sorted entries
            self.entries.extend(dirs);
            self.entries.extend(files);
        }
    }
    
    pub fn navigate_up(&mut self) {
        if self.selected_index > 0 {
            self.selected_index -= 1;
            self.adjust_scroll_to_selection();
        }
    }
    
    pub fn navigate_down(&mut self) {
        if self.selected_index < self.entries.len().saturating_sub(1) {
            self.selected_index += 1;
            self.adjust_scroll_to_selection();
        }
    }
    
    pub fn scroll_up(&mut self) {
        if self.scroll_offset > 0 {
            self.scroll_offset -= 1;
        }
    }
    
    pub fn scroll_down(&mut self) {
        let max_scroll = self.entries.len().saturating_sub(self.visible_height);
        if self.scroll_offset < max_scroll {
            self.scroll_offset += 1;
        }
    }
    
    fn adjust_scroll_to_selection(&mut self) {
        // Scroll up if selection is above visible area
        if self.selected_index < self.scroll_offset {
            self.scroll_offset = self.selected_index;
        }
        // Scroll down if selection is below visible area
        else if self.selected_index >= self.scroll_offset + self.visible_height {
            self.scroll_offset = self.selected_index.saturating_sub(self.visible_height - 1);
        }
    }
    
    pub fn enter_directory(&mut self) -> bool {
        if let Some(entry) = self.entries.get(self.selected_index) {
            if entry.is_dir {
                self.current_dir = entry.path.clone();
                self.load_entries();
                return true;
            }
        }
        false
    }
    
    pub fn go_to_parent(&mut self) -> bool {
        if let Some(parent) = self.current_dir.parent() {
            // Remember the current directory name to select it after going up
            let current_name = self.current_dir
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("")
                .to_string();
            
            self.current_dir = parent.to_path_buf();
            self.load_entries();
            
            // Find and select the directory we just came from
            for (i, entry) in self.entries.iter().enumerate() {
                if entry.name == current_name {
                    self.selected_index = i;
                    self.adjust_scroll_to_selection();
                    break;
                }
            }
            
            return true;
        }
        false
    }
    
    pub fn get_selected_path(&self) -> Option<String> {
        self.entries.get(self.selected_index).map(|e| {
            e.path.to_string_lossy().to_string()
        })
    }
    
    pub fn render(&mut self, f: &mut Frame, _full_area: Rect, area: Rect) {
        // No dimming overlay needed - UI elements handle dimming themselves
        // Just clear the browser area to ensure solid background
        f.render_widget(Clear, area);
        
        let block = Block::default()
            .title(format!(" File Browser - {} ", self.current_dir.display()))
            .borders(Borders::ALL)
            .border_type(BorderType::Rounded)
            .border_style(Style::default().fg(Color::Cyan))
            .style(Style::default().bg(hex_color(0x141420))); // Solid dark blue background
        
        let inner_area = Rect {
            x: area.x + 1,
            y: area.y + 1,
            width: area.width.saturating_sub(2),
            height: area.height.saturating_sub(2),
        };
        
        f.render_widget(block, area);
        
        // Calculate visible entries
        let visible_height = inner_area.height.saturating_sub(2) as usize; // Reserve space for help
        self.visible_height = visible_height;
        let visible_entries: Vec<ListItem> = self.entries
            .iter()
            .skip(self.scroll_offset)
            .take(visible_height)
            .enumerate()
            .map(|(idx, entry)| {
                let actual_idx = idx + self.scroll_offset;
                let is_selected = actual_idx == self.selected_index;
                
                let icon = if entry.name == ".." {
                    "↑"
                } else if entry.is_dir {
                    "📁"
                } else {
                    "📄"
                };
                
                let size_str = if entry.is_dir {
                    "".to_string()
                } else if entry.size > 1024 * 1024 {
                    format!(" ({:.1} MB)", entry.size as f64 / (1024.0 * 1024.0))
                } else if entry.size > 1024 {
                    format!(" ({:.1} KB)", entry.size as f64 / 1024.0)
                } else {
                    format!(" ({} B)", entry.size)
                };
                
                let content = format!(" {} {}{}",
                    icon,
                    entry.name,
                    size_str
                );
                
                let style = if is_selected {
                    Style::default().fg(Color::Black).bg(Color::Cyan)
                } else if entry.is_dir {
                    Style::default().fg(Color::Cyan)
                } else {
                    Style::default().fg(Color::White)
                };
                
                ListItem::new(Line::from(Span::styled(content, style)))
            })
            .collect();
        
        let list = List::new(visible_entries);
        
        let list_area = Rect {
            x: inner_area.x,
            y: inner_area.y,
            width: inner_area.width,
            height: inner_area.height.saturating_sub(2),
        };
        
        f.render_widget(list, list_area);
        
        // Draw scrollbar if needed
        if self.entries.len() > visible_height {
            let scrollbar_height = list_area.height as usize;
            let total_items = self.entries.len();
            let scrollbar_position = if total_items > scrollbar_height {
                (self.scroll_offset * scrollbar_height) / total_items
            } else {
                0
            };
            let scrollbar_size = (scrollbar_height * scrollbar_height) / total_items.max(1);
            let scrollbar_size = scrollbar_size.max(1);
            
            for i in 0..scrollbar_height {
                let is_scrollbar = i >= scrollbar_position && i < (scrollbar_position + scrollbar_size);
                let symbol = if is_scrollbar { "█" } else { "│" };
                let color = if is_scrollbar { Color::Cyan } else { Color::DarkGray };
                
                let x = list_area.x + list_area.width - 1;
                let y = list_area.y + i as u16;
                
                f.render_widget(
                    Paragraph::new(symbol).style(Style::default().fg(color)),
                    Rect { x, y, width: 1, height: 1 }
                );
            }
        }
        
        // Help text at bottom
        let help_text = Line::from(vec![
            Span::styled("[↑↓] Navigate  ", Style::default().fg(Color::Gray)),
            Span::styled("[Enter] Select/Open  ", Style::default().fg(Color::Gray)),
            Span::styled("[Esc] Cancel", Style::default().fg(Color::Gray)),
        ]);
        
        let help_area = Rect {
            x: inner_area.x + 1,
            y: inner_area.y + inner_area.height.saturating_sub(1),
            width: inner_area.width.saturating_sub(2),
            height: 1,
        };
        
        f.render_widget(ratatui::widgets::Paragraph::new(help_text), help_area);
    }
}

// Path completion utilities
pub fn complete_path(partial: &str) -> Vec<String> {
    let path = Path::new(partial);
    let (dir, prefix) = if partial.ends_with('/') {
        (path, "")
    } else {
        (
            path.parent().unwrap_or(Path::new(".")),
            path.file_name().and_then(|s| s.to_str()).unwrap_or("")
        )
    };
    
    let mut completions = vec![];
    
    if let Ok(entries) = fs::read_dir(dir) {
        for entry in entries.flatten() {
            if let Some(name) = entry.file_name().to_str() {
                if name.starts_with(prefix) {
                    let full_path = entry.path().to_string_lossy().to_string();
                    completions.push(full_path);
                }
            }
        }
    }
    
    completions.sort();
    completions
}

// ZSH-style path expansion: p/t/f -> path/to/file
pub fn expand_path_shorthand(input: &str) -> Option<Vec<String>> {
    if !input.contains('/') {
        return None;
    }
    
    let parts: Vec<&str> = input.split('/').collect();
    let mut current_paths = vec![String::from("")];
    
    for (idx, part) in parts.iter().enumerate() {
        if part.is_empty() && idx > 0 {
            continue;
        }
        
        let mut next_paths = vec![];
        
        for base_path in &current_paths {
            let search_dir = if base_path.is_empty() {
                Path::new("/")
            } else {
                Path::new(base_path)
            };
            
            if let Ok(entries) = fs::read_dir(search_dir) {
                for entry in entries.flatten() {
                    if let Some(name) = entry.file_name().to_str() {
                        // Match if name starts with the part
                        if name.to_lowercase().starts_with(&part.to_lowercase()) {
                            let new_path = if base_path.is_empty() {
                                format!("/{}", name)
                            } else {
                                format!("{}/{}", base_path, name)
                            };
                            next_paths.push(new_path);
                        }
                    }
                }
            }
        }
        
        if next_paths.is_empty() {
            return None;
        }
        
        current_paths = next_paths;
    }
    
    if current_paths.is_empty() {
        None
    } else {
        Some(current_paths)
    }
}

