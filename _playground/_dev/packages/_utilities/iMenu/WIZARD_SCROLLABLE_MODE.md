# Wizard Scrollable Mode

## Overview

By default, the wizard uses an **alternate screen buffer** which prevents scrolling. When content exceeds the terminal height, it gets pushed out of view.

**Scrollable mode** allows the terminal to scroll normally, so you can scroll back to see previous content when it exceeds the terminal height.

## Usage

Enable scrollable mode by setting the `WIZARD_SCROLLABLE` environment variable to `true`:

```bash
# Enable scrollable mode
export WIZARD_SCROLLABLE=true
bash wizard_demo.sh

# Or inline
WIZARD_SCROLLABLE=true bash wizard_demo.sh
```

## Differences

### Default Mode (Alternate Screen Buffer)
- ✅ Clean screen - no scrollback interference
- ✅ Full screen control
- ❌ Content pushed out of view when terminal height exceeded
- ❌ Cannot scroll to see previous content

### Scrollable Mode (`WIZARD_SCROLLABLE=true`)
- ✅ Terminal scrolls normally
- ✅ Can scroll back to see previous content
- ✅ Content never pushed out of view
- ⚠️ May affect terminal scrollback (content remains in scrollback)

## When to Use

**Use scrollable mode when:**
- You have many wizard steps
- Content exceeds terminal height
- You need to review previous selections
- You're debugging wizard behavior

**Use default mode when:**
- You want clean screen transitions
- Content fits within terminal height
- You don't need to review previous content
- You want to preserve terminal scrollback

## Technical Details

When `WIZARD_SCROLLABLE=true`:
- Alternate screen buffer is **not** entered
- Normal terminal scrolling is enabled
- Screen clearing still works (clears content area, preserves header)
- All other wizard functionality remains the same

## Example

```bash
# Run wizard with scrollable mode enabled
WIZARD_SCROLLABLE=true bash wizard_demo.sh

# Or set it in your shell session
export WIZARD_SCROLLABLE=true
bash wizard_demo.sh
bash wizard_inline_demo.sh  # Also scrollable
```

