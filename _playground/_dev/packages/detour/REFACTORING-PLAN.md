# Refactoring Plan: DRY and Optimization

## Current Issues

**app.rs**: 2199 lines - too large, handling too many concerns

### Duplication Identified:

1. **Form Handling** - Detours and Includes have nearly identical form logic:
   - `*_form_handle_char`, `*_form_backspace`, `*_form_move_cursor_*`
   - `*_form_next_field`, `*_form_prev_field`, `*_form_cancel`
   - `*_form_open_file_browser`, `*_form_close_file_browser`
   - `*_form_complete_path`, `*_form_paste_clipboard` ⚠️ **Tab completion is duplicated**
   
   **Note**: `form_panel` component handles rendering only. Input handling is in `events.rs` → `app.rs`, causing duplication.

2. **Save/Delete Patterns** - Very similar flows:
   - `save_detour_to_config()` vs `save_include_to_config()`
   - `confirm_delete_detour()` vs `confirm_delete_include()`
   - `delete_detour_and_file()` vs `delete_include_and_file()`
   - Both check for active state, remove from config, prompt for file deletion

3. **Activation Logic** - Scattered across multiple places:
   - Space key handler calls `include_manager.apply()` or `detour_manager.apply()`
   - New include creation calls `include_manager.apply()` directly
   - Edit flows may need activation
   - All do similar: apply, update state, update config

4. **File Operations** - Duplicated logic:
   - `create_custom_file_and_save()` and `create_include_file_and_save()` - both duplicate target file
   - Both check for file existence and prompt
   - Both create parent directories

## Proposed Structure

```
src/
├── app.rs                    # Core state (~800 lines)
├── forms/
│   ├── mod.rs
│   ├── base.rs              # Shared form operations (cursor, navigation, clipboard)
│   ├── detour_form.rs       # Detour-specific form handling
│   └── include_form.rs      # Include-specific form handling
├── operations/
│   ├── mod.rs
│   ├── activation.rs        # Shared activate/deactivate logic for detours & includes
│   ├── file_ops.rs          # File creation, duplication, deletion with prompts
│   └── config_ops.rs       # Config save, update, reload patterns
├── validation.rs            # Shared validation helpers
├── components/              # (existing)
├── include.rs               # (existing)
├── manager.rs               # (existing)
└── ...
```

## Extraction Plan

### 1. forms/base.rs
**Extract common form operations:**
- `handle_char`, `backspace`, `move_cursor_left/right`
- `next_field`, `prev_field`, `cancel`
- `open_file_browser`, `close_file_browser`
- `complete_path`, `paste_clipboard`

**Use traits or generics to share between detour/include forms**

### 2. forms/detour_form.rs
**Extract:**
- `save_detour_to_config()`
- `create_custom_file_and_save()`
- Detour-specific form state management
- ~300 lines → ~150 lines

### 3. forms/include_form.rs
**Extract:**
- `save_include_to_config()`
- `create_include_file_and_save()`
- Include-specific form state management
- ~350 lines → ~150 lines

### 4. operations/activation.rs
**Unified activation/deactivation:**
```rust
pub struct ActivationOps {
    pub detour_manager: DetourManager,
    pub include_manager: IncludeManager,
}

impl ActivationOps {
    pub fn activate_detour(&self, ...) -> Result<()>
    pub fn deactivate_detour(&self, ...) -> Result<()>
    pub fn activate_include(&self, ...) -> Result<()>
    pub fn deactivate_include(&self, ...) -> Result<()>
}
```
**Handles:**
- Apply/remove directives
- Update state
- Update config
- Error handling and logging

### 5. operations/file_ops.rs
**Shared file operations:**
```rust
pub fn duplicate_file_with_prompt(
    source: &Path,
    dest: &Path,
    on_prompt: impl Fn(&Path) -> bool,
) -> Result<()>

pub fn delete_file_with_prompt(
    path: &Path,
    on_prompt: impl Fn(&Path) -> bool,
) -> Result<()>

pub fn ensure_parent_dirs(path: &Path) -> Result<()>
```

### 6. operations/config_ops.rs
**Config operation patterns:**
```rust
pub fn save_entry_to_config<T>(
    config_path: &Path,
    update_fn: impl FnOnce(&mut DetourConfig) -> Result<T>,
) -> Result<T>

pub fn remove_entry_with_cleanup(
    config_path: &Path,
    index: usize,
    entry_type: EntryType,
    cleanup_fn: impl FnOnce(&Entry) -> Result<()>,
) -> Result<()>
```

### 7. validation.rs
**Shared validation:**
- Path validation
- File existence checks
- Config validation helpers

## Benefits

1. **Reduced Duplication**: ~40% less code in app.rs
2. **Easier Changes**: Modify one place for form/file/config operations
3. **Better Testing**: Isolated modules can be unit tested
4. **Clearer Structure**: Each file has a single responsibility
5. **Reusability**: Components can be used in new features

## Migration Strategy

1. Create new module structure
2. Extract one concern at a time (forms → operations → validation)
3. Update app.rs to use new modules
4. Test after each extraction
5. Remove old code when fully migrated

## Estimated Impact

- **app.rs**: 2199 lines → ~800 lines (63% reduction)
- **New modules**: ~1200 lines total (better organized)
- **Net**: Slightly more code but much better structured and DRY

