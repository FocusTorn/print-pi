# Scroll Prevention in Select/Multiselect Prompts

## Overview

By default, when navigating select and multiselect menus, the menu wraps around (top to bottom, bottom to top). When `IMENU_DISABLE_SCROLLING=true`, the menu stops at boundaries instead of wrapping, preventing terminal scrolling when navigating at top/bottom.

**Important**: This allows terminal scrolling for content (so text doesn't go out of view), but prevents menu navigation from causing scrolling at boundaries.

## Usage

Enable scroll prevention by setting the `IMENU_DISABLE_SCROLLING` environment variable to `true`:

```bash
# Enable scroll prevention for select/multiselect prompts
export IMENU_DISABLE_SCROLLING=true
bash wizard_demo.sh

# Or inline
IMENU_DISABLE_SCROLLING=true bash wizard_demo.sh
```

## How It Works

When `IMENU_DISABLE_SCROLLING=true`:

1. **Menu navigation**: Arrow keys navigate through options, but stop at top/bottom (no wrapping)
2. **Terminal scrolling**: Still works normally for content that goes out of view
3. **Boundary behavior**: 
   - At top: Up arrow does nothing (stays at top)
   - At bottom: Down arrow does nothing (stays at bottom)

When `IMENU_DISABLE_SCROLLING=false` (default):

- Menu wraps around normally (top → bottom, bottom → top)
- Terminal scrolling works normally

### Technical Details

- Uses boundary-aware navigation instead of disabling scrolling entirely
- Prevents wrapping at menu boundaries when enabled
- Allows terminal scrolling for content visibility
- No scroll region manipulation - uses navigation constraints instead

## When to Use

**Use scroll prevention when:**
- You want to prevent terminal scrolling during menu navigation
- Content is positioned near terminal boundaries
- You want consistent menu behavior regardless of terminal position
- You're using wizards and want to keep previous steps visible

**Don't use scroll prevention when:**
- You want normal terminal scrolling behavior
- Menus are very long and need scrolling to see all options
- You're debugging terminal behavior

## Example

```bash
# Run wizard with scroll prevention enabled
IMENU_DISABLE_SCROLLING=true bash wizard_demo.sh

# Or set it in your shell session
export IMENU_DISABLE_SCROLLING=true
bash wizard_demo.sh
bash wizard_inline_demo.sh  # Also has scroll prevention
```

## Compatibility

- Works with most modern terminals (xterm, gnome-terminal, konsole, etc.)
- May not work with all terminal emulators
- Automatically falls back gracefully if scroll region control is not supported

## Notes

- Scroll prevention only affects **select** and **multiselect** prompts
- Other prompt types (text, confirm, etc.) are not affected
- Scroll prevention is automatically disabled when prompt completes
- If the prompt is cancelled (ESC), scrolling is re-enabled

