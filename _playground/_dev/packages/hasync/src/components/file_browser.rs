// File browser component

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
        // TODO: Implement navigation
    }
    
    pub fn navigate_down(&mut self) {
        // TODO: Implement navigation
    }
    
    pub fn enter_directory(&mut self) {
        // TODO: Implement directory navigation
    }
    
    pub fn go_to_parent(&mut self) {
        // TODO: Implement parent navigation
    }
}
