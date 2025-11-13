# Universal Rust TUI Documentation

## Purpose

This directory contains universal, package-agnostic documentation for creating Rust TUI applications in the workspace. These principles serve as the foundation for all TUI projects, ensuring consistency across packages.

## Documentation Structure

### 01-color-palette.md
**Universal color system and palette.**

- Hex color helper function
- Core color definitions
- Semantic color usage
- Color application patterns

**Use this when**: Defining colors for any TUI application.

### 02-styling-helpers.md
**Universal styling helper functions and patterns.**

- Selection style helpers
- Accent color helpers
- Text color logic
- Border styling patterns
- Modal dimming patterns

**Use this when**: Implementing styling for UI components.

### 03-layout-patterns.md
**Universal layout patterns and structures.**

- Three-column layout pattern
- Area calculations
- Responsive layout handling
- Minimum size requirements
- Centered rectangle helper

**Use this when**: Designing layout structure for TUI applications.

### 04-component-patterns.md
**Universal reusable component patterns.**

- List panel component pattern
- Form panel component pattern
- Popup/dialog patterns
- Toast notification patterns
- File browser patterns
- Scrollbar implementation

**Use this when**: Creating reusable UI components.

### 05-event-handling.md
**Universal event handling patterns.**

- Event routing hierarchy
- Priority-based key handling
- Modal/overlay event handling
- Form input handling
- Navigation patterns

**Use this when**: Implementing event handling logic.

### 06-state-management.md
**Universal state management patterns.**

- Application state structure
- State initialization patterns
- Modal state management
- State update patterns
- Error handling in state
- Required App methods (get_current_actions, get_current_description)

**Use this when**: Designing application state architecture.

### 07-project-structure.md
**Universal project structure and module organization.**

- Required module structure
- Component module organization
- App structure requirements
- Required methods and fields
- Main function pattern
- Common mistakes to avoid

**Use this when**: Setting up a new TUI project from scratch.

### 08-ui-rendering-patterns.md
**Universal UI rendering patterns.**

- Main UI function naming (ui() not draw())
- Title bar rendering with rounded borders
- View column rendering with arrows
- Action column rendering with conditional arrows
- Content column rendering using list_panel
- Popup and toast rendering patterns

**Use this when**: Implementing UI rendering code.

## Quick Start for New TUI Projects

1. **Read**: `07-project-structure.md` - Set up project structure and modules
2. **Read**: `01-color-palette.md` - Understand the color system
3. **Review**: `02-styling-helpers.md` - Get styling helper functions
4. **Study**: `03-layout-patterns.md` - Understand layout structure
5. **Implement**: `04-component-patterns.md` - Create component modules
6. **Manage State**: `06-state-management.md` - Design state management with required methods
7. **Render UI**: `08-ui-rendering-patterns.md` - Implement UI rendering
8. **Handle Events**: `05-event-handling.md` - Implement event handling

## Design Principles

### Consistency
All TUI applications should follow these universal patterns to ensure:
- Consistent visual appearance
- Familiar user experience
- Predictable behavior
- Easier maintenance

### Reusability
Components and patterns are designed to be reusable across different TUI applications.

### Extensibility
Patterns can be extended for package-specific needs while maintaining core principles.

## Package-Specific Documentation

While this directory contains universal principles, each package may have:
- Package-specific implementation details
- Domain-specific patterns
- Extension points
- Custom components

See package-specific documentation (e.g., `detour/docs/`) for implementation details.

## Reference Implementation

The Detour package (`_dev/packages/detour/`) serves as the reference implementation of these universal patterns. See Detour's documentation for concrete examples.

## Version Information

- **Documentation Version**: 1.0
- **Last Updated**: 2025-11-07
- **Based on**: Detour TUI implementation
- **Target Audience**: AI Agents and developers creating new TUI applications

## Best Practices

1. **Follow Universal Patterns**: Use these patterns as the foundation
2. **Extend, Don't Replace**: Extend patterns for specific needs, don't replace them
3. **Maintain Consistency**: Keep visual and behavioral consistency with other TUIs
4. **Document Extensions**: Document package-specific extensions clearly
5. **Reference Examples**: Reference Detour implementation for concrete examples

## Notes for AI Agents

- These documents are package-agnostic and should be used as the foundation
- Patterns are based on proven implementations (Detour)
- Code examples are production-ready
- All patterns are designed for reuse across packages
- Package-specific documentation should reference these universal patterns

