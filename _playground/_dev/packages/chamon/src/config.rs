use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize, Serialize)]
pub struct Config {
    pub title_bar: TitleBar,
    pub baseline: BaselineConfig,
    pub commands_view: CommandsView,
    pub files_panel: FilesPanel,
    pub baseline_panel: BaselinePanel,
    pub help_line: HelpLine,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct TitleBar {
    pub display: String,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct BaselineConfig {
    pub exclude_directories: Vec<String>,
    pub existence_only_directories: Vec<String>,
    pub existence_only_extensions: Vec<String>,
    pub content_size_limit: u64,
    pub exclusion_log: String,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct CommandsView {
    pub select_indicator: String,
    pub changes_commands: Vec<CommandConfig>,
    pub baseline_commands: Vec<CommandConfig>,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct CommandConfig {
    pub name: String,
    pub key: String,
    pub desc: String,
    pub command: String,
    pub select: Option<String>, // Optional select indicator (e.g., "►")
}

#[derive(Debug, Deserialize, Serialize)]
pub struct FilesPanel {
    pub toggles: Vec<ToggleConfig>,
    pub view_type: Vec<ViewTypeConfig>,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct ToggleConfig {
    pub name: String,
    pub command: String,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct ViewTypeConfig {
    pub name: String,
    pub command: String,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct BaselinePanel {
    pub help_line: PanelHelpLine,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct PanelHelpLine {
    pub pre_text: String,
    pub post_text: String,
    pub bindings: Vec<HelpLineBinding>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct HelpLineBinding {
    pub name: String,
    pub key: String,
    pub command: String,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct HelpLine {
    pub text: String,
}
