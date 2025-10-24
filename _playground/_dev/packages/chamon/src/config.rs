use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize, Serialize)]
pub struct Config {
    pub debugging: DebuggingConfig,
    pub title_bar: TitleBar,
    pub primary_commands_panel: PrimaryCommandsPanel,
    pub secondary_commands_panel: SecondaryCommandsPanel,
    pub files_panel: FilesPanel,
    pub baseline_panel: BaselinePanelConfig,
    pub help_line: HelpLine,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct DebuggingConfig {
    pub scan_path: String,
    pub redirect_path: String,
    pub auto_prompts: AutoPromptsConfig,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct AutoPromptsConfig {
    pub enabled: bool,
    pub initial_baseline: InitialBaselinePrompts,
    #[serde(default)]
    pub delta_baseline: DeltaBaselinePrompts,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct InitialBaselinePrompts {
    pub overwrite_confirmation: PromptValue,
    pub scan_path: PromptValue,
    pub redirect_path: PromptValue,
}

#[derive(Debug, Deserialize, Serialize, Clone, Default)]
pub struct DeltaBaselinePrompts {
    // No prompts currently - delta uses initial baseline settings
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct PromptValue {
    pub apply: bool,
    pub value: String,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct TitleBar {
    pub display: String,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct BaselineConfig {
    pub exclude_directories: Vec<String>,
    pub max_directory_files: usize,
    pub collapse_completed_dirs: bool,
    pub existence_only_directories: Vec<String>,
    pub existence_only_extensions: Vec<String>,
    pub content_size_limit: u64,
    pub exclusion_log: String,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct PrimaryCommandsPanel {
    pub select_indicator: String,
    pub primary_commands: Vec<CommandConfig>,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct SecondaryCommandsPanel {
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
pub struct BaselinePanelConfig {
    pub baseline_generation: BaselineConfig,
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
