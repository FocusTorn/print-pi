// Configuration parsing and management

use std::path::PathBuf;

pub struct DetourConfig {
    pub detours: Vec<Detour>,
    pub includes: Vec<Include>,
    pub services: Vec<Service>,
}

pub struct Detour {
    pub original: PathBuf,
    pub custom: PathBuf,
}

pub struct Include {
    pub target: PathBuf,
    pub include_file: PathBuf,
}

pub struct Service {
    pub name: String,
    pub action: ServiceAction,
}

pub enum ServiceAction {
    Start,
    Stop,
    Restart,
    Reload,
}

impl DetourConfig {
    pub fn parse(_path: PathBuf) -> Result<Self, String> {
        // TODO: Implement config parsing
        unimplemented!("Config parsing not yet implemented")
    }
}


