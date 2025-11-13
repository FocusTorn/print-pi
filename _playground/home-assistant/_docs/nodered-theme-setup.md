# Node-RED Theme Setup Guide

## Available Themes

You have **35 themes** available from `@node-red-contrib-themes`:

### Dark Themes (Popular)
- `dark` - Classic dark theme
- `monokai` - Monokai color scheme
- `tokyo-night` - Tokyo Night dark
- `tokyo-night-storm` - Tokyo Night storm variant
- `github-dark` - GitHub dark theme
- `github-dark-default` - GitHub dark default
- `github-dark-dimmed` - GitHub dark dimmed
- `dracula` - Dracula theme
- `midnight-red` - Midnight red theme
- `night-owl` - Night Owl theme
- `oceanic-next` - Oceanic Next theme
- `one-dark-pro` - One Dark Pro theme
- `oled` - OLED optimized theme
- `zenburn` - Zenburn theme

### Noctis Series
- `noctis` - Noctis base
- `noctis-sereno` - Noctis Sereno
- `noctis-bordo` - Noctis Bordo
- `noctis-uva` - Noctis Uva
- `noctis-viola` - Noctis Viola
- `noctis-minimus` - Noctis Minimus
- `noctis-obscuro` - Noctis Obscuro
- `noctis-azureus` - Noctis Azureus

### Light Themes
- `tokyo-night-light` - Tokyo Night light
- `selenized-light` - Selenized light
- `solarized-light` - Solarized light

### Other Themes
- `aurora` - Aurora theme
- `cobalt2` - Cobalt 2 theme
- `espresso-libre` - Espresso Libre theme
- `monoindustrial` - Mono Industrial theme
- `monokai-dimmed` - Monokai dimmed
- `one-dark-pro-darker` - One Dark Pro darker
- `railscasts-extended` - Railscasts Extended
- `selenized-dark` - Selenized dark
- `solarized-dark` - Solarized dark
- `totallyinformation` - Totally Information theme
- `zendesk-garden` - Zendesk Garden theme

## How to Enable a Theme

### Step 1: Edit settings.js

Open `/home/pi/nodered/settings.js` and find the `editorTheme` section (around line 417):

```javascript
editorTheme: {
    /** The following property can be used to set a custom theme for the editor.
     * See https://github.com/node-red-contrib-themes/theme-collection for
     * a collection of themes to chose from.
     */
    //theme: "",
```

### Step 2: Uncomment and Set Theme Name

Change this line:
```javascript
//theme: "",
```

To (for example, using "dark" theme):
```javascript
theme: "dark",
```

Or for other themes:
```javascript
theme: "monokai",
theme: "tokyo-night",
theme: "github-dark",
theme: "dracula",
// etc.
```

### Step 3: Save the File

Save the `settings.js` file after making the change.

### Step 4: Restart Node-RED

Restart the Node-RED container to apply the theme:

```bash
docker restart nodered
```

### Step 5: Refresh Browser

Refresh your Node-RED editor in the browser (or clear cache if needed).

## Quick Setup Example

**Enable "dark" theme:**

1. Edit `/home/pi/nodered/settings.js`
2. Find line with `//theme: "",`
3. Change to: `theme: "dark",`
4. Save file
5. Run: `docker restart nodered`
6. Refresh browser

## Recommended Themes

### For Dark Mode Lovers:
- **`dark`** - Classic, clean dark theme
- **`tokyo-night`** - Modern, beautiful dark theme
- **`github-dark`** - Familiar GitHub-style dark
- **`monokai`** - Popular Monokai color scheme
- **`dracula`** - Popular Dracula theme

### For Light Mode:
- **`tokyo-night-light`** - Clean light theme
- **`selenized-light`** - Easy on the eyes
- **`solarized-light`** - Popular Solarized light

### For OLED Screens:
- **`oled`** - Optimized for OLED displays (true black)

## Troubleshooting

### Theme Not Applying

1. **Check theme name:**
   - Make sure theme name matches exactly (case-sensitive)
   - Check available themes list above

2. **Check syntax:**
   - Make sure there's a comma after the theme name
   - Make sure the line is not commented out (no `//` at start)

3. **Restart Node-RED:**
   - Must restart after changing settings.js
   - Use: `docker restart nodered`

4. **Clear browser cache:**
   - Hard refresh: `Ctrl+Shift+R` (or `Cmd+Shift+R` on Mac)
   - Or clear browser cache

5. **Check Node-RED logs:**
   ```bash
   docker logs nodered | grep -i theme
   ```

### Theme Package Not Found

If you get an error about theme not found:

1. **Check theme package is installed:**
   ```bash
   docker exec nodered npm list @node-red-contrib-themes
   ```

2. **Reinstall theme package:**
   ```bash
   docker exec nodered npm install @node-red-contrib-themes
   ```

3. **Restart Node-RED:**
   ```bash
   docker restart nodered
   ```

## Changing Themes

To change to a different theme:

1. Edit `settings.js`
2. Change the theme name
3. Save file
4. Restart Node-RED: `docker restart nodered`
5. Refresh browser

## Advanced Configuration

### Multiple Themes (Not Supported)

Node-RED only supports one theme at a time. You cannot have multiple themes active simultaneously.

### Custom Theme Colors

Themes are pre-configured. To customize colors, you would need to:
1. Create a custom theme
2. Or modify the theme CSS files (not recommended)

## File Location

- **Settings file:** `/home/pi/nodered/settings.js`
- **Theme package:** `/home/pi/nodered/node_modules/@node-red-contrib-themes/`
- **Theme files:** `/home/pi/nodered/node_modules/@node-red-contrib-themes/theme-collection/themes/`

## Quick Reference

**Enable theme:**
```javascript
editorTheme: {
    theme: "dark",  // or any theme name from the list
}
```

**Restart Node-RED:**
```bash
docker restart nodered
```

**Check available themes:**
```bash
docker exec nodered ls /data/node_modules/@node-red-contrib-themes/theme-collection/themes/
```

---

**Popular Themes to Try:**
- `dark` - Classic dark
- `tokyo-night` - Modern dark
- `github-dark` - GitHub style
- `monokai` - Monokai colors
- `dracula` - Dracula theme
- `oled` - OLED optimized

