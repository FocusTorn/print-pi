// File browser component (base implementation, can be extended by projects)

use std::path::PathBuf;

pub struct FileBrowser {
    pub current_dir: PathBuf,
    pub entries: Vec<FileEntry>,
    pub selected_index: usize,
    pub scroll_offset: usize,
    pub visible_height: usize,
}

pub struct FileEntry {
    pub name: String,
    pub path: PathBuf,
    pub is_dir: bool,
    pub size: u64,
}

impl FileBrowser {
    pub fn new(start_path: impl Into<PathBuf>) -> Self {
        let current_dir = start_path.into();
        FileBrowser {
            current_dir,
            entries: vec![],
            selected_index: 0,
            scroll_offset: 0,
            visible_height: 0,
        }
    }
    
    pub fn navigate_up(&mut self) {
        // Base implementation - can be overridden by projects
        if self.selected_index > 0 {
            self.selected_index -= 1;
        }
    }
    
    pub fn navigate_down(&mut self) {
        // Base implementation - can be overridden by projects
        if self.selected_index < self.entries.len().saturating_sub(1) {
            self.selected_index += 1;
        }
    }
    
    pub fn enter_directory(&mut self) {
        // Base implementation - projects should override this
        // to implement actual directory navigation
    }
    
    pub fn go_to_parent(&mut self) {
        // Base implementation - projects should override this
        // to implement actual parent navigation
    }
}

