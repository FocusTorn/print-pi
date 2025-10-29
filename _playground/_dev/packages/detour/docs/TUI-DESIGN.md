# Detour TUI Design - Horizontal Layout

## Design Philosophy

**Target Terminal:** Wide but short (e.g., 180x25, 200x30)
**Layout Style:** Horizontal 3-column layout (like chamon)

## Main Screen Layout

```
┌─ Detour ───────────────────────────────────────────────────────────────────────────────────────┐
│ Profile: default  |  3 active detours  |  Status: ✓ All synced                                 │
├────────┬────────────────────┬────────────────────────────────────────────────────────────────────┤
│        │                    │                                                                    │
│ Views  │    Actions         │  Content Area                                                     │
│        │                    │                                                                    │
│ Detour │    List            │ ┌─ Active Detours (3) ─────────────────────────────────────────┐ │
│ Includ │    Add             │ │ /etc/nginx/nginx.conf → ../_playground/nginx/nginx.conf      │ │
│ Servic │    Edit            │ │   Modified: 2h ago  |  Size: 12.5 KB  |  ⚠️  Restart needed   │ │
│ Status │    Toggle          │ │                                                               │ │
│ Logs   │    Validate        │ │ /home/pi/homeassistant/.vscode/settings.json                 │ │
│ Config │    Remove          │ │   → ../_playground/homeassistant/.vscode/settings.json       │ │
│        │                    │ │   Modified: 5m ago  |  Size: 3.2 KB  |  ✓ Active             │ │
│        │                    │ │                                                               │ │
│        │                    │ │ /home/pi/klipper/printer.cfg → ../_playground/klipper/...   │ │
│        │                    │ │   ❌ Target missing!  |  💡 Create or fix path                │ │
│        │                    │ └───────────────────────────────────────────────────────────────┘ │
│        │                    │                                                                    │
├────────┴────────────────────┴────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│ [Tab] Next Panel  [↑↓] Navigate  [Enter] Select  [?] Help  [Q] Quit                            │
│ ──────────────────────────────────────────────────────────────────────────────────────────────  │
│ Detours redirect file reads to custom versions using bind mounts                               │
└──────────────────────────────────────────────────────────────────────────────────────────────────┘
```

## Column Structure

### Column 1: Views (Narrow ~12 chars)
```
┌──────────┐
│ Detours  │  ← Main view
│ Includes │
│ Services │
│ Status   │
│ Logs     │
│ Config   │
│ Help     │
└──────────┘
```

### Column 2: Actions (Medium ~20 chars)
Dynamic based on selected view:

**When "Detours" selected:**
```
┌──────────────────┐
│ List             │
│ Add              │
│ Edit             │
│ Toggle           │ ◄─ select indicator
│ Validate         │
│ Remove           │
│ Backup           │
│ Restore          │
└──────────────────┘
```

**When "Includes" selected:**
```
┌──────────────────┐
│ List             │
│ Add Include      │
│ Remove           │
│ Test Injection   │
└──────────────────┘
```

**When "Logs" selected:**
```
┌──────────────────┐
│ Live View        │
│ Filter           │
│ Search           │
│ Export           │
│ Clear            │
└──────────────────┘
```

### Column 3: Content (Wide - Remaining space)

Changes based on View + Action combination.

## Content Area Views

### 1. Detours → List (Default)
```
┌─ Active Detours (3) ─┬─ Inactive (1) ────────────────────────────────────┐
│                       │                                                   │
│ /etc/nginx/nginx.conf │ /opt/old-app/config.yaml                         │
│   → _playground/...   │   → _playground/...                              │
│   📝 2h  📏 12 KB ⚠️   │   📝 3d  📏 5 KB 💤                               │
│                       │                                                   │
│ /home/pi/.../settings │ ─────────────────────────────────────────────────│
│   → _playground/...   │ Stats:                                            │
│   📝 5m  📏 3 KB ✓     │   Total: 4 detours                                │
│                       │   Active: 3  Inactive: 1                          │
│ /home/pi/.../printer  │   Disk: +15 MB                                    │
│   → _playground/...   │                                                   │
│   ❌ Target missing    │                                                   │
└───────────────────────┴───────────────────────────────────────────────────┘
```

### 2. Detours → Add
```
┌─ Add New Detour ──────────────────────────────────────────────────────────┐
│                                                                            │
│ Original Path:  /home/pi/homeassistant/configuration.yaml▊                │
│                 [Tab] suggestions  [Ctrl+F] Browse                         │
│                                                                            │
│ Custom Path:    /home/pi/_playground/homeassistant/configuration.yaml     │
│                 ✓ File exists (3.8 KB, modified today)                    │
│                                                                            │
│ ┌─ Options ───────────────────────────────────────────────────────────┐   │
│ │ [x] Create backup    [ ] Restart services    [x] Add to profile     │   │
│ └─────────────────────────────────────────────────────────────────────┘   │
│                                                                            │
│ ┌─ Preview ───────────────────────────────────────────────────────────┐   │
│ │ This will:                                                           │   │
│ │  1. Backup original to: /home/pi/homeassistant/configuration.yaml~  │   │
│ │  2. Create bind mount from custom to original                       │   │
│ │  3. Add entry to default profile                                    │   │
│ │  ⚠️  May affect: homeassistant (service)                             │   │
│ └─────────────────────────────────────────────────────────────────────┘   │
│                                                                            │
│              [Esc] Cancel          [Enter] Apply Detour                    │
└────────────────────────────────────────────────────────────────────────────┘
```

### 3. Logs → Live View
```
┌─ Detour Logs ─────────────────┬─ Filters ──────┬─ Quick Stats ─────────┐
│ 2024-10-28 15:42:18 [INFO]    │ [x] Info       │ Last hour:            │
│   Applied: nginx.conf         │ [x] Success    │   12 operations       │
│                               │ [x] Warning    │    8 successful       │
│ 2024-10-28 15:42:19 [SUCCESS] │ [ ] Error      │    3 warnings         │
│   nginx restarted             │                │    1 error            │
│                               │ [x] Detours    │                       │
│ 2024-10-28 15:43:05 [INFO]    │ [ ] Includes   │ Total detours: 3      │
│   Change detected: settings   │ [x] Services   │ Active: 3             │
│                               │                │ Inactive: 0           │
│ 2024-10-28 15:43:06 [WARN]    │ Search:        │                       │
│   Service restart needed      │ nginx▊         │                       │
│                               │                │                       │
│ 2024-10-28 15:45:12 [ERROR]   │                │                       │
│   Target not found: printer   │                │                       │
│                               │                │                       │
└───────────────────────────────┴────────────────┴───────────────────────┘
```

### 4. Status → Overview
```
┌─ System Status ───────┬─ Detours ─────────┬─ Health ──────────────────┐
│ Overall: ✓ Healthy    │ Active: 3         │ ✓ All detours mounted     │
│ Last check: 1m ago    │ Inactive: 1       │ ✓ No permission issues    │
│                       │ Errors: 1         │ ⚠️  2 services need restart│
│ Profile: default      │ Total: 4          │ ✓ All files synced        │
│ Uptime: 5d 3h         │                   │                           │
│                       │ Recent:           │ Disk Impact:              │
│ ┌─ Quick Actions ───┐│ • nginx.conf (2h) │   Originals:  45.2 MB     │
│ │ [R] Reload Config ││ • settings (5m)   │   Custom:     52.3 MB     │
│ │ [V] Validate All  ││ • printer (err)   │   Backups:    45.2 MB     │
│ │ [S] Restart Svcs  ││                   │   Impact:     +7.1 MB     │
│ └───────────────────┘│                   │                           │
└───────────────────────┴───────────────────┴───────────────────────────┘
```

### 5. Config → Edit
```
┌─ Detour Configuration (~/.detour.conf) ────────────────────────────────────┐
│   1 │ # Detour Configuration                                               │
│   2 │                                                                       │
│   3 │ # nginx detour                                                        │
│   4 │ detour /etc/nginx/nginx.conf = /home/pi/_playground/nginx/nginx.conf │
│   5 │                                                                       │
│   6 │ # Home Assistant detours                                             │
│   7 │ detour /home/pi/homeassistant/.vscode/settings.json = \              │
│   8 │        /home/pi/_playground/homeassistant/.vscode/settings.json      │
│   9 │                                                                       │
│  10 │ detour /home/pi/homeassistant/configuration.yaml = \                 │
│  11 │        /home/pi/_playground/homeassistant/configuration.yaml         │
│  12 │                                                                       │
│  13 │ # Klipper detour (inactive)                                          │
│  14 │ # detour /home/pi/klipper/printer.cfg = ..._playground/klipper/...  │
│  15 │                                                                       │
│                                                                            │
│ [Ctrl+S] Save  [Ctrl+V] Validate  [Esc] Cancel  [?] Syntax Help          │
└────────────────────────────────────────────────────────────────────────────┘
```

## Minimal Terminal Size

```
┌─ Detour ──────────────────────────────────────────────────────────────────┐
│ Terminal too small! Minimum: 120x20  Current: 80x15                       │
│ Press 'q' to quit                                                          │
└────────────────────────────────────────────────────────────────────────────┘
```

## Color Scheme (Same as chamon)

- **Background**: `#0A0A0A` (very dark)
- **Borders Active**: `White` (bright)
- **Borders Inactive**: `#333333` (dark grey)
- **Selection**: `#2A2A2A` bg + `White` fg + `BOLD`
- **Text Active**: `#FFFFFF` (white)
- **Text Inactive**: `#777777` (grey)
- **Success**: `#00AA00` (green)
- **Warning**: `#FFAA00` (yellow)
- **Error**: `#FF0000` (red)
- **Info**: `#00AAAA` (cyan)

## Navigation

### Column Focus
- `Tab` / `Shift+Tab` - Move between columns
- `h` / `l` (vim) or `←` / `→` - Move between columns

### Within Column
- `↑` / `↓` or `j` / `k` (vim) - Navigate items
- `Enter` - Select/Execute
- `Space` - Toggle (for checkboxes)

### Global
- `?` / `F1` - Help overlay
- `q` / `Q` / `Ctrl+C` - Quit
- `/` - Search
- `Esc` - Cancel/Back

### Quick Actions (Any Screen)
- `a` - Add detour
- `r` - Reload config
- `v` - Validate all
- `s` - Status overview

## Special Features

### 1. Smart Width Allocation
- **Column 1**: Auto-size to widest view name + 2 padding
- **Column 2**: Auto-size to widest action name + 4 padding
- **Column 3**: Remaining space (minimum 60 chars)

### 2. Responsive Borders
- Active column: `Thick` border + `White`
- Inactive columns: `Plain` border + `#333333`
- No column: `#222222` (very dim)

### 3. Contextual Help Line
Bottom shows context-sensitive help:
```
In Detours → List:
  [↑↓] Navigate  [Enter] Details  [Space] Toggle  [A]dd  [E]dit  [D]elete

In Add Dialog:
  [Tab] Next field  [Ctrl+F] Browse  [Enter] Confirm  [Esc] Cancel
```

### 4. Progress Indicators
For long operations (like applying many detours):
```
┌─ Applying Detours ─────────────────────────────────────────────────────────┐
│ ⣾  Processing... (2/5)                                                     │
│                                                                            │
│ ✓ nginx.conf                           [████████░░░░░░] 40%               │
│ ✓ settings.json                                                            │
│ ⣾  configuration.yaml (validating...)                                      │
│ ⋯  printer.cfg (pending)                                                   │
│ ⋯  macros.cfg (pending)                                                    │
└────────────────────────────────────────────────────────────────────────────┘
```

## Layout Comparison

### Chamon Style (Horizontal)
```
┌─────┬──────┬─────────────────────────────────────┐
│Views│Action│  Wide Content Area                  │
│     │      │                                     │
│     │      │                                     │
└─────┴──────┴─────────────────────────────────────┘
```

### Old Detour Idea (Vertical)
```
┌──────────────────────────────────────────────────┐
│ Title                                            │
├──────────────────────────────────────────────────┤
│ Tall                                             │
│ Content                                          │
│ Area                                             │
│                                                  │
├──────────────────────────────────────────────────┤
│ Status                                           │
└──────────────────────────────────────────────────┘
```

## Example: Full 180x25 Terminal

```
┌─ Detour ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Profile: default  |  3 active  |  Status: ✓ All synced  |  Disk: +7.1 MB                                                                                             │
├──────────┬──────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Detours  │ List                 │ ┌─ Active Detours (3) ───────────────────────────────────────────────────────────────────────────────────────────────────────────┐│
│ Includes │ Add                  │ │ /etc/nginx/nginx.conf → /home/pi/_playground/nginx/nginx.conf                                                                ││
│ Services │ Edit                 │ │   📝 Modified: 2h ago  |  📏 Size: 12.5 KB  |  ⚠️  Service restart needed  |  👤 pi:pi  |  🔒 rw-r--r--                      ││
│ Status   │ Toggle           ◄   │ │                                                                                                                               ││
│ Logs     │ Validate             │ │ /home/pi/homeassistant/.vscode/settings.json → /home/pi/_playground/homeassistant/.vscode/settings.json                     ││
│ Config   │ Remove               │ │   📝 Modified: 5m ago  |  📏 Size: 3.2 KB  |  ✓ Active and synced  |  👤 pi:pi  |  🔒 rw-rw-r--                                ││
│          │ Backup               │ │                                                                                                                               ││
│          │ Restore              │ │ /home/pi/klipper/printer.cfg → /home/pi/_playground/klipper/printer.cfg                                                      ││
│          │                      │ │   ❌ Target file missing!  |  💡 Create file or fix path  |  Last seen: 3d ago                                                 ││
│          │                      │ └───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘│
│          │                      │                                                                                                                                     │
├──────────┴──────────────────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ [Tab] Next  [↑↓/jk] Navigate  [Enter] Details  [Space] Toggle  [a] Add  [e] Edit  [d] Delete  [v] Validate  [?] Help  [q] Quit                                      │
│ ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────── │
│ Active detours are mounted and redirecting file reads. Toggle to temporarily disable without removing.                                                                │
└────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

**Key Takeaway:** Wide + shallow = 3 horizontal columns, maximizing content area width while keeping navigation compact on the left.



