# Wizard Clearing Improvements

## Problem

The original wizard implementation used `_imenu_clear_screen()` which clears the **entire screen**, including the header. This approach:
- Creates a "new window" effect (full screen clear)
- Can cause options to not be visible after choices are made
- Is inefficient (clears and redraws everything)

## Solution

Implemented **line-tracking clearing** that:
1. **Preserves the header** - Only clears content area (from line 6 downward)
2. **Uses cursor positioning** - Moves to content start line, then clears to end of screen
3. **Tracks content lines** - Counts lines drawn for optimization (though `\033[J` handles clearing)

## Changes Made

### `wizard-display.sh`

1. **Added line tracking variables:**
   - `_WIZARD_CONTENT_START_LINE=6` - Content starts after 5-line header
   - `_WIZARD_CONTENT_LINES=0` - Tracks lines drawn

2. **Improved `_wizard_display_clear_content()`:**
   ```bash
   # Old: Cleared entire screen
   _imenu_clear_screen
   
   # New: Clears only content area
   printf '\033[%d;1H' "$_WIZARD_CONTENT_START_LINE" >&2  # Move to line 6
   printf '\033[J' >&2  # Clear from cursor to end of screen
   ```

3. **Enhanced `_wizard_display_draw_sent_section()`:**
   - Now tracks lines drawn for each step type
   - Updates `_WIZARD_CONTENT_LINES` for efficient clearing

## Benefits

✅ **Header preserved** - Banner stays visible throughout wizard  
✅ **More efficient** - Only clears content, not entire screen  
✅ **Better UX** - No "new window" effect, smoother transitions  
✅ **Options visible** - Content clearing ensures prompt redraws correctly  

## Technical Details

### Clearing Method

Uses ANSI escape sequences:
- `\033[6;1H` - Move cursor to line 6, column 1 (content start)
- `\033[J` - Clear from cursor position to end of screen

This is more reliable than line-by-line clearing and works well with alternate screen buffers.

### Line Tracking

While `\033[J` clears everything from cursor to end, tracking lines helps with:
- Optimization (knowing when clearing is needed)
- Future enhancements (selective clearing)
- Debugging (understanding content layout)

## Testing

Test the improved clearing:
```bash
cd /home/pi/_playground/_dev/packages/_utilities/iMenu/demos
bash wizard_demo.sh
```

You should see:
- Header remains visible throughout
- Previous selections shown dimmed
- Active prompt options fully visible
- Smooth transitions between steps

## About Charm

**Charm** (charm.sh) is a Go-based terminal UI library, not a bash tool. While it offers excellent terminal UI capabilities, it would require:
- Rewriting iMenu in Go
- Losing bash compatibility
- Significant architectural changes

**Recommendation:** The improved line-tracking clearing approach is better suited for iMenu's bash-based architecture and provides the same benefits (dynamic clearing, preserved selections, smooth UX) without requiring a complete rewrite.

## Future Enhancements

Possible improvements:
1. **Selective line clearing** - Clear only changed lines (more complex)
2. **Scrollback preservation** - Better handling of long content
3. **Animation support** - Smooth transitions between steps
4. **Better line counting** - More accurate tracking for complex prompts

