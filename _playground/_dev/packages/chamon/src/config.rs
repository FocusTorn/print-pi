use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize, Serialize)]
pub struct Config {
    pub title_bar: TitleBar,
    pub commands_view: CommandsView,
    pub files_view: FilesView,
    pub help_line: HelpLine,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct TitleBar {
    pub display: String,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct CommandsView {
    pub commands: Vec<CommandConfig>,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct CommandConfig {
    pub name: String,
    pub key: String,
    pub desc: String,
    pub command: String,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct FilesView {
    pub tab1: TabConfig,
    pub tab2: TabConfig,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct TabConfig {
    pub name: String,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct HelpLine {
    pub text: String,
}
