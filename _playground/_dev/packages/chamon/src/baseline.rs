use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};
use std::fs::{self, File};
use std::io::{self, BufReader, BufWriter, Read};
use std::path::{Path, PathBuf};
use std::time::SystemTime;
use std::os::unix::fs::MetadataExt;
use std::sync::{Arc, Mutex};
use std::sync::atomic::{AtomicBool, Ordering};
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
    pub changed_files: Vec<String>,         // For delta: files that existed in initial and changed
    pub new_files_manual: Vec<String>,      // For delta: NEW files (manual install)
    pub new_files_package: HashMap<String, String>,  // For delta: NEW files from packages (path -> package name)
    pub deleted_files: Vec<String>,         // For delta: files deleted since initial
    pub packages_added_manual: Vec<String>,     // For delta: NEW packages (manually installed)
    pub packages_added_auto: Vec<String>,       // For delta: NEW packages (auto dependencies)
    pub packages_removed: Vec<String>,          // For delta: Packages removed
    pub packages_upgraded: Vec<String>,         // For delta: Packages upgraded (version changed)
    
    // Package snapshot (for both initial and delta)
    #[serde(default)]
    pub installed_packages: HashMap<String, String>,  // package_name -> version
    #[serde(default)]
    pub manual_packages: Vec<String>,  // List of manually installed packages (not auto-deps)
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
        let cancel_flag = Arc::new(AtomicBool::new(false));
        Self::create_with_progress(scan_path, remap_to, config, cancel_flag, |_, _, _| {})
    }
    
    pub fn create_with_progress<F>(scan_path: &str, remap_to: &str, config: &BaselineConfig, cancel_flag: Arc<AtomicBool>, progress_callback: F) -> io::Result<Self> 
    where F: FnMut(&str, usize, &str) + Send + 'static,
    {
        let mut files = HashMap::new();
        let mut size_excluded = Vec::new(); // Track files excluded by size
        
        // Wrap callback in Arc<Mutex> for scan_parallel
        let callback = Arc::new(Mutex::new(progress_callback));
        
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
            let callback_clone = Arc::clone(&callback);
            (files, size_excluded) = Self::scan_parallel(
                scan_path_obj,
                config,
                scan_path_normalized,
                remap_to_normalized,
                cancel_flag,
                callback_clone,
            )?;
        }
        
        // Write size exclusion log if any files were excluded
        if !size_excluded.is_empty() {
            Self::write_exclusion_log(&size_excluded, config)?;
        }

        let file_count = files.len();
        
        // Capture package state at baseline creation
        if let Ok(mut cb) = callback.lock() {
            cb("Capturing package state", file_count, "Querying dpkg and apt-mark...");
        }
        // Query packages from the scan_path root, not the live system
        let (installed_packages, manual_package_set) = Self::get_installed_packages_from_root(Some(&scan_path_normalized));
        let manual_packages: Vec<String> = manual_package_set.into_iter().collect();
        
        if let Ok(mut cb) = callback.lock() {
            cb("Package snapshot complete", installed_packages.len(), &format!("Captured {} packages", installed_packages.len()));
        }
        
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
            changed_files: vec![],           // Not a delta
            new_files_manual: vec![],        // Not a delta
            new_files_package: HashMap::new(),  // Not a delta
            deleted_files: vec![],
            packages_added_manual: vec![],   // Not a delta
            packages_added_auto: vec![],     // Not a delta
            packages_removed: vec![],        // Not a delta
            packages_upgraded: vec![],       // Not a delta
            installed_packages,
            manual_packages,
        })
    }

    /// Create a delta baseline by comparing current state to initial baseline
    pub fn create_delta(data_dir: &Path, config: &BaselineConfig) -> io::Result<Self> {
        let cancel_flag = Arc::new(AtomicBool::new(false));
        Self::create_delta_with_progress(data_dir, config, cancel_flag, |_, _, _| {})
    }
    
    pub fn create_delta_with_progress<F>(data_dir: &Path, config: &BaselineConfig, cancel_flag: Arc<AtomicBool>, progress_callback: F) -> io::Result<Self>
    where F: FnMut(&str, usize, &str) + Send + 'static,
    {
        // Load initial baseline
        let initial = Self::load_initial(data_dir)?;
        
        // Wrap callback in Arc<Mutex> for shared access
        let callback = Arc::new(Mutex::new(progress_callback));
        
        // Build package database for filtering (one-time cost, ~30+ seconds)
        // Create a progress callback wrapper that works with build_package_database's signature
        let callback_clone = Arc::clone(&callback);
        let cancel_clone = Arc::clone(&cancel_flag);
        let (package_file_set, file_to_package_map) = Self::build_package_database(cancel_clone, Arc::new(Mutex::new(move |current, _total, status: String| {
            if let Ok(mut cb) = callback_clone.lock() {
                cb("Building package database", current, &status);
            }
        })))?;
        
        // Notify database build complete
        if let Ok(mut cb) = callback.lock() {
            cb("Package database ready", package_file_set.len(), "Querying current packages...");
        }
        
        // Get current package list to compare against initial baseline
        let (current_packages, current_manual_packages) = Self::get_installed_packages();
        
        if let Ok(mut cb) = callback.lock() {
            cb("Package queries complete", current_packages.len(), "Starting filesystem scan...");
        }
        let initial_packages = &initial.installed_packages;
        let initial_manual_packages: HashSet<String> = initial.manual_packages.iter().cloned().collect();
        
        // Scan LIVE filesystem (remap_to path) to compare against initial
        // Example: initial was scanned from /media/pi/clean-pi/rootfs (clean reference)
        //          but remapped to /. Now we scan the LIVE / to find differences.
        let mut current_files = HashMap::new();
        let mut size_excluded = Vec::new();
        let live_path = Path::new(&initial.remap_to);
        if live_path.exists() {
            // Clone callback Arc for scan_parallel
            let callback_clone = Arc::clone(&callback);
            
            // Use parallel scanning for delta too
            (current_files, size_excluded) = Self::scan_parallel(
                live_path,
                config,
                &initial.remap_to,
                &initial.remap_to,
                cancel_flag,
                callback_clone,
            )?;
        }
        
        // Write size exclusion log if any files were excluded
        if !size_excluded.is_empty() {
            Self::write_exclusion_log(&size_excluded, config)?;
        }
        
        // Find changes - separate changed, new manual, and new package files
        let mut all_files = HashMap::new();
        let mut changed_file_paths = Vec::new();
        let mut new_manual_paths = Vec::new();
        let mut new_package_file_map = HashMap::new();  // path -> package name
        let mut deleted_files = Vec::new();
        
        // Check for modified and deleted files
        for (path, initial_entry) in &initial.files {
            if let Some(current_entry) = current_files.get(path) {
                // File exists, check if changed
                if Self::has_changed(&initial_entry.track_mode, &current_entry.track_mode) {
                    all_files.insert(path.clone(), current_entry.clone());
                    changed_file_paths.push(path.clone());
                }
            } else {
                // File was deleted
                deleted_files.push(path.clone());
            }
        }
        
        // Check for new files (didn't exist in initial)
        // Separate manual vs package-managed files
        if let Ok(mut cb) = callback.lock() {
            cb("Analyzing changes", all_files.len(), "Checking package database...");
        }
        
        for (path, current_entry) in &current_files {
            if !initial.files.contains_key(path) {
                // New file - check if it's package-managed
                let is_package_db = package_file_set.contains(path);
                let is_package_heuristic = Self::is_likely_package_file(path, &package_file_set);
                
                if is_package_db || is_package_heuristic {
                    // Package-managed file - store with package name
                    all_files.insert(path.clone(), current_entry.clone());
                    let package_name = file_to_package_map.get(path)
                        .cloned()
                        .unwrap_or_else(|| "raspi-firmware".to_string()); // Default for /boot/firmware
                    new_package_file_map.insert(path.clone(), package_name);
                } else {
                    // Truly new file (manual install)
                    all_files.insert(path.clone(), current_entry.clone());
                    new_manual_paths.push(path.clone());
                }
            }
        }
        
        // Compare packages (added/removed/upgraded) - separate manual vs auto
        let mut packages_added_manual = Vec::new();
        let mut packages_added_auto = Vec::new();
        let mut packages_removed = Vec::new();
        let mut packages_upgraded = Vec::new();
        
        // Find added and upgraded packages
        for (pkg, version) in &current_packages {
            if let Some(initial_version) = initial_packages.get(pkg) {
                // Package existed in initial baseline - check if upgraded
                if version != initial_version {
                    packages_upgraded.push(format!("{}: {} -> {}", pkg, initial_version, version));
                }
            } else {
                // NEW package (not in initial baseline at all)
                let pkg_str = format!("{} ({})", pkg, version);
                
                // For NEW packages, categorize by manual vs auto
                // A package is "manual" if it's currently manual AND wasn't manual in initial baseline
                let is_currently_manual = current_manual_packages.contains(pkg);
                let was_initially_manual = initial_manual_packages.contains(pkg);
                
                if is_currently_manual && !was_initially_manual {
                    // NEWLY manual (user installed this)
                    packages_added_manual.push(pkg_str);
                } else {
                    // Auto dependency (even if currently marked manual, it was in initial baseline)
                    packages_added_auto.push(pkg_str);
                }
            }
        }
        
        // Find removed packages
        for (pkg, version) in initial_packages {
            if !current_packages.contains_key(pkg) {
                packages_removed.push(format!("{} ({})", pkg, version));
            }
        }
        
        // Sort the lists for consistency
        changed_file_paths.sort();
        new_manual_paths.sort();
        deleted_files.sort();
        packages_added_manual.sort();
        packages_added_auto.sort();
        packages_removed.sort();
        packages_upgraded.sort();
        
        // Send final progress update
        if let Ok(mut cb) = callback.lock() {
            cb("Analysis complete", all_files.len(), &format!("Found {} changes", all_files.len()));
        }
        
        let file_count = all_files.len() + deleted_files.len();
        let created_at = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        
        // Convert current package sets to storable format
        let current_manual_packages_vec: Vec<String> = current_manual_packages.into_iter().collect();
        
        Ok(Baseline {
            created_at,
            version: chrono::DateTime::from_timestamp(created_at as i64, 0)
                .map(|dt| dt.format("%Y%m%d-%H%M%S").to_string())
                .unwrap_or_else(|| "unknown".to_string()),
            scan_path: initial.remap_to.clone(),  // Delta scans the LIVE system
            remap_to: initial.remap_to.clone(),   // No remapping for delta (already at target)
            file_count,
            is_delta: true,
            files: all_files,
            changed_files: changed_file_paths,
            new_files_manual: new_manual_paths,
            new_files_package: new_package_file_map,
            deleted_files,
            packages_added_manual,
            packages_added_auto,
            packages_removed,
            packages_upgraded,
            installed_packages: current_packages,
            manual_packages: current_manual_packages_vec,
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
    
    /// Scan directory recursively with streaming progress (single pass, no pre-counting)
    fn scan_directory_recursive_streaming<F>(
        path: &Path,
        results: &mut HashMap<String, FileEntry>,
        size_excluded: &mut Vec<(String, u64)>,
        config: &BaselineConfig,
        scan_path: &str,
        remap_to: &str,
        progress_callback: &mut F,
        current_count: usize,
    ) -> io::Result<usize>
    where F: FnMut(usize, usize, &str),
    {
        let mut processed_count = current_count;
        
        // Check if this directory should be excluded (check against REMAPPED path)
        if let Some(path_str) = path.to_str() {
            let remapped_path = Self::remap_path(path_str, scan_path, remap_to);
            for exclude in &config.exclude_directories {
                if remapped_path.starts_with(exclude.as_str()) {
                    return Ok(processed_count);
                }
            }
        }

        if path.is_file() {
            // Process this file
            match Self::process_file(path, config, scan_path, remap_to) {
                Ok((file_entry, excluded_info)) => {
                    let file_path = file_entry.path.clone();
                    results.insert(file_entry.path.clone(), file_entry);
                    if let Some((path, size)) = excluded_info {
                        size_excluded.push((path, size));
                    }
                    
                    // Update progress (use 0 for total since we don't know yet - streaming mode)
                    processed_count += 1;
                    progress_callback(processed_count, 0, &file_path);
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
                            processed_count = Self::scan_directory_recursive_streaming(
                                &entry_path, 
                                results, 
                                size_excluded, 
                                config, 
                                scan_path, 
                                remap_to,
                                progress_callback,
                                processed_count,
                            )?;
                        }
                    }
                }
            }
        }

        Ok(processed_count)
    }
    
    /// Parallel scanning with rayon - automatic work stealing and thread management
    fn scan_parallel<F>(
        scan_path: &Path,
        config: &BaselineConfig,
        scan_path_str: &str,
        remap_to_str: &str,
        cancel_flag: Arc<AtomicBool>,
        callback: Arc<Mutex<F>>,
    ) -> io::Result<(HashMap<String, FileEntry>, Vec<(String, u64)>)>
    where F: FnMut(&str, usize, &str) + Send + 'static,
    {
        use rayon::prelude::*;
        use dashmap::DashMap;
        // Check if cancelled before starting
        if cancel_flag.load(Ordering::Relaxed) {
            return Err(io::Error::new(io::ErrorKind::Interrupted, "Scan cancelled"));
        }
        
        // Thread-safe collections using dashmap (no locks needed!)
        let files = Arc::new(DashMap::new());
        let size_excluded = Arc::new(Mutex::new(Vec::new()));
        
        // Get top-level directories for parallel scanning
        let mut top_level_dirs = Vec::new();
        if let Ok(entries) = fs::read_dir(scan_path) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.is_dir() {
                    // Check if not excluded (use ONLY remapped path for remap feature)
                    if let Some(path_str) = path.to_str() {
                        let remapped = Self::remap_path(path_str, scan_path_str, remap_to_str);
                        let mut excluded = false;
                        for exclude in &config.exclude_directories {
                            if remapped.starts_with(exclude.as_str()) {
                                excluded = true;
                                break;
                            }
                        }
                        if !excluded {
                            top_level_dirs.push(path);
                        }
                    }
                }
            }
        }
        
        if top_level_dirs.is_empty() {
            // No subdirectories, just scan root (single-threaded)
            let mut local_files = HashMap::new();
            let mut local_size_excluded = Vec::new();
            Self::scan_directory_recursive_streaming(
                scan_path,
                &mut local_files,
                &mut local_size_excluded,
                config,
                scan_path_str,
                remap_to_str,
                &mut |_count, _total, path| {
                    if let Ok(mut cb) = callback.lock() {
                        cb(scan_path_str, _count, path);
                    }
                },
                0,
            )?;
            Ok((local_files, local_size_excluded))
        } else {
            // RAYON PARALLEL SCANNING - automatic work stealing!
            // Scan directories in parallel using rayon
            let result: Result<(), io::Error> = top_level_dirs.par_iter().try_for_each(|dir| {
                // Check cancellation
                if cancel_flag.load(Ordering::Relaxed) {
                    return Err(io::Error::new(io::ErrorKind::Interrupted, "Cancelled"));
                }
                
                let physical_path = dir.to_string_lossy().to_string();
                let display_path = Self::remap_path(&physical_path, scan_path_str, remap_to_str);
                
                // Recursively scan this directory
                let mut local_files = HashMap::new();
                let mut local_size_excluded = Vec::new();
                let local_file_count = Self::scan_directory_recursive_streaming(
                    dir,
                    &mut local_files,
                    &mut local_size_excluded,
                    config,
                    scan_path_str,
                    remap_to_str,
                    &mut |count, _total, path| {
                        if let Ok(mut cb) = callback.lock() {
                            cb(&display_path, count, path);
                        }
                    },
                    0,
                )?;
                
                // Merge results into shared collections
                for (path, entry) in local_files {
                    files.insert(path, entry);
                }
                
                        if let Ok(mut excluded) = size_excluded.lock() {
                    excluded.extend(local_size_excluded);
                    }
                    
                // Notify completion
                    if let Ok(mut cb) = callback.lock() {
                    cb(&format!("DONE:{}", display_path), local_file_count, "");
                }
                
                Ok(())
            });
            
            // Check if cancelled or error
            result?;
            
            // Extract results from dashmap - no Arc::try_unwrap needed!
            let final_files: HashMap<String, FileEntry> = files.iter()
                .map(|entry| (entry.key().clone(), entry.value().clone()))
                .collect();
            
            let final_size_excluded = size_excluded.lock()
                .map_err(|e| io::Error::new(io::ErrorKind::Other, format!("Lock poisoned: {:?}", e)))?
                .clone();
            
            Ok((final_files, final_size_excluded))
        }
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

        // Rule 3: Check for extensionless binaries (executable bit check)
        // This covers the "missing case" - files with no extension that are binaries
        if path.extension().is_none() && Self::is_executable(&metadata) {
            return Ok((TrackMode::Exists {
                size,
                modified,
                permissions,
                owner,
                group,
            }, false)); // Not excluded by size
        }

        // Rule 4: Check if file is too large (existence only + LOG IT)
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

    /// Check if a file is executable (has executable bit set)
    /// This is a fast stat() call - much faster than file type detection
    fn is_executable(metadata: &std::fs::Metadata) -> bool {
        use std::os::unix::fs::PermissionsExt;
        let permissions = metadata.permissions();
        let mode = permissions.mode();
        
        // Check for any executable bit (user, group, or other)
        (mode & 0o111) != 0
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
    
    /// Get list of installed packages with versions and install type
    /// Returns (all_packages, manually_installed_set)
    fn get_installed_packages() -> (HashMap<String, String>, std::collections::HashSet<String>) {
        Self::get_installed_packages_from_root(None)
    }
    
    fn get_installed_packages_from_root(root_path: Option<&str>) -> (HashMap<String, String>, std::collections::HashSet<String>) {
        use std::process::Command;
        use std::collections::HashSet;
        use std::thread;
        
        // Spawn parallel workers for package queries
        let root_clone = root_path.map(|s| s.to_string());
        let all_packages_handle = thread::spawn(move || {
            let mut packages = HashMap::new();
            let mut cmd = Command::new("dpkg-query");
            
            // Add --root flag if scanning from a different root
            if let Some(root) = root_clone {
                cmd.arg(format!("--root={}", root));
            }
            
            let output = cmd
                .arg("-W")
                .arg("-f=${Package}\\t${Version}\\n")
                .output();
            
            if let Ok(result) = output {
                if result.status.success() {
                    let stdout = String::from_utf8_lossy(&result.stdout);
                    for line in stdout.lines() {
                        let parts: Vec<&str> = line.split('\t').collect();
                        if parts.len() == 2 {
                            packages.insert(parts[0].to_string(), parts[1].to_string());
                        }
                    }
                }
            }
            packages
        });
        
        let root_clone2 = root_path.map(|s| s.to_string());
        let manual_packages_handle = thread::spawn(move || {
            let mut manually_installed = HashSet::new();
            
            // If we have a root path, we need to read the apt/dpkg database from that root
            if let Some(root) = root_clone2 {
                // Read /var/lib/apt/extended_states from the alternate root
                let states_path = format!("{}/var/lib/apt/extended_states", root);
                if let Ok(content) = std::fs::read_to_string(&states_path) {
                    let mut current_package = String::new();
                    let mut is_auto = false;
                    
                    for line in content.lines() {
                        if line.starts_with("Package: ") {
                            current_package = line[9..].trim().to_string();
                            is_auto = false;
                        } else if line.starts_with("Auto-Installed: 1") {
                            is_auto = true;
                        } else if line.is_empty() && !current_package.is_empty() {
                            if !is_auto {
                                manually_installed.insert(current_package.clone());
                            }
                            current_package.clear();
                        }
                    }
                }
            } else {
                // Use apt-mark for live system
                let output = Command::new("apt-mark")
                    .arg("showmanual")
                    .output();
                
                if let Ok(result) = output {
                    if result.status.success() {
                        let stdout = String::from_utf8_lossy(&result.stdout);
                        for line in stdout.lines() {
                            let trimmed = line.trim();
                            if !trimmed.is_empty() {
                                manually_installed.insert(trimmed.to_string());
                            }
                        }
                    }
                }
            }
            manually_installed
        });
        
        // Wait for both workers to complete
        let all_packages = all_packages_handle.join().unwrap_or_default();
        let manually_installed = manual_packages_handle.join().unwrap_or_default();
        
        (all_packages, manually_installed)
    }
    
    /// Build a fast package file database (one-time cost)
    /// Returns (HashSet of files, HashMap of file->package mappings)
    fn build_package_database<F>(cancel_flag: Arc<AtomicBool>, progress_callback: Arc<Mutex<F>>) -> io::Result<(std::collections::HashSet<String>, HashMap<String, String>)>
    where F: FnMut(usize, usize, String) + Send + 'static
    {
        use std::process::Command;
        use std::collections::HashSet;
        use rayon::prelude::*;
        use dashmap::DashMap;
        use std::sync::atomic::{AtomicUsize, Ordering};
        
        // Get all installed packages
        let (packages, _manually_installed) = Self::get_installed_packages();
        let total_packages = packages.len();
        
        // Get rayon thread pool info
        let num_threads = rayon::current_num_threads();
        
        if let Ok(mut cb) = progress_callback.lock() {
            cb(0, total_packages, format!("Starting parallel build with {} threads...", num_threads));
        }
        
        // Convert to vec for parallel iteration
        let packages_vec: Vec<(String, String)> = packages.into_iter().collect();
        
        // Thread-safe containers
        let file_to_package_map = DashMap::new();
        let processed_count = Arc::new(AtomicUsize::new(0));
        
        // Spawn a progress reporter thread that periodically checks the counter
        let processed_clone = Arc::clone(&processed_count);
        let progress_clone = Arc::clone(&progress_callback);
        let cancel_clone = Arc::clone(&cancel_flag);
        let progress_handle = std::thread::spawn(move || {
            let mut last_reported = 0;
            loop {
                if cancel_clone.load(Ordering::Relaxed) {
                    break;
                }
                
                let current = processed_clone.load(Ordering::Relaxed);
                if current != last_reported {
                    if let Ok(mut cb) = progress_clone.lock() {
                        cb(current, total_packages, format!("Processing dpkg -L ({}/{})", current, total_packages));
                    }
                    last_reported = current;
                }
                
                if current >= total_packages {
                    break;
                }
                
                std::thread::sleep(std::time::Duration::from_millis(100));
            }
        });
        
        // Process packages in parallel using rayon
        let processed_for_closure = Arc::clone(&processed_count);
        let _ = packages_vec.par_iter().try_for_each(|(package, _version)| -> Result<(), ()> {
            // Check for cancellation
            if cancel_flag.load(Ordering::Relaxed) {
                return Err(()); // Stop processing
            }
            let output = Command::new("dpkg")
                .arg("-L")
                .arg(package)
                .output();
            
            if let Ok(result) = output {
                if result.status.success() {
                    let stdout = String::from_utf8_lossy(&result.stdout);
                    for line in stdout.lines() {
                        let trimmed = line.trim();
                        if !trimmed.is_empty() && trimmed.starts_with('/') {
                            file_to_package_map.insert(trimmed.to_string(), package.clone());
                        }
                    }
                }
            }
            
            // Update progress counter (but don't call callback from parallel context)
            let _ = processed_for_closure.fetch_add(1, Ordering::Relaxed);
            
            Ok(())
        });
        
        // Wait for progress thread to finish
        let _ = progress_handle.join();
        
        // Check if cancelled
        if cancel_flag.load(Ordering::Relaxed) {
            return Err(io::Error::new(io::ErrorKind::Interrupted, "Operation cancelled"));
        }
        
        // Update progress after parallel processing
        let processed = processed_count.load(Ordering::Relaxed);
        if let Ok(mut cb) = progress_callback.lock() {
            cb(processed, total_packages, format!("Processed {} packages in parallel...", processed));
        }
        
        // Convert DashMap to regular HashMap and HashSet
        let mut package_files = HashSet::new();
        let mut file_to_package = HashMap::new();
        
        for entry in file_to_package_map.iter() {
            let path = entry.key().clone();
            let pkg = entry.value().clone();
            package_files.insert(path.clone());
            file_to_package.insert(path, pkg);
        }
        
        if let Ok(mut cb) = progress_callback.lock() {
            cb(total_packages, total_packages, format!("Complete! Indexed {} files", package_files.len()));
        }
        
        Ok((package_files, file_to_package))
    }
    
    /// Check if a file is likely package-managed using database + heuristics
    /// Combines dpkg database lookup with pattern-based rules for files dpkg doesn't track
    fn is_likely_package_file(path: &str, package_db: &std::collections::HashSet<String>) -> bool {
        // First check dpkg database
        if package_db.contains(path) {
            return true;
        }
        
        // Fallback heuristics for files dpkg doesn't track (like /boot/firmware)
        
        // Boot firmware files (raspi-firmware package, but dpkg doesn't track them)
        if path.starts_with("/boot/firmware/") {
            // Firmware binaries and device trees are package-managed
            if path.ends_with(".dtb") || path.ends_with(".dtbo") ||
               path.ends_with(".bin") || path.ends_with(".dat") ||
               path.ends_with(".img") || path.ends_with(".elf") ||
               path.contains("/overlays/") ||
               path.contains("kernel") || path.contains("initramfs") ||
               path.contains("fixup") || path.contains("bootcode") ||
               path.ends_with("LICENCE.broadcom") || path.ends_with("issue.txt") {
                return true;
            }
            
            // Config files and custom files are manual
            if path.ends_with("config.txt") || path.ends_with("cmdline.txt") ||
               path.ends_with("ssh") || path.ends_with("wpa_supplicant.conf") {
                return false;
            }
        }
        
        // Default: not a package file
        false
    }
    
    /// Export delta baseline changes to a text file
    /// Uses pre-computed lists from delta creation (already verified against dpkg)
    pub fn export_delta(&self, export_dir: &Path) -> io::Result<PathBuf> {
        use std::io::Write;
        
        if !self.is_delta {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "Can only export delta baselines"
            ));
        }
        
        fs::create_dir_all(export_dir)?;
        
        let filename = format!("changes-{}.txt", self.version);
        let filepath = export_dir.join(&filename);
        let mut file = File::create(&filepath)?;
        
        let total_changes = self.changed_files.len() + self.new_files_manual.len() + self.new_files_package.len() + self.deleted_files.len();
        
        // Write header
        writeln!(file, "Delta Baseline Export")?;
        writeln!(file, "Version: {}", self.version)?;
        writeln!(file, "Generated: {}", chrono::Local::now().format("%Y-%m-%d %H:%M:%S"))?;
        writeln!(file, "")?;
        writeln!(file, "Summary - FILES:")?;
        writeln!(file, "  - Changed:           {}", self.changed_files.len())?;
        writeln!(file, "  - New (Manual):      {} ⚠️  <- Manually installed/created", self.new_files_manual.len())?;
        writeln!(file, "  - New (Package):     {} ℹ️  <- From apt/dpkg packages", self.new_files_package.len())?;
        writeln!(file, "  - Deleted:           {}", self.deleted_files.len())?;
        writeln!(file, "  - Total Files:       {}", total_changes)?;
        writeln!(file, "")?;
        writeln!(file, "Summary - PACKAGES:")?;
        writeln!(file, "  - Added (Manual):    {} ⚠️  <- You installed these", self.packages_added_manual.len())?;
        writeln!(file, "  - Added (Auto):      {} ℹ️  <- Dependencies", self.packages_added_auto.len())?;
        writeln!(file, "  - Removed:           {}", self.packages_removed.len())?;
        writeln!(file, "  - Upgraded:          {}", self.packages_upgraded.len())?;
        writeln!(file, "")?;
        
        // Write packages section with nice box
        writeln!(file, "┌────────────────────────────────────────────────────────────────────────────────────────────────┐")?;
        writeln!(file, "│                                           PACKAGES                                             │")?;
        writeln!(file, "└────────────────────────────────────────────────────────────────────────────────────────────────┘")?;
        writeln!(file, "")?;
        
        // Write package changes first (most important for restoration)
        if !self.packages_added_manual.is_empty() {
            writeln!(file, "┌── MANUAL ADD ({}) ─────────────────────────────────────────", self.packages_added_manual.len())?;
            for pkg in &self.packages_added_manual {
                writeln!(file, "  + {}", pkg)?;
            }
            writeln!(file, "")?;
        }
        
        if !self.packages_removed.is_empty() {
            writeln!(file, "┌── REMOVED ({}) ────────────────────────────────────────────", self.packages_removed.len())?;
            for pkg in &self.packages_removed {
                writeln!(file, "  - {}", pkg)?;
            }
            writeln!(file, "")?;
        }
        
        // Write files section with nice box
        writeln!(file, "┌────────────────────────────────────────────────────────────────────────────────────────────────┐")?;
        writeln!(file, "│                                             FILES                                              │")?;
        writeln!(file, "└────────────────────────────────────────────────────────────────────────────────────────────────┘")?;
        writeln!(file, "")?;
        
        // Write new MANUAL files (most important - these need tracking!)
        if !self.new_files_manual.is_empty() {
            writeln!(file, "┌── MANUAL ADD ({}) ──────────────────────────────────────────", self.new_files_manual.len())?;
            for path in &self.new_files_manual {
                writeln!(file, "  N  {}", path)?;
            }
            writeln!(file, "")?;
        }
        
        // Write changed files
        if !self.changed_files.is_empty() {
            writeln!(file, "┌── MODIFIED ({}) ──────────────────────────────────────────", self.changed_files.len())?;
            for path in &self.changed_files {
                writeln!(file, "  M  {}", path)?;
            }
            writeln!(file, "")?;
        }
        
        // Write system modified section with nice box
        writeln!(file, "┌────────────────────────────────────────────────────────────────────────────────────────────────┐")?;
        writeln!(file, "│                                        SYSTEM MODIFIED                                         │")?;
        writeln!(file, "└────────────────────────────────────────────────────────────────────────────────────────────────┘")?;
        writeln!(file, "")?;
        
        if !self.packages_added_auto.is_empty() {
            writeln!(file, "## PACKAGES ADDED (AUTO-DEPENDENCIES) ({})", self.packages_added_auto.len())?;
            writeln!(file, "# ℹ️  These are dependencies automatically installed")?;
            writeln!(file, "")?;
            for pkg in &self.packages_added_auto {
                writeln!(file, "+ {}", pkg)?;
            }
            writeln!(file, "")?;
        }
        
        if !self.packages_upgraded.is_empty() {
            writeln!(file, "## PACKAGES UPGRADED ({})", self.packages_upgraded.len())?;
            writeln!(file, "")?;
            for pkg in &self.packages_upgraded {
                writeln!(file, "U {}", pkg)?;
            }
            writeln!(file, "")?;
        }
        
        // Write new PACKAGE files (installed by apt/dpkg) with package names
        if !self.new_files_package.is_empty() {
            writeln!(file, "## NEW FILES - FROM PACKAGES ({}) ℹ️", self.new_files_package.len())?;
            writeln!(file, "# These files were installed by apt/dpkg")?;
            writeln!(file, "")?;
            // Sort by package name for better readability
            let mut package_file_list: Vec<_> = self.new_files_package.iter().collect();
            package_file_list.sort_by_key(|(_, pkg)| pkg.as_str());
            for (path, package) in package_file_list {
                writeln!(file, "P  {} ({})", path, package)?;
            }
            writeln!(file, "")?;
        }
        
        // Write deleted files
        if !self.deleted_files.is_empty() {
            writeln!(file, "## DELETED FILES ({})", self.deleted_files.len())?;
            writeln!(file, "")?;
            for path in &self.deleted_files {
                writeln!(file, "D  {}", path)?;
            }
            writeln!(file, "")?;
        }
        
        Ok(filepath)
    }
}

