# Node-RED Wire/Connection Line Visibility

## Understanding Wire Visibility

In Node-RED, there are different types of connections:

1. **Regular Wires** - Always visible between nodes
2. **Link Node Connections** - Virtual connections, hidden by default
3. **Wires Behind Nodes** - May be hidden when nodes overlap

## Making Link Node Connections Visible

### Link Nodes (Virtual Connections)

Link nodes create virtual connections between different parts of your flow. These connections are **hidden by default** but can be made visible:

**Method 1: Select Link Node**
1. Click on any **Link In** or **Link Out** node
2. The editor will automatically show all connections to/from that Link node
3. If the connection goes to another tab, a virtual node appears showing the connection

**Method 2: View All Link Connections**
- Select any Link node to see its connections
- Connections to other tabs will show as virtual nodes
- Click the virtual node to navigate to the actual Link node

### Link Node Best Practices

1. **Use Descriptive Names:**
   - Name Link nodes clearly (e.g., "Link Out: trigger-backup")
   - Makes it easier to find connections

2. **Organize Link Nodes:**
   - Group Link In/Out nodes together
   - Use comments to document Link connections

3. **Check Connections:**
   - Select Link nodes to verify connections
   - Use virtual nodes to navigate between tabs

## Making Regular Wires More Visible

### Method 1: Improve Wire Contrast

Some themes make wires easier to see than others. Try:

- **Dark themes** - Wires are usually more visible on dark backgrounds
- **High contrast themes** - Better wire visibility
- **Current theme:** `github-dark-dimmed` should have good wire visibility

### Method 2: Wire Routing Settings

Node-RED automatically routes wires to avoid overlaps, but you can:

1. **Organize Nodes:**
   - Space nodes to reduce wire crossings
   - Align nodes to create cleaner wire paths
   - Use junctions for complex routing

2. **Use Junctions:**
   - Add Junction nodes for cleaner wire routing
   - Reduces wire crossings
   - Makes connections more visible

3. **Minimize Overlaps:**
   - Don't stack nodes directly on top of each other
   - Leave space between nodes
   - Wire paths will be clearer

### Method 3: Zoom and Pan

1. **Zoom In:**
   - Use mouse wheel or zoom controls
   - Makes wires easier to see
   - Better for detailed work

2. **Pan Around:**
   - Click and drag canvas to move around
   - Find hidden connections
   - See entire flow structure

### Method 4: Highlight Connections

**Select a Node:**
1. Click on any node
2. All wires connected to that node are highlighted
3. Makes it easy to see connections

**Select Multiple Nodes:**
1. Click and drag to select multiple nodes
2. All connections between selected nodes are visible
3. Helps understand flow structure

## Advanced: Custom CSS (Advanced Users)

If you want to customize wire appearance, you can add custom CSS:

**Note:** This requires modifying Node-RED installation files and may be overwritten on updates.

### Location:
- Node-RED installation directory
- Editor client CSS files
- Theme CSS files

### Custom CSS Options:
- Wire thickness
- Wire colors
- Wire opacity
- Wire routing style

**Warning:** Custom CSS modifications are not officially supported and may break with updates.

## Settings Configuration

### Check Current Settings

In `settings.js`, the `editorTheme` section controls editor appearance:

```javascript
editorTheme: {
    theme: "github-dark-dimmed",  // Theme affects wire visibility
    // Other editor settings
}
```

### Available Settings

Currently, Node-RED doesn't have a built-in setting to:
- Show all wires at once (except Link nodes when selected)
- Make wires always visible behind nodes
- Force wire routing style

**Workarounds:**
1. Use Link nodes and select them to see connections
2. Organize nodes to minimize overlaps
3. Use junctions for complex routing
4. Select nodes to highlight their connections
5. Zoom in for better visibility

## Best Practices for Wire Visibility

### 1. Organize Your Flow
- Space nodes appropriately
- Align nodes to reduce crossings
- Use groups to organize related nodes

### 2. Use Link Nodes Wisely
- Use Link nodes for cross-tab connections
- Name Link nodes descriptively
- Select Link nodes to see connections

### 3. Minimize Wire Crossings
- Organize nodes logically
- Use junctions for complex routing
- Keep related nodes close together

### 4. Use Visual Aids
- Add comments to document connections
- Use groups to organize sections
- Use colors to highlight important connections

### 5. Regular Maintenance
- Clean up unused connections
- Remove duplicate wires
- Organize nodes regularly

## Troubleshooting

### Wires Not Visible

1. **Check Zoom Level:**
   - Zoom in if wires are too small
   - Use mouse wheel to zoom

2. **Check Theme:**
   - Some themes have better wire contrast
   - Try different themes

3. **Check Node Overlaps:**
   - Move nodes apart
   - Wires may be hidden behind nodes

4. **Select Nodes:**
   - Click nodes to highlight connections
   - Makes wires more visible

### Link Node Connections Not Showing

1. **Select Link Node:**
   - Click on Link In/Out node
   - Connections should appear

2. **Check Link Node Names:**
   - Link In/Out nodes must have matching names
   - Check for typos in names

3. **Check Node Status:**
   - Ensure Link nodes are deployed
   - Check for errors in flow

### Wires Hard to See

1. **Try Different Theme:**
   - Dark themes often have better contrast
   - Try: `dark`, `tokyo-night`, `github-dark`

2. **Increase Zoom:**
   - Zoom in for better visibility
   - Use mouse wheel

3. **Organize Nodes:**
   - Space nodes to reduce crossings
   - Align nodes for cleaner paths

## Quick Reference

### See Link Node Connections:
- Click on Link In/Out node
- Connections will appear
- Virtual nodes show cross-tab connections

### Highlight Node Connections:
- Click on any node
- All connected wires are highlighted
- Makes connections visible

### Improve Wire Visibility:
- Use dark/high-contrast themes
- Organize nodes to reduce overlaps
- Use junctions for complex routing
- Zoom in for better visibility

### Check All Connections:
- Select nodes to highlight connections
- Use Link nodes and select them
- Organize flow to see connections clearly

---

## Practical Tips for Your Flow

### For Your Settings Group Flow:

1. **Select Nodes to See Connections:**
   - Click on any node in your Settings group
   - All wires connected to that node will be highlighted
   - Makes it easy to trace connections

2. **Use Junction Nodes:**
   - Add Junction nodes for complex branching (like your HMS file flow)
   - Makes wire routing cleaner
   - Reduces wire crossings

3. **Organize Node Placement:**
   - Space nodes to avoid overlaps
   - Align nodes in columns/rows
   - Wires will be more visible

4. **Zoom In for Complex Areas:**
   - Use mouse wheel to zoom into Settings group
   - Makes wires easier to see
   - Better for detailed work

5. **Select Multiple Nodes:**
   - Click and drag to select multiple nodes
   - See all connections between selected nodes
   - Helps understand flow structure

## Summary

**For Link Nodes:**
- Select Link node to see connections
- Virtual nodes show cross-tab connections
- Click virtual node to navigate

**For Regular Wires:**
- Select nodes to highlight connections
- Organize nodes to reduce overlaps
- Use junctions for complex routing
- Zoom in for better visibility
- Use high-contrast themes

**No Built-in "Show All Wires" Setting:**
- Node-RED doesn't have a setting to show all wires at once
- Use node selection to highlight connections
- Organize flow for better visibility

**Quick Answer:**
- **Click on any node** to see all its connections highlighted
- **Select Link nodes** to see their virtual connections
- **Zoom in** for better wire visibility
- **Organize nodes** to reduce wire crossings

