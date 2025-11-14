# Extract - Lessons Learned: iMenu Wizard Terminal Position Tracking and Formatting

## 1. :: Shorthand reference Mapping and Explanations

### 1.1. :: Alias Mapping

- **\_strat**: `docs/testing/_Testing-Strategy.md`
- **\_ts**: `docs/testing/_Troubleshooting - Tests.md`
- **lib guide**: `docs/testing/Library-Testing-AI-Guide.md`

### 1.2. :: Details for shorthand execution details:

#### Add to strat

You will understand that _add to strat_ means to do the following:

1. Add the needed documentation to **\_strat**
2. Ensure there is a `### **Documentation References**` to **\_strat** within **guide**
3. Add or modify a concise section with a pointer to the main file for more detail to **guide**

#### Add to trouble

You will understand that _add to trouble_ means to do the following:

1. Add the needed documentation to **\_ts**
2. Ensure there is a `### **Documentation References**` to **\_strat** within **guide**
3. Add or modify a concise section with a pointer to the main file for more detail to **guide**

---

## 2.0 :: Terminal Position Tracking - Viewport-Relative vs Absolute

- Learning: ANSI escape sequence `\033[6n` for cursor position queries returns viewport-relative row positions, not absolute terminal buffer positions. This causes incorrect calculations when terminals are scrolled or have fewer than 100 visible lines.

- Pattern: Use line counting from the start of output instead of cursor position queries. Track lines printed in a persistent counter and calculate absolute positions as `initial_position + lines_printed`.

- Implementation: Initialize `lines_printed` counter to 0 at wizard start. After each output operation (banner, prompts, etc.), increment the counter by the number of lines printed. Calculate `virtual_line_1_row` as `lines_printed + banner_height + 1` without querying cursor position.

- Benefit: Provides accurate absolute positioning regardless of terminal scroll state or viewport size. Eliminates dependency on unreliable cursor position queries that fail in small terminals or scrolled contexts.

- **Not documented**: Terminal position tracking patterns, viewport-relative vs absolute position differences, line counting approach for terminal positioning, limitations of ANSI cursor position queries.

- **Mistake/Assumption**: Initially attempted to query cursor position after printing banner to determine virtual_line_1_row. Assumed cursor queries would return absolute positions. Also tried querying initial position and adding lines, but this still failed with scrolled terminals.

- **Correction**: Removed all cursor position queries. Implemented pure line counting approach: track `lines_printed` from start (initialized to 0), increment after each output operation, calculate positions as `lines_printed + output_height + 1`. This provides absolute positioning based on our own output tracking.

- **Recommendation**:
    - Document terminal position tracking patterns in iMenu package documentation, specifically the line counting approach vs cursor query limitations
    - Add a section to workspace rules about terminal positioning: prefer line counting over cursor queries for absolute positions
    - Create a troubleshooting guide entry for "terminal position tracking fails with scrolled terminals" with the line counting solution

- **Response**: ✏️❓❌⚠️✅ No action required

---

## 2.1 :: Hardcoded Values vs Calculated Values

- Learning: Hardcoded magic numbers (like "6" for virtual_line_1_row) are brittle and incorrect when the actual position differs. Values should be calculated based on actual state, not assumptions.

- Pattern: Always calculate position values based on tracked state (lines printed, banner height, etc.) rather than hardcoding expected values. Use constants for fixed dimensions (banner height) but calculate derived values.

- Implementation: Define banner height as a constant (5 lines), track lines printed, calculate virtual_line_1_row as `lines_printed + banner_height + 1`. Store calculated value in persistent array for later use.

- Benefit: Values remain correct even if banner structure changes or output occurs in different contexts. Makes code more maintainable and less error-prone.

- **Not documented**: Best practices for avoiding hardcoded values in terminal positioning code, pattern of using constants for dimensions and calculations for derived values.

- **Mistake/Assumption**: Initially hardcoded `virtual_line_1_row = 6` assuming banner always starts at line 1 and ends at line 5. User pointed out this was wrong when actual cursor position was at row 10.

- **Correction**: Changed to calculate based on banner height constant and lines printed: `local banner_height=5` and `local virtual_line_1_row=$((lines_printed + banner_height + 1))`. This calculates the actual position dynamically.

- **Recommendation**:
    - Add to coding standards: avoid hardcoded position values, always calculate from tracked state
    - Document the pattern: use constants for dimensions, calculations for derived positions
    - Add code review checklist item: verify no hardcoded terminal position values

- **Response**: ✏️❓❌⚠️✅ No action required

---

## 2.2 :: Persistent Variable Management Across Sourced Scripts

- Learning: Global variables in bash can be lost or inaccessible across sourced scripts. Associative arrays declared in one script may not persist properly. Need explicit global declaration and proper initialization.

- Pattern: Use `declare -gA` for global associative arrays that need to persist across sourced scripts. Store critical state in persistent arrays with getter/setter functions. Add logging for debugging persistence issues.

- Implementation: Created `_WIZARD_PERSISTENT` associative array with `declare -gA _WIZARD_PERSISTENT=()`. Implemented `_wizard_data_set_persistent(key, value)` and `_wizard_data_get_persistent(key)` functions. Added logging to `/home/pi/_playground/_dev/packages/_utilities/iMenu/log.txt` for set/get operations on critical variables like `virtual_line_1_row`.

- Benefit: Ensures state persists correctly across sourced scripts. Logging helps debug when variables aren't being set or retrieved properly. Explicit getter/setter functions provide controlled access.

- **Not documented**: Bash global variable persistence patterns across sourced scripts, associative array declaration requirements, debugging techniques for variable persistence issues.

- **Mistake/Assumption**: Initially used standalone variable `_WIZARD_VIRTUAL_LINE_1_ROW` which wasn't being properly collected or used. Assumed variable would persist automatically across sourced scripts.

- **Correction**: Moved to persistent associative array `_WIZARD_PERSISTENT["virtual_line_1_row"]` with explicit getter/setter functions. Added error checking in `_wizard_display_clear_content()` to error if variable not set (no fallback to default). Added logging for all set/get operations to track persistence.

- **Recommendation**:
    - Document bash global variable persistence patterns, especially for associative arrays across sourced scripts
    - Add pattern: use persistent arrays with getter/setter functions for cross-script state
    - Document debugging approach: add logging for critical variable operations when persistence issues occur

- **Response**: ✏️❓❓❌⚠️✅ No action required

---

## 2.3 :: Sent Section Formatting - Blank Line Management

- Learning: Blank lines in the sent section (completed steps display) need careful management. For multiselect/select prompts, each bullet should be on a separate line with no blank lines between message and bullets or between bullets themselves.

- Pattern: Format multiselect/select results with bullets on separate lines (using `\n    ●` prefix for each), no leading blank line before first bullet, no trailing newline. Display function prints message, then formatted result (which contains newlines), then final newline to end step.

- Implementation: In `_wizard_data_format_result()`, format multiselect/select with `$'\n    ● '"${options_array[$idx]}"` for each selected option. In `_wizard_display_draw_sent_section()`, print message without newline, then formatted result (contains newlines), then final newline. This creates compact display with no gaps.

- Benefit: Creates clean, compact sent section display without unnecessary blank lines. Each step's information is clearly separated but not spaced out excessively.

- **Not documented**: Sent section formatting patterns, blank line management in wizard displays, formatting requirements for different prompt types in sent sections.

- **Mistake/Assumption**: Initially had blank line between message and result for multiselect/select. User corrected: no blank line between message and choices, but each bullet on separate line. Also initially tried putting result on same line as message, but user wanted bullets on separate lines.

- **Correction**: Updated formatting to put each bullet on separate line with `\n    ●` prefix, no leading blank line. Updated display function to print message, then formatted result (which contains the newlines for bullets), then final newline. This gives compact display: message on one line, each bullet on its own line below, no gaps.

- **Recommendation**:
    - Document sent section formatting requirements for each prompt type
    - Add formatting pattern: bullets on separate lines, no blank lines between message and bullets
    - Create visual examples of correct sent section formatting

- **Response**: ✏️❓❌⚠️✅ No action required

---

## 2.4 :: Debug Pause Implementation - Silent and Cursor-Aware

- Learning: Debug pauses should be silent (no messages printed) to avoid messing up cursor positioning. Must ensure native cursor is visible before pausing so user can see current state.

- Pattern: Implement silent debug pauses that show cursor before pausing. Use `_imenu_show_cursor` before each pause. Pause at key points (before clear, before draw) without printing any messages that would affect positioning.

- Implementation: Created `_wizard_debug_pause()` function that calls `_imenu_show_cursor` then does silent `read` (no prompt). Called before every clear operation and before every draw operation when `IWIZARD_DEBUG=true`. No messages printed during pause.

- Benefit: Allows inspection of terminal state at critical points without disrupting cursor positioning or screen layout. Silent pauses don't interfere with the display.

- **Not documented**: Debug pause patterns for terminal applications, silent pause implementation, cursor visibility requirements during debugging.

- **Mistake/Assumption**: Initially debug pauses printed messages which messed up cursor positioning. User corrected: no messages, just pause and ensure cursor is visible.

- **Correction**: Removed all message printing from debug pauses. Made pauses completely silent - just show cursor and wait for keypress. This allows inspection without disrupting layout.

- **Recommendation**:
    - Document debug pause pattern: silent pauses with cursor visibility
    - Add to terminal application debugging guide: never print messages during debug pauses
    - Document the pattern of pausing before clear and before draw operations

- **Response**: ✏️❓❌⚠️✅ No action required

---

## 2.5 :: Signal Handling for Cursor Restoration

- Learning: When processes are interrupted (Ctrl+C), the cursor may not be restored, leaving terminal in bad state. Need signal handlers to ensure cleanup (cursor restoration, temp file removal) on interrupt.

- Pattern: Use `trap` to catch `INT` (Ctrl+C) and `TERM` signals. Create cleanup function that restores cursor and removes temporary files. Call cleanup on both interrupt and normal exit.

- Implementation: Added `trap '_wizard_cleanup; exit 130' INT` and `trap '_wizard_cleanup; exit 143' TERM` in orchestrator. Created `_wizard_cleanup()` function that calls `_imenu_show_cursor` and removes temporary JSON files created during execution.

- Benefit: Ensures terminal is left in usable state even if wizard is interrupted. Prevents cursor from being hidden or terminal from being in bad state after Ctrl+C.

- **Not documented**: Signal handling patterns for terminal applications, cursor restoration on interrupt, cleanup function patterns.

- **Mistake/Assumption**: Initially no signal handling was implemented. User reported cursor didn't return after Ctrl+C.

- **Correction**: Added signal traps for INT and TERM signals. Created cleanup function that restores cursor and cleans up temp files. Ensures graceful exit even on interrupt.

- **Recommendation**:
    - Document signal handling pattern for terminal applications: always trap INT/TERM and restore cursor
    - Add to terminal application checklist: implement cleanup handlers for interrupts
    - Document cleanup function pattern: cursor restoration + temp file removal

- **Response**: ✏️❓❌⚠️✅ No action required

---

