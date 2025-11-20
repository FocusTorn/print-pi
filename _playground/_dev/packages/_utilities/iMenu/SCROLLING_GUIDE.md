# Terminal Scrolling Guide for iMenu Wizards

## The Issue

By default, iMenu wizards use an **alternate screen buffer** which prevents terminal scrolling. This means:
- ❌ Terminal cannot scroll when content exceeds terminal height
- ✅ Menu options can still navigate (but terminal doesn't scroll)

## Solution: Enable Scrollable Mode

To enable terminal scrolling, you **must** set `WIZARD_SCROLLABLE=true`:

```bash
# Enable terminal scrolling
WIZARD_SCROLLABLE=true bash wizard_demo.sh

# Or export it
export WIZARD_SCROLLABLE=true
bash wizard_demo.sh
```

## Two Different Scroll Settings

### 1. `WIZARD_SCROLLABLE` - Terminal Scrolling
**Purpose**: Allows terminal to scroll when content exceeds terminal height

```bash
WIZARD_SCROLLABLE=true bash wizard_demo.sh
```

**What it does**:
- Disables alternate screen buffer
- Allows terminal scrolling for content
- Content can scroll up/down when it exceeds terminal height

**When to use**: When you want to scroll back and see previous content

### 2. `IMENU_DISABLE_SCROLLING` - Menu Boundary Prevention
**Purpose**: Prevents menu navigation from causing scrolling at boundaries

```bash
IMENU_DISABLE_SCROLLING=true bash wizard_demo.sh
```

**What it does**:
- Prevents menu wrapping at top/bottom
- Menu stops at boundaries instead of wrapping
- Terminal scrolling still works (if `WIZARD_SCROLLABLE=true`)

**When to use**: When you want menu to stop at top/bottom instead of wrapping

## Combined Usage

You can use both together:

```bash
# Enable terminal scrolling AND prevent menu boundary scrolling
WIZARD_SCROLLABLE=true IMENU_DISABLE_SCROLLING=true bash wizard_demo.sh
```

**Result**:
- ✅ Terminal scrolls when content exceeds height
- ✅ Menu stops at top/bottom (no wrapping)
- ✅ Best of both worlds

## Quick Reference

| Setting | Terminal Scrolls? | Menu Wraps? | Use Case |
|---------|------------------|-------------|----------|
| Default | ❌ No | ✅ Yes | Clean screen, content fits |
| `WIZARD_SCROLLABLE=true` | ✅ Yes | ✅ Yes | Need to see previous content |
| `IMENU_DISABLE_SCROLLING=true` | ❌ No* | ❌ No | Prevent menu wrapping |
| Both enabled | ✅ Yes | ❌ No | Scrollable + no wrapping |

*Terminal scrolling only works if `WIZARD_SCROLLABLE=true` is also set

## Troubleshooting

**Problem**: Terminal doesn't scroll when content goes out of view
**Solution**: Set `WIZARD_SCROLLABLE=true`

**Problem**: Menu wraps around when I want it to stop at boundaries
**Solution**: Set `IMENU_DISABLE_SCROLLING=true`

**Problem**: Want both terminal scrolling AND no menu wrapping
**Solution**: Set both `WIZARD_SCROLLABLE=true IMENU_DISABLE_SCROLLING=true`

