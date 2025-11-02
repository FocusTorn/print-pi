# Codebase Duplication Analysis (Post Component Migration)

## Summary
- **Total Lines**: 5,727
- **Largest File**: `app.rs` (2,199 lines - 38% of codebase)
- **Components Created**: ✅ ListPanel, FormPanel (both Detours and Includes now use them)

## Duplication Patterns Identified

### 1. Form Operations (21 functions in app.rs)

#### Detours Form Functions:
```
- form_handle_char()
- form_backspace()
- form_move_cursor_left()
- form_move_cursor_right()
- form_next_field()
- form_prev_field()
- form_cancel()
- form_save_detour()
- form_open_file_browser()
- form_close_file_browser()
- form_complete_path()        ⚠️ Tab completion
- form_paste_clipboard()
```

#### Includes Form Functions:
```
- includes_form_handle_char()
- includes_form_backspace()
- includes_form_move_cursor_left()
- includes_form_move_cursor_right()
- includes_form_next_field()
- includes_form_prev_field()
- includes_form_cancel()
- includes_form_submit()
- includes_form_open_file_browser()
- includes_form_close_file_browser()
- includes_form_complete_path()   ⚠️ Tab completion
- includes_form_paste_clipboard()
```

**Duplication Level**: ~95% identical logic, different form struct access
**Estimated Lines**: ~400 lines duplicated

---

### 2. Save/Delete Patterns

#### Detours:
```rust
save_detour_to_config()
├── Validate paths
├── Check if custom file exists → prompt if not
├── Load config
├── Update or add entry
├── Save config
├── Reload config
└── Apply detour if enabled

confirm_delete_detour()
├── Get detour from list (active state)
├── Check if active → unmount first
├── Load config
├── Remove from config
├── Save config
├── Check if custom file exists → prompt to delete
└── Reload and adjust selection

delete_detour_and_file()
└── Remove file, reload config, adjust selection
```

#### Includes:
```rust
save_include_to_config()
├── Validate paths
├── Check if include file exists → prompt if not
├── Load config
├── Update or add entry
├── Save config
├── Apply include if enabled (new entries)
└── Reload config

confirm_delete_include()
├── Get include from list (active state)
├── Check if active → remove directive first
├── Load config
├── Remove from config
├── Save config
├── Check if include file exists → prompt to delete
└── Reload and adjust selection

delete_include_and_file()
└── Remove file, reload config, adjust selection
```

**Duplication Level**: ~80% identical flow, different manager calls
**Estimated Lines**: ~300 lines duplicated

---

### 3. Activation/Deactivation Patterns

#### Current Scattered Logic:

**Space Key Handler** (events.rs):
```rust
ViewMode::DetoursList => {
    Toggle detour.active
    if active → detour_manager.apply()
    else → detour_manager.remove()
    Update config.enabled
    Save config
}

ViewMode::IncludesList => {
    Toggle include.active
    if active → include_manager.apply()
    else → include_manager.remove()
    Update config.enabled
    Save config
}
```

**New Include Creation** (app.rs):
```rust
After saving config with enabled: true:
├── Reload config
├── Find include in list
├── If not active → include_manager.apply()
└── Set include.active = true
```

**Duplication Level**: Activation logic duplicated in 3+ places
**Estimated Lines**: ~150 lines duplicated

---

### 4. File Operations

#### Duplicate File Creation:
```rust
create_custom_file_and_save() [Detours]
├── Get original_path, custom_path from form
├── Create parent directories
├── Read original file contents
├── Write to custom file (duplicate)
└── Save detour to config

create_include_file_and_save() [Includes]
├── Get target_path, include_path from form
├── Create parent directories
├── Read target file contents
├── Write to include file (duplicate)
└── Save include to config
```

**Duplication Level**: ~90% identical, just different field names
**Estimated Lines**: ~100 lines duplicated

#### Delete File with Prompt:
```rust
delete_detour_and_file()
delete_include_and_file()
// Both identical except for paths
```

**Duplication Level**: ~95% identical
**Estimated Lines**: ~40 lines duplicated

---

### 5. Config Operations

**Pattern Repeated 6+ Times:**
```rust
// Load config
let mut config = DetourConfig::parse(&self.config_path)
    .unwrap_or_else(|_| DetourConfig { ... });

// Modify config
// ...

// Save config
if let Ok(yaml) = serde_yaml::to_string(&config) {
    if let Err(e) = std::fs::write(&self.config_path, yaml) {
        // error handling
    }
    // Success path
} else {
    // Serialization error
}
```

**Duplication Level**: Exact same pattern repeated
**Estimated Lines**: ~180 lines duplicated

---

### 6. Path Validation

**Repeated Pattern:**
```rust
if target.is_empty() || custom.is_empty() {
    self.show_error("Validation Error", "Paths are required".to_string());
    return;
}
```

**Duplication Level**: Same validation logic in multiple places
**Estimated Lines**: ~20 lines duplicated

---

## Refactoring Opportunities

### High Impact (Large duplication, frequently changed):

1. **Form Operations** (~400 lines) → `forms/base.rs`
   - Create trait or generic helper for form input handling
   - Single implementation, parameterized by form type

2. **Config Operations** (~180 lines) → `operations/config_ops.rs`
   - Helper functions: `with_config()`, `update_config()`, `save_config()`
   - Reduces boilerplate by 80%

3. **Save/Delete Patterns** (~300 lines) → `operations/save_delete.rs`
   - Generic save pattern
   - Generic delete pattern with cleanup hooks

### Medium Impact:

4. **Activation Logic** (~150 lines) → `operations/activation.rs`
   - Unified activate/deactivate for detours and includes
   - Handles apply, remove, state update, config update

5. **File Operations** (~140 lines) → `operations/file_ops.rs`
   - Generic file duplication
   - Generic file deletion with prompt
   - Directory creation helpers

### Low Impact (Quick wins):

6. **Validation** (~20 lines) → `validation.rs`
   - Path validation helpers
   - Reusable error messages

---

## Estimated Refactoring Impact

| Module | Current | After | Reduction |
|-------|---------|-------|-----------|
| app.rs | 2,199 | ~800 | 64% |
| forms/base.rs | 0 | ~200 | New |
| forms/detour_form.rs | 0 | ~150 | New |
| forms/include_form.rs | 0 | ~150 | New |
| operations/activation.rs | 0 | ~100 | New |
| operations/file_ops.rs | 0 | ~140 | New |
| operations/config_ops.rs | 0 | ~150 | New |
| validation.rs | 0 | ~50 | New |
| **Total** | **2,199** | **1,740** | **21% reduction** |

**Net Benefit**: 
- 21% less code overall
- 64% reduction in app.rs complexity
- Better organization and maintainability
- Single place to change for each concern

---

## Migration Priority

1. ✅ **DONE**: Migrate Detours to use ListPanel/FormPanel components
2. **NEXT**: Extract form operations (biggest win, ~400 lines)
3. **THEN**: Extract config operations (most repeated pattern)
4. **THEN**: Extract save/delete patterns
5. **THEN**: Extract activation logic
6. **FINALLY**: Extract file ops and validation

---

## Notes

- Tab completion works for both forms but is duplicated
- Both forms now use FormPanel component for rendering
- Both lists now use ListPanel component for rendering
- Form event handling is still separate (needs consolidation)

