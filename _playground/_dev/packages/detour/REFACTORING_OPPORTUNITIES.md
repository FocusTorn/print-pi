# Refactoring Opportunities

Based on code analysis, here are areas that would benefit from similar optimization approaches:

## 1. Content Column Navigation (HIGH PRIORITY)
**Location:** `app.rs` - `navigate_up()` and `navigate_down()`

**Problem:** Duplicated pattern for handling different view modes in Content column:
- Same bounds checking logic repeated for `DetoursList`, `InjectionsList`, `ServicesList`
- Similar pattern of updating selection index and ListState

**Solution:** Create a trait or helper functions:
```rust
trait SelectableList {
    fn len(&self) -> usize;
    fn select_index(&mut self, index: usize);
}

// Or helper methods:
fn navigate_content_up(&mut self)
fn navigate_content_down(&mut self)
```

**Benefits:**
- Eliminates ~30 lines of duplicated code
- Makes adding new list views easier
- Centralizes bounds checking logic

---

## 2. Selection State Synchronization (MEDIUM PRIORITY)
**Location:** `app.rs` - Multiple places updating `selected_*` and corresponding `*_state`

**Problem:** Multiple selection indices and ListState fields that need to stay in sync:
- `selected_detour` ↔ `detour_state`
- `selected_injection` ↔ `injection_state`  
- `selected_service` ↔ `service_state`

**Solution:** Helper methods to sync selection state:
```rust
fn sync_detour_selection(&mut self) {
    self.detour_state.select(
        if self.detours.is_empty() { None } 
        else { Some(self.selected_detour.min(self.detours.len() - 1)) }
    );
}
```

**Benefits:**
- Ensures state always stays in sync
- Centralizes bounds checking
- Reduces risk of out-of-sync bugs

---

## 3. ViewMode-based Action Dispatch (MEDIUM PRIORITY)
**Location:** `app.rs` - `handle_space()`, `handle_enter()`, event handlers

**Problem:** Repeated pattern of matching on `view_mode` to dispatch to view-specific logic:
```rust
match self.view_mode {
    ViewMode::DetoursList => { /* detour logic */ }
    ViewMode::InjectionsList => { /* injection logic */ }
    // Pattern repeats...
}
```

**Solution:** Create a trait or enum-based dispatch:
```rust
trait ViewHandler {
    fn handle_space(&mut self, app: &mut App);
    fn handle_enter(&mut self, app: &mut App);
    // etc.
}
```

**Benefits:**
- Moves view-specific logic into separate modules
- Easier to add new views (implement trait)
- Better separation of concerns

---

## 4. Help Text Generation (LOW PRIORITY)
**Location:** `ui.rs` - `get_panel_help()`

**Problem:** Nested match statements (ViewMode → ActiveColumn → String)

**Solution:** Lookup table or helper methods:
```rust
fn get_help_for_view(view_mode: ViewMode, column: ActiveColumn) -> &'static str {
    // Use const lookup table
}
```

**Benefits:**
- Simpler, more maintainable
- Easy to update help text
- Less nested conditionals

---

## 5. List Bounds Validation (MEDIUM PRIORITY)
**Location:** `app.rs` - `reload_config()` method

**Problem:** Repetitive bounds checking for each selection type:
```rust
if self.selected_detour >= self.detours.len() && !self.detours.is_empty() {
    self.selected_detour = self.detours.len() - 1;
}
// Same pattern for injections...
```

**Solution:** Generic bounds checking helper:
```rust
fn validate_selection_bounds(&mut self) {
    self.selected_detour = self.selected_detour.min(self.detours.len().saturating_sub(1));
    self.selected_injection = self.selected_injection.min(self.injections.len().saturating_sub(1));
    // etc.
}
```

**Benefits:**
- Single place to fix bounds bugs
- Consistent behavior across all lists
- Less code duplication

---

## 6. Content Rendering Dispatch (LOW PRIORITY)
**Location:** `ui.rs` - `draw_content_column()`

**Problem:** Large match statement mapping ViewMode to draw functions

**Solution:** Could use a macro or dispatch table, but current approach is fine for clarity

**Recommendation:** Keep as-is unless number of views grows significantly (>15 views)

---

---

## 7. Description String Handling (IMPLEMENTED ✅)
**Location:** `app.rs` - `save_detour_to_config()`, `save_injection_to_config()`

**Problem:** Repeated pattern:
```rust
description: if desc.is_empty() { None } else { Some(desc.clone()) }
```

**Solution:** Created `description_from_str()` helper method

**Status:** ✅ Implemented - Eliminates 4+ instances of duplication

---

## 8. Edit/Delete Action Handling (IMPLEMENTED ✅)
**Location:** `events.rs` - Edit and Delete key handlers

**Problem:** Repeated if/else chains checking view_mode:
```rust
if app.view_mode == ViewMode::DetoursList {
    app.edit_selected_detour();
} else if app.view_mode == ViewMode::InjectionsList {
    app.edit_selected_injection();
}
```

**Solution:** Created `handle_edit_action()` and `handle_delete_action()` methods

**Status:** ✅ Implemented - Centralizes action dispatch logic

---

## Additional Opportunities Found

### 9. Toggle Logic Similarity (LOW PRIORITY)
**Location:** `app.rs` - `handle_space()` for DetoursList and InjectionsList

**Problem:** Very similar toggle logic for detours and injections:
- Both check if item exists
- Both toggle active state
- Both call manager apply/remove
- Both update config
- Both show toast/log

**Solution:** Could extract to generic toggle method, but current approach is clear enough

**Recommendation:** Keep as-is unless adding more similar views

---

### 10. String Allocation Patterns (VERY LOW PRIORITY)
**Location:** Throughout codebase

**Problem:** 116 instances of `.clone()`, `.to_string()`, `String::from()`

**Analysis:** Most are necessary for ownership transfer. A few could use references or Cow, but optimization would be premature.

**Recommendation:** Monitor if performance issues arise, but don't optimize prematurely

---

## Implementation Status

✅ **Completed:**
1. Content Column Navigation - Helper methods extracted
2. Selection State Synchronization - Sync helpers created
3. List Bounds Validation - Validation helper implemented
4. Description String Handling - Helper method created
5. Edit/Delete Action Handling - Centralized action methods

## Priority Recommendations

1. ✅ **#1 (Content Navigation)** - COMPLETE
2. ✅ **#3 (Bounds Validation)** - COMPLETE
3. ✅ **#2 (Selection Sync)** - COMPLETE
4. ✅ **#7 (Description Handling)** - COMPLETE
5. ✅ **#8 (Action Handling)** - COMPLETE
6. **#3 (ViewMode Dispatch)** - Could be future work if views multiply significantly

