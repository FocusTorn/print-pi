use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs::{self, File};
use std::io::{self, BufReader, BufWriter, Read};
use std::path::{Path, PathBuf};
use std::time::SystemTime;
use std::os::unix::fs::MetadataExt;
use crate::config::BaselineConfig;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TrackMode {
    /// Track existence only - no checksum or content
    Exists {
        size: u64,
        modified: u64,
        permissions: u32,
        owner: u32,
        group: u32,
    },
    /// Track with MD5 checksum
    Checksum {
        checksum: String,
        size: u64,
        modified: u64,
        permissions: u32,
        owner: u32,
        group: u32,
    },
    /// Store full content for diffing
    Content {
        checksum: String,
        content: String,
        size: u64,
        modified: u64,
        permissions: u32,
        owner: u32,
        group: u32,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileEntry {
    pub path: String,
    pub track_mode: TrackMode,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Baseline {
    pub created_at: u64,
    pub version: String,
    pub scan_path: String,      // Physical path scanned (e.g., "/media/pi/clean-pi/rootfs")
    pub remap_to: String,        // Logical path to remap to (e.g., "/")
    pub file_count: usize,
    pub is_delta: bool,         // True if this is a delta (only changed files)
    pub files: HashMap<String, FileEntry>,  // For delta: only changed/added files
    pub deleted_files: Vec<String>,         // For delta: files deleted since initial
}

#[derive(Debug, Clone)]
pub struct BaselineComparison {
    pub changed: Vec<FileEntry>,
    pub new: Vec<String>,
    pub deleted: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BaselineMetadata {
    pub version: String,
    pub file_count: usize,
    pub is_delta: bool,
}

impl Baseline {
    /// Create a new baseline by scanning from the specified path
    /// 
    /// # Arguments
    /// * `scan_path` - Physical path to scan (e.g., "/media/pi/clean-pi/rootfs")
    /// * `remap_to` - Logical path to remap to (e.g., "/"). If empty, uses scan_path.
    /// * `config` - Baseline configuration
    pub fn create(scan_path: &str, remap_to: &str, config: &BaselineConfig) -> io::Result<Self> {
        let mut files = HashMap::new();
        let mut size_excluded = Vec::new(); // Track files excluded by size
        
        // Normalize paths (remove trailing slashes, except for root "/")
        let scan_path_normalized = if scan_path == "/" {
            "/"
        } else {
            scan_path.trim_end_matches('/')
        };
        
        let remap_to_normalized = if remap_to.is_empty() {
            scan_path_normalized
        } else if remap_to == "/" {
            "/" // Special case: root path should stay as "/"
        } else {
            remap_to.trim_end_matches('/')
        };
        
        // Scan the specified directory
        let scan_path_obj = Path::new(scan_path_normalized);
        if scan_path_obj.exists() {
            Self::scan_directory_recursive(
                scan_path_obj,
                &mut files,
                &mut size_excluded,
                config,
                scan_path_normalized,
                remap_to_normalized,
            )?;
        }
        
        // Write size exclusion log if any files were excluded
        if !size_excluded.is_empty() {
            Self::write_exclusion_log(&size_excluded, config)?;
        }

        let file_count = files.len();
        let created_at = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)
            .unwrap()
            .as_secs();

        Ok(Baseline {
            created_at,
            version: chrono::DateTime::from_timestamp(created_at as i64, 0)
                .map(|dt| dt.format("%Y%m%d-%H%M%S").to_string())
                .unwrap_or_else(|| "unknown".to_string()),
            scan_path: scan_path_normalized.to_string(),
            remap_to: remap_to_normalized.to_string(),
            file_count,
            is_delta: false,
            files,
            deleted_files: vec![],
        })
    }

    /// Create a delta baseline by comparing current state to initial baseline
    pub fn create_delta(data_dir: &Path, config: &BaselineConfig) -> io::Result<Self> {
        // Load initial baseline
        let initial = Self::load_initial(data_dir)?;
        
        // Scan LIVE filesystem (remap_to path) to compare against initial
        // Example: initial was scanned from /media/pi/clean-pi/rootfs (clean reference)
        //          but remapped to /. Now we scan the LIVE / to find differences.
        let mut current_files = HashMap::new();
        let mut size_excluded = Vec::new();
        let live_path = Path::new(&initial.remap_to);
        if live_path.exists() {
            Self::scan_directory_recursive(
                live_path,
                &mut current_files,
                &mut size_excluded,
                config,
                &initial.remap_to,  // Scan the live system
                &initial.remap_to,  // Store paths as-is (no remapping for delta)
            )?;
        }
        
        // Write size exclusion log if any files were excluded
        if !size_excluded.is_empty() {
            Self::write_exclusion_log(&size_excluded, config)?;
        }
        
        // Find changes
        let mut changed_files = HashMap::new();
        let mut deleted_files = Vec::new();
        
        // Check for modified and deleted files
        for (path, initial_entry) in &initial.files {
            if let Some(current_entry) = current_files.get(path) {
                // File exists, check if changed
                if Self::has_changed(&initial_entry.track_mode, &current_entry.track_mode) {
                    changed_files.insert(path.clone(), current_entry.clone());
                }
            } else {
                // File was deleted
                deleted_files.push(path.clone());
            }
        }
        
        // Check for new files
        for (path, current_entry) in &current_files {
            if !initial.files.contains_key(path) {
                // New file
                changed_files.insert(path.clone(), current_entry.clone());
            }
        }
        
        let file_count = changed_files.len() + deleted_files.len();
        let created_at = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        
        Ok(Baseline {
            created_at,
            version: chrono::DateTime::from_timestamp(created_at as i64, 0)
                .map(|dt| dt.format("%Y%m%d-%H%M%S").to_string())
                .unwrap_or_else(|| "unknown".to_string()),
            scan_path: initial.remap_to.clone(),  // Delta scans the LIVE system
            remap_to: initial.remap_to.clone(),   // No remapping for delta (already at target)
            file_count,
            is_delta: true,
            files: changed_files,
            deleted_files,
        })
    }

    fn scan_directory_recursive(
        path: &Path,
        results: &mut HashMap<String, FileEntry>,
        size_excluded: &mut Vec<(String, u64)>,
        config: &BaselineConfig,
        scan_path: &str,
        remap_to: &str,
    ) -> io::Result<()> {
        // Check if this directory should be excluded (check against REMAPPED path)
        if let Some(path_str) = path.to_str() {
            let remapped_path = Self::remap_path(path_str, scan_path, remap_to);
            for exclude in &config.exclude_directories {
                if remapped_path.starts_with(exclude.as_str()) {
                    return Ok(());
                }
            }
        }

        if path.is_file() {
            // Process this file
            match Self::process_file(path, config, scan_path, remap_to) {
                Ok((file_entry, excluded_info)) => {
                    results.insert(file_entry.path.clone(), file_entry);
                    if let Some((path, size)) = excluded_info {
                        size_excluded.push((path, size));
                    }
                }
                Err(_) => {
                    // Skip files we can't read
                }
            }
        } else if path.is_dir() {
            // Recursively scan subdirectories
            if let Ok(entries) = fs::read_dir(path) {
                for entry in entries.flatten() {
                    let entry_path = entry.path();
                    // Avoid following symlinks to prevent cycles
                    if let Ok(metadata) = fs::symlink_metadata(&entry_path) {
                        if !metadata.is_symlink() {
                            let _ = Self::scan_directory_recursive(&entry_path, results, size_excluded, config, scan_path, remap_to);
                        }
                    }
                }
            }
        }

        Ok(())
    }
    
    /// Write exclusion log for files that were too large
    fn write_exclusion_log(excluded: &[(String, u64)], config: &BaselineConfig) -> io::Result<()> {
        use std::io::Write;
        
        let log_path = Path::new(&config.exclusion_log);
        if let Some(parent) = log_path.parent() {
            fs::create_dir_all(parent)?;
        }
        
        let mut file = File::create(log_path)?;
        writeln!(file, "# Files excluded from baseline due to size limit ({}KB)", config.content_size_limit / 1024)?;
        writeln!(file, "# Generated: {}", chrono::Local::now().format("%Y-%m-%d %H:%M:%S"))?;
        writeln!(file, "")?;
        
        for (path, size) in excluded {
            let size_mb = (*size as f64) / 1_048_576.0;
            writeln!(file, "{} ({:.2} MB)", path, size_mb)?;
        }
        
        Ok(())
    }

    /// Remap a physical path to a logical path
    /// Example: "/media/pi/clean-pi/rootfs/etc/config.txt" -> "/etc/config.txt"
    fn remap_path(physical_path: &str, scan_path: &str, remap_to: &str) -> String {
        if scan_path == remap_to {
            // No remapping needed
            return physical_path.to_string();
        }
        
        if let Some(suffix) = physical_path.strip_prefix(scan_path) {
            // Strip scan_path prefix and add remap_to prefix
            let suffix = suffix.trim_start_matches('/');
            if suffix.is_empty() {
                remap_to.to_string()
            } else if remap_to == "/" {
                // Special case: remapping to root, just add leading slash
                format!("/{}", suffix)
            } else {
                format!("{}/{}", remap_to, suffix)
            }
        } else {
            // Path doesn't start with scan_path, return as-is
            physical_path.to_string()
        }
    }

    /// Process a single file and determine its tracking mode
    /// Returns (FileEntry, Option<(path, size)>) where second element is Some if excluded by size
    fn process_file(
        path: &Path, 
        config: &BaselineConfig, 
        scan_path: &str, 
        remap_to: &str
    ) -> io::Result<(FileEntry, Option<(String, u64)>)> {
        let size = fs::metadata(path)?.len();
        let physical_path = path.to_string_lossy().to_string();
        
        // Remap the path
        let logical_path = Self::remap_path(&physical_path, scan_path, remap_to);
        
        // Determine tracking mode based on config rules
        let (track_mode, size_excluded) = Self::determine_track_mode(path, size, config)?;

        Ok((
            FileEntry {
                path: logical_path.clone(),
                track_mode,
            },
            if size_excluded {
                Some((logical_path, size))
            } else {
                None
            }
        ))
    }

    /// Determine which tracking mode to use for a file
    /// Returns (TrackMode, bool) where bool is true if excluded by size
    fn determine_track_mode(
        path: &Path,
        size: u64,
        config: &BaselineConfig,
    ) -> io::Result<(TrackMode, bool)> {
        let path_str = path.to_string_lossy();
        let metadata = fs::metadata(path)?;
        let permissions = metadata.mode();
        let owner = metadata.uid();
        let group = metadata.gid();
        let modified = metadata
            .modified()?
            .duration_since(SystemTime::UNIX_EPOCH)
            .unwrap()
            .as_secs();

        // Rule 1: Check if in existence-only directory
        for exists_dir in &config.existence_only_directories {
            if path_str.starts_with(exists_dir.as_str()) {
                return Ok((TrackMode::Exists {
                    size,
                    modified,
                    permissions,
                    owner,
                    group,
                }, false)); // Not excluded by size
            }
        }

        // Rule 2: Check if file extension is existence-only
        if let Some(ext) = path.extension() {
            let ext_str = format!(".{}", ext.to_string_lossy());
            if config.existence_only_extensions.contains(&ext_str) {
                return Ok((TrackMode::Exists {
                    size,
                    modified,
                    permissions,
                    owner,
                    group,
                }, false)); // Not excluded by size
            }
        }

        // Rule 3: Check if file is too large (existence only + LOG IT)
        if size > config.content_size_limit {
            return Ok((TrackMode::Exists {
                size,
                modified,
                permissions,
                owner,
                group,
            }, true)); // EXCLUDED BY SIZE - will be logged
        }

        // Default: Store full content for all files under size limit
        // Try to read as text; if fails, fall back to checksum only
        match fs::read_to_string(path) {
            Ok(content) => {
                let checksum = format!("{:x}", md5::compute(&content));
                Ok((TrackMode::Content {
                    checksum,
                    content,
                    size,
                    modified,
                    permissions,
                    owner,
                    group,
                }, false))
            }
            Err(_) => {
                // File is binary or unreadable, use checksum mode
                let mut file = File::open(path)?;
                let mut buffer = Vec::new();
                file.read_to_end(&mut buffer)?;
                let checksum = format!("{:x}", md5::compute(&buffer));
                
                Ok((TrackMode::Checksum {
                    checksum,
                    size,
                    modified,
                    permissions,
                    owner,
                    group,
                }, false))
            }
        }
    }

    /// Save baseline to file
    pub fn save(&self, data_dir: &Path, is_initial: bool) -> io::Result<PathBuf> {
        let baselines_dir = data_dir.join("baselines");
        fs::create_dir_all(&baselines_dir)?;

        let filename = if is_initial {
            "baseline-initial.json".to_string()
        } else {
            format!("baseline-{}.json", self.version)
        };
        
        let filepath = baselines_dir.join(&filename);
        
        let file = File::create(&filepath)?;
        let writer = BufWriter::new(file);
        serde_json::to_writer_pretty(writer, self)?;

        Ok(filepath)
    }

    /// Load initial baseline
    pub fn load_initial(data_dir: &Path) -> io::Result<Self> {
        let filepath = data_dir.join("baselines/baseline-initial.json");
        let file = File::open(filepath)?;
        let reader = BufReader::new(file);
        let baseline = serde_json::from_reader(reader)?;
        Ok(baseline)
    }

    /// Load a specific baseline version
    pub fn load(data_dir: &Path, version: &str) -> io::Result<Self> {
        let filepath = data_dir.join(format!("baselines/baseline-{}.json", version));
        let file = File::open(filepath)?;
        let reader = BufReader::new(file);
        let baseline = serde_json::from_reader(reader)?;
        Ok(baseline)
    }

    /// List all available baseline versions with metadata (excluding initial)
    pub fn list_versions(data_dir: &Path) -> io::Result<Vec<BaselineMetadata>> {
        let baselines_dir = data_dir.join("baselines");
        
        if !baselines_dir.exists() {
            return Ok(Vec::new());
        }

        let mut versions = Vec::new();
        
        for entry in fs::read_dir(&baselines_dir)? {
            let entry = entry?;
            let filename = entry.file_name();
            let filename_str = filename.to_string_lossy();
            
            // Skip initial baseline, only get versioned (delta) files
            if filename_str.starts_with("baseline-") 
                && filename_str.ends_with(".json")
                && !filename_str.contains("initial")
            {
                // Load baseline to get metadata
                let filepath = entry.path();
                if let Ok(file) = File::open(&filepath) {
                    if let Ok(baseline) = serde_json::from_reader::<_, Baseline>(BufReader::new(file)) {
                        versions.push(BaselineMetadata {
                            version: baseline.version,
                            file_count: baseline.file_count,
                            is_delta: baseline.is_delta,
                        });
                    }
                }
            }
        }
        
        // Sort by version (newest first)
        versions.sort_by(|a, b| b.version.cmp(&a.version));
        Ok(versions)
    }

    /// Compare current system state with this baseline
    pub fn compare(&self, config: &BaselineConfig, data_dir: &Path) -> io::Result<BaselineComparison> {
        let mut changed = Vec::new();
        let mut deleted = Vec::new();
        let mut current_files = HashMap::new();

        // Scan current system state using same path and remapping as baseline
        let scan_path = Path::new(&self.scan_path);
        let mut size_excluded = Vec::new(); // Not logged for comparisons
        if scan_path.exists() {
            Self::scan_directory_recursive(
                scan_path,
                &mut current_files,
                &mut size_excluded,
                config,
                &self.scan_path,
                &self.remap_to,
            )?;
        }

        // Reconstruct full baseline state (for delta baselines)
        let full_baseline_files = if self.is_delta {
            // Load initial baseline and apply delta
            let initial = Self::load_initial(data_dir)?;
            let mut full_files = initial.files.clone();
            
            // Apply delta changes (overwrite with changed files)
            for (path, entry) in &self.files {
                full_files.insert(path.clone(), entry.clone());
            }
            
            // Remove deleted files
            for path in &self.deleted_files {
                full_files.remove(path);
            }
            
            full_files
        } else {
            // Not a delta, use files as-is
            self.files.clone()
        };

        // Check for changes and deletions
        for (path, baseline_entry) in &full_baseline_files {
            if let Some(current_entry) = current_files.get(path) {
                if Self::has_changed(&baseline_entry.track_mode, &current_entry.track_mode) {
                    changed.push(current_entry.clone());
                }
            } else {
                deleted.push(path.clone());
            }
        }

        // Check for new files
        let new: Vec<String> = current_files
            .keys()
            .filter(|path| !full_baseline_files.contains_key(*path))
            .cloned()
            .collect();

        Ok(BaselineComparison {
            changed,
            new,
            deleted,
        })
    }

    /// Check if a file has changed between two track modes
    fn has_changed(baseline: &TrackMode, current: &TrackMode) -> bool {
        match (baseline, current) {
            (TrackMode::Exists { size: s1, modified: m1, permissions: p1, owner: o1, group: g1 },
             TrackMode::Exists { size: s2, modified: m2, permissions: p2, owner: o2, group: g2 }) => {
                s1 != s2 || m1 != m2 || p1 != p2 || o1 != o2 || g1 != g2
            }
            (TrackMode::Checksum { checksum: c1, permissions: p1, owner: o1, group: g1, .. },
             TrackMode::Checksum { checksum: c2, permissions: p2, owner: o2, group: g2, .. }) => {
                c1 != c2 || p1 != p2 || o1 != o2 || g1 != g2
            }
            (TrackMode::Content { checksum: c1, permissions: p1, owner: o1, group: g1, .. },
             TrackMode::Content { checksum: c2, permissions: p2, owner: o2, group: g2, .. }) => {
                c1 != c2 || p1 != p2 || o1 != o2 || g1 != g2
            }
            _ => true, // Different tracking modes = changed
        }
    }
}

