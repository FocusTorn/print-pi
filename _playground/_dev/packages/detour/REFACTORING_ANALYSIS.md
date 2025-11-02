# Deep Dive: Detour TUI Refactoring Opportunities

## Executive Summary

After comprehensive analysis, identified **significant duplication** and **architectural inefficiencies** across 3 main areas:
1. **Form Handling** - 90% duplication across 3 form types
2. **CRUD Operations** - Nearly identical patterns for Detours/Injections/Mirrors
3. **View Mode Mapping** - Repeated index-to-enum conversions

**Estimated code reduction: ~800-1000 lines** with proper refactoring.

---

## 1. FORM HANDLING DUPLICATION (CRITICAL)

### Current State
- **23 form methods** in `app.rs` doing identical passthroughs
- Same pattern repeated 3x: DetourForm → InjectionForm → MirrorForm
- Only difference: which form struct they target

### Duplication Examples

```rust
// Pattern repeated 3x:
pub fn form_handle_char(&mut self, c: char) {
    crate::forms::detour_form::handle_char(&mut self.add_form, c);
}
pub fn injection_form_handle_char(&mut self, c: char) {
    crate::forms::injection_form::handle_char(&mut self.injection_form, c);
}
// Missing: mirror_form_handle_char (would be same pattern)
```

### Refactoring Strategy

**Option A: Unified Form Handler (Recommended)**
```rust
// Single dispatch method based on view_mode
pub fn handle_form_input(&mut self, action: FormAction) {
    match self.view_mode {
        ViewMode::DetoursAdd | ViewMode::DetoursEdit => {
            match action {
                FormAction::Char(c) => detour_form::handle_char(&mut self.add_form, c),
                FormAction::Backspace => detour_form::handle_backspace(&mut self.add_form),
                // ... etc
            }
        }
        ViewMode::InjectionsAdd => {
            match action {
                FormAction::Char(c) => injection_form::handle_char(&mut self.injection_form, c),
                // ... etc
            }
        }
        ViewMode::MirrorsAdd | ViewMode::MirrorsEdit => {
            match action {
                FormAction::Char(c) => mirror_form::handle_char(&mut self.mirror_form, c),
                // ... etc
            }
        }
        _ => {}
    }
}
```

**Option B: Trait-Based Forms (Advanced)**
- Create `FormTrait` with generic methods
- Each form implements trait
- Single handler dispatches via trait

**Savings:** ~400 lines removed, single point of maintenance

---

## 2. CRUD OPERATIONS DUPLICATION (HIGH PRIORITY)

### Toggle Pattern (handle_space)

**Current:** 3 nearly identical blocks (60 lines each)

```rust
ViewMode::DetoursList => {
    if let Some(detour) = self.detours.get_mut(self.selected_detour) {
        let new_state = !detour.active;
        let original = detour.original.clone();
        let custom = detour.custom.clone();
        
        let result = if new_state {
            self.detour_manager.apply_detour(&original, &custom)
        } else {
            self.detour_manager.remove_detour(&original)
        };
        
        match result {
            Ok(msg) => {
                detour.active = new_state;
                config_ops::with_config_mut(...); // Update config.enabled
                // Toast/log
            }
            Err(err) => { /* error */ }
        }
    }
}
// Same pattern for InjectionsList and MirrorsList
```

**Refactored:**
```rust
pub fn toggle_active_item(&mut self) {
    match self.view_mode {
        ViewMode::DetoursList => self.toggle_detour(),
        ViewMode::InjectionsList => self.toggle_injection(),
        ViewMode::MirrorsList => self.toggle_mirror(),
        _ => {}
    }
}

fn toggle_detour(&mut self) {
    let (apply_fn, remove_fn, config_path_fn) = (
        |s, o, c| s.detour_manager.apply_detour(o, c),
        |s, o| s.detour_manager.remove_detour(o),
        |config| &mut config.detours,
    );
    self.toggle_generic(
        self.detours.get_mut(self.selected_detour),
        &["original", "custom"],
        apply_fn, remove_fn, config_path_fn,
    )
}
```

**Or better: Trait-based managers**
```rust
trait Toggleable {
    fn apply(&self, app: &mut App) -> Result<String, String>;
    fn remove(&self, app: &mut App) -> Result<String, String>;
    fn config_mut(&mut DetourConfig) -> &mut Vec<Self>;
    fn enabled_field(&mut Self) -> &mut bool;
}
```

**Savings:** ~150 lines, eliminates duplication

---

### Delete Pattern

**Current:** 3 nearly identical delete methods
- `confirm_delete_detour` (~50 lines)
- `confirm_delete_injection` (~60 lines)  
- `confirm_delete_mirror` (~45 lines)

**Same flow:**
1. Check if active, disable first
2. Load config
3. Remove from config
4. Save config
5. Check for file cleanup
6. Reload config
7. Sync selection

**Refactored:**
```rust
pub fn delete_item(&mut self) {
    match self.view_mode {
        ViewMode::DetoursList => self.delete_detour(),
        ViewMode::InjectionsList => self.delete_injection(),
        ViewMode::MirrorsList => self.delete_mirror(),
        _ => {}
    }
}

fn delete_item_generic<T>(
    &mut self,
    item: Option<&mut T>,
    index: usize,
    disable_fn: fn(&mut App, &T) -> Result<(), String>,
    config_get_fn: fn(&mut DetourConfig, usize) -> Option<T>,
    file_check_fn: Option<fn(&T) -> Option<String>>,
) -> Result<(), String>
```

**Savings:** ~120 lines

---

### Save Pattern

**Current:** 3 similar save methods
- `save_detour_to_config` (~50 lines)
- `save_injection_to_config` (~90 lines)
- (Mirrors save not yet implemented, but would follow pattern)

**Differences:**
- Field names (original/custom vs target/include vs source/target)
- Validation logic (slightly different)
- File existence checks (different file ops)

**Refactored:**
```rust
trait ConfigSavable {
    fn validate(&self) -> Result<(), String>;
    fn to_entry(&self) -> Entry;
    fn get_paths(&self) -> (String, String);
    fn should_check_file(&self) -> bool;
}

fn save_to_config<T: ConfigSavable>(&mut self, form: &T, config_fn: fn(&mut DetourConfig) -> &mut Vec<T::Entry>) {
    // Generic save logic
}
```

**Savings:** ~150 lines

---

## 3. VIEW MODE MAPPING DUPLICATION (MEDIUM)

### Current State

**Problem:** Index-to-enum conversion happens in 3+ places:

1. `app.rs::sync_view_mode()`:
```rust
match self.selected_view {
    0 => ViewMode::DetoursList,
    1 => ViewMode::InjectionsList,
    2 => ViewMode::MirrorsList,
    3 => ViewMode::ServicesList,
    4 => ViewMode::StatusOverview,
    5 => ViewMode::LogsLive,
    _ => ViewMode::DetoursList,
}
```

2. `ui.rs::draw_content_column()`:
```rust
match app.selected_view {
    0 => ViewMode::DetoursList,
    1 => ViewMode::InjectionsList,
    2 => ViewMode::MirrorsList,
    // ... same mapping
}
```

3. `app.rs::get_current_actions()` - implicit mapping via view_mode
4. Various other places checking `selected_view` index

### Refactoring

**Option A: Centralized Mapping**
```rust
impl ViewMode {
    fn from_view_index(idx: usize) -> Self {
        const VIEW_MAP: &[ViewMode] = &[
            ViewMode::DetoursList,
            ViewMode::InjectionsList,
            ViewMode::MirrorsList,
            ViewMode::ServicesList,
            ViewMode::StatusOverview,
            ViewMode::LogsLive,
        ];
        VIEW_MAP.get(idx).copied().unwrap_or(ViewMode::DetoursList)
    }
}
```

**Option B: Derive from views Vec**
```rust
// Sync views with ViewMode enum order
const VIEW_MODES: &[ViewMode] = &[...];

fn sync_view_mode(&mut self) {
    self.view_mode = VIEW_MODES.get(self.selected_view)
        .copied()
        .unwrap_or(ViewMode::DetoursList);
}
```

**Savings:** Eliminates repeated mappings, single source of truth

---

## 4. STRING CLONING INEFFICIENCIES (LOW-MEDIUM)

### Patterns Found

1. **Unnecessary clones before closure capture:**
```rust
let original = detour.original.clone();
let custom = detour.custom.clone();
// ... then used in closure
config_ops::with_config_mut(|config| {
    if let Some(entry) = config.detours.iter_mut().find(|e| e.original == original) {
        // Could use reference instead
    }
})
```

**Fix:** Use references or clone only when necessary

2. **trim().to_string() patterns:**
```rust
let target = self.injection_form.target_path.trim().to_string();
let include = self.injection_form.include_path.trim().to_string();
```

**Fix:** Extract to helper or use `String::from` consistently

3. **Multiple clones of same value:**
```rust
let target_clone = target.clone();
let include_clone = include.clone();
// Then target_clone used once...
```

**Savings:** Minor memory, but improves code clarity

---

## 5. CONFIG OPERATIONS PATTERNS (MEDIUM)

### Current State

**Repeated pattern:**
```rust
use crate::operations::config_ops;
config_ops::with_config_mut(&self.config_path, |config| {
    // Find entry
    if let Some(entry) = config.detours.iter_mut().find(|e| e.field == value) {
        entry.enabled = new_state;
    }
    Ok(())
});
```

**Refactored:**
```rust
// Helper methods
pub fn update_entry_enabled<T, F>(config_path: &str, find_fn: F, enabled: bool) -> Result<(), String>
where
    F: Fn(&mut DetourConfig) -> &mut Vec<T>,
    T: HasEnabled,
{
    config_ops::with_config_mut(config_path, |config| {
        let vec = find_fn(config);
        if let Some(entry) = vec.iter_mut().find(...) {
            entry.set_enabled(enabled);
        }
        Ok(())
    })
}
```

**Savings:** ~50 lines, reduces boilerplate

---

## 6. FILE BROWSER INTEGRATION (LOW)

### Current State

**Duplication:**
- `form_open_file_browser` - detours
- `injection_form_open_file_browser` - injections
- (Mirrors would need same)

**Similar logic:** Determine start path based on active field

**Refactored:**
```rust
fn open_file_browser_for_form(&mut self, paths: &[String], active_field: usize) {
    let start_path = paths.get(active_field)
        .and_then(|p| Path::new(p).parent())
        .and_then(|p| p.to_str())
        .unwrap_or("/home/pi");
    self.file_browser = Some(FileBrowser::new(start_path));
}
```

**Savings:** ~40 lines

---

## PRIORITY RANKING

1. **CRITICAL:** Form handling unification (~400 lines)
2. **HIGH:** CRUD operations (toggle, delete, save) (~420 lines)
3. **MEDIUM:** View mode mapping consolidation (~50 lines)
4. **MEDIUM:** Config operation helpers (~50 lines)
5. **LOW:** String cloning optimizations (~20 lines)
6. **LOW:** File browser unification (~40 lines)

**Total Estimated Savings: ~980 lines**

---

## IMPLEMENTATION STRATEGY

### Phase 1: Form Handling (Low Risk)
- Create unified form handler
- Update events.rs to use it
- Remove duplicate methods
- **Risk:** Low, isolated to form input

### Phase 2: Toggle Operations (Medium Risk)
- Extract toggle logic to generic function
- Test thoroughly with each item type
- **Risk:** Medium, touches core functionality

### Phase 3: Delete Operations (Medium Risk)
- Extract delete pattern
- Handle edge cases (file cleanup differs)
- **Risk:** Medium, critical operation

### Phase 4: Save Operations (Higher Risk)
- Extract save pattern
- Validate all form types work
- **Risk:** Higher, data persistence

### Phase 5: Cleanup (Low Risk)
- View mode mapping
- String optimizations
- **Risk:** Low, mostly cosmetic

---

## NOTES

- **Backwards Compatibility:** All refactoring maintains same API surface
- **Testing:** Need comprehensive tests before Phase 2-4
- **Incremental:** Can do Phase 1 independently, validate, continue
- **Documentation:** Update as refactoring progresses

---

## METRICS

**Current State:**
- `app.rs`: ~1875 lines
- `events.rs`: ~559 lines
- `ui.rs`: ~1037 lines
- **Total:** ~3471 lines

**After Refactoring:**
- Estimated: ~2491 lines
- **Reduction:** ~28% code reduction
- **Maintainability:** Significantly improved
- **New feature speed:** Much faster (add Mirrors form = 50 lines vs 200+ lines)

