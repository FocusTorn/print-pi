# Detour Documentation for AI Agents

## Purpose

This directory contains comprehensive documentation for AI agents to understand, recreate, and extend the Detour TUI package. These documents are specifically written for AI agent consumption with clear patterns, examples, and implementation details.

## Documentation Structure

### 01-structure-guide.md
**Complete guide to Detour's package structure and architecture.**

- Package directory layout
- Module organization and responsibilities
- State management patterns
- Event handling architecture
- Component reusability guidelines
- Extension points for new features

**Use this when**: Creating similar TUI applications, understanding Detour's architecture, or extending functionality.

### 02-style-guide.md
**Complete guide to Detour's visual style and UI patterns.**

- Color palette and hex color helpers
- Border styling and types
- Layout structure and calculations
- Form input styling and cursor rendering
- Modal dimming patterns
- Popup styling and dimensions
- Toast notification patterns
- List rendering and scrollbars
- Status bar styling

**Use this when**: Implementing new UI components, recreating visual style, or ensuring consistency.

### 03-implementation-patterns.md
**Concrete implementation patterns and code examples.**

- State management code examples
- Event handling patterns
- Form handling patterns
- Component rendering patterns
- Popup creation and handling
- Toast notification implementation
- File operations patterns
- Error handling patterns
- Validation patterns

**Use this when**: Writing new code, extending features, or understanding implementation details.

### 04-formatting-reference.md
**Comprehensive visual design system reference.**

- Complete color palette with hex values
- Universal styling helpers
- Border styling specifications
- Text styling logic
- Column layout details
- Form input specifications
- Modal and popup styling
- List rendering specifications
- Scrollbar implementation
- Status and message styling
- Toast notification details
- Navigation patterns
- Keyboard shortcuts
- Minimum size requirements
- Best practices checklist

**Use this when**: Need detailed styling specifications, visual design details, or comprehensive reference.

## Quick Start for AI Agents

### Understanding Detour Structure

1. **Read**: `01-structure-guide.md` - Understand the overall architecture
2. **Review**: `src/lib.rs` - See module organization
3. **Study**: `src/app.rs` - Understand state management
4. **Examine**: `src/events.rs` - Learn event handling patterns

### Implementing New Features

1. **Plan**: Use `01-structure-guide.md` to identify extension points
2. **Style**: Reference `02-style-guide.md` for visual consistency
3. **Implement**: Use `03-implementation-patterns.md` for code patterns
4. **Verify**: Check `04-formatting-reference.md` for styling details

### Creating Similar Applications

1. **Structure**: Follow patterns in `01-structure-guide.md`
2. **Style**: Apply styling from `02-style-guide.md`
3. **Code**: Use patterns from `03-implementation-patterns.md`
4. **Polish**: Reference `04-formatting-reference.md` for details

## Document Relationships

```
01-structure-guide.md (Architecture)
    ↓
02-style-guide.md (Visual Design)
    ↓
03-implementation-patterns.md (Code Patterns)
    ↓
04-formatting-reference.md (Detailed Specs)
```

## Key Concepts

### Three-Column Layout
- **Column 1**: Views (narrow, dynamic width)
- **Column 2**: Actions (medium, dynamic width)
- **Column 3**: Content (wide, remaining space)

### State Management
- Single source of truth in `App` struct
- Event-driven state updates
- Modal/popup state centralization

### Component Reusability
- `list_panel` for all list rendering
- `form_panel` for all form rendering
- Custom components for domain-specific UI

### Modal Dimming
- No global overlay
- Conditional dimming per widget
- Check `app.is_modal_visible()` for all widgets

### Event Priority
1. Overlays (file browser, popups, reports)
2. Forms (when active)
3. Global navigation
4. View-specific handlers

## Best Practices

1. **Always check modal state**: Use `app.is_modal_visible()` before rendering
2. **Use helper functions**: Prefer `get_selection_style()`, `accent_color()`, etc.
3. **Clear before render**: Always clear modal/popup areas
4. **Handle empty states**: Always provide helpful empty state messages
5. **Validate before operations**: Check paths, permissions, etc.
6. **Provide user feedback**: Use toasts for non-critical, popups for critical
7. **Follow event priority**: Handle overlays before forms, forms before navigation
8. **Reuse components**: Use existing components when possible

## Reference Implementation

For complete reference, see:
- `src/ui.rs` - Main UI rendering
- `src/components/` - Reusable components
- `src/app.rs` - State management
- `src/events.rs` - Event handling
- `src/popup.rs` - Popup implementation
- `src/filebrowser.rs` - File browser implementation

## Additional Resources

- **User Documentation**: See `README.md` in root directory
- **Architecture Details**: See `ARCHITECTURE.md` in root directory
- **Config Structure**: See `CONFIG-STRUCTURE.md` in root directory
- **Migration Guide**: See `docs/MIGRATION.md` for migration from old version

## Version Information

- **Documentation Version**: 2.0
- **Last Updated**: 2025-11-07
- **Based on**: Detour TUI implementation
- **Target Audience**: AI Agents and developers

## Notes for AI Agents

- These documents are designed for AI agent consumption
- Patterns and examples are provided for direct implementation
- Code examples are production-ready and tested
- All styling follows the established design system
- Implementation patterns are based on actual Detour code
- References to source files are accurate and up-to-date

