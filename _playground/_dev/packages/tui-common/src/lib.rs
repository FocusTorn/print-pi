// Shared TUI components library
// 
// This crate provides reusable components for building terminal user interfaces
// with ratatui. Components can be extended by individual projects as needed.

pub mod helpers;
pub mod list_panel;
pub mod form_panel;
pub mod toast;
pub mod file_browser;

// Re-export commonly used types and functions
pub use helpers::{hex_color, get_selection_style, accent_color, centered_rect};
pub use list_panel::{ItemRow, ListPanelTheme, draw_list_panel};
pub use form_panel::{FormField, FormState, draw_form_panel};
pub use toast::{Toast, ToastType};
pub use file_browser::{FileBrowser, FileEntry};

