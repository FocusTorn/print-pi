# Detour Documentation for AI Agents

## Purpose

This directory contains Detour-specific documentation for AI agents. For universal Rust TUI patterns that apply to all TUI applications, see `_dev/_docs/rust/`.

## Universal Patterns First

**Before reading Detour-specific docs, familiarize yourself with universal patterns:**
- **Universal TUI Documentation**: `_dev/_docs/rust/README.md`
- **Color Palette**: `_dev/_docs/rust/01-color-palette.md`
- **Styling Helpers**: `_dev/_docs/rust/02-styling-helpers.md`
- **Layout Patterns**: `_dev/_docs/rust/03-layout-patterns.md`
- **Component Patterns**: `_dev/_docs/rust/04-component-patterns.md`
- **Event Handling**: `_dev/_docs/rust/05-event-handling.md`
- **State Management**: `_dev/_docs/rust/06-state-management.md`

These universal patterns serve as the foundation. Detour-specific documentation extends these patterns.

## Documentation Structure

### 01-structure-guide.md
**Detour-specific package structure and architecture.**

- Detour package directory layout
- Detour-specific modules and responsibilities
- Detour-specific view modes and actions
- Detour-specific operations (apply, remove, toggle)
- Detour-specific forms and components
- Integration with shell script backend

**Use this when**: Understanding Detour's structure, extending Detour functionality, or creating Detour-specific features.

### 02-style-guide.md
**Detour-specific styling details and extensions.**

- Detour status icons and colors
- Detour list item formatting
- Detour form styling
- Status overview styling
- Logs live view styling
- Config edit view styling

**Use this when**: Implementing Detour-specific UI components or styling Detour views.

### 03-implementation-patterns.md
**Detour-specific implementation patterns and code examples.**

- Detour-specific state management
- Detour-specific event handling
- Detour operations (apply, remove, toggle, validate)
- Detour-specific UI rendering
- Detour-specific error handling
- Detour config management

**Use this when**: Writing Detour-specific code, extending Detour features, or understanding Detour implementation.

### 04-formatting-reference.md
**Quick reference for Detour-specific formatting.**

- Detour status icons
- Detour list item format
- Detour view modes
- Detour-specific key bindings
- Detour-specific color usage

**Use this when**: Need quick reference for Detour-specific formatting details.

## Quick Start for AI Agents

### Understanding Detour

1. **Read Universal Patterns**: Start with `_dev/_docs/rust/README.md`
2. **Study Detour Structure**: Read `01-structure-guide.md`
3. **Review Detour Styling**: Read `02-style-guide.md`
4. **Examine Implementation**: Read `03-implementation-patterns.md`

### Extending Detour

1. **Understand Universal Patterns**: Review `_dev/_docs/rust/` documentation
2. **Study Detour Structure**: Review `01-structure-guide.md`
3. **Follow Detour Patterns**: Use `03-implementation-patterns.md` as reference
4. **Maintain Consistency**: Use universal styling helpers and patterns

### Creating Similar Applications

1. **Start with Universal Patterns**: Use `_dev/_docs/rust/` as foundation
2. **Reference Detour Implementation**: Use Detour as reference for domain-specific extensions
3. **Follow Universal Principles**: Maintain consistency with universal patterns
4. **Document Extensions**: Document package-specific extensions clearly

## Document Relationships

```
Universal Patterns (_dev/_docs/rust/)
    ↓ (Foundation)
Detour-Specific Docs (detour/docs/)
    ↓ (Implementation)
Detour Source Code (detour/src/)
```

## Key Concepts

### Universal Foundation

All Detour implementation is built on universal patterns:
- Universal color palette and styling helpers
- Universal three-column layout
- Universal component patterns (list_panel, form_panel)
- Universal event handling patterns
- Universal state management patterns

### Detour Extensions

Detour extends universal patterns with:
- Detour-specific view modes (Detours, Injections, Mirrors, Services)
- Detour-specific operations (apply, remove, toggle detours)
- Detour-specific forms (add/edit detour, injection, mirror)
- Detour-specific components (diff viewer, validation report)
- Shell script integration for file operations

### Separation of Concerns

- **Universal Patterns** (`_dev/_docs/rust/`): Package-agnostic, reusable across all TUIs
- **Detour-Specific** (`detour/docs/`): Detour domain-specific implementation details
- **Source Code** (`detour/src/`): Actual implementation following both universal and Detour patterns

## Best Practices

1. **Use Universal Patterns First**: Always start with universal patterns from `_dev/_docs/rust/`
2. **Extend, Don't Replace**: Extend universal patterns for Detour-specific needs
3. **Maintain Consistency**: Keep visual and behavioral consistency with universal patterns
4. **Document Extensions**: Document Detour-specific extensions clearly
5. **Reference Examples**: Reference Detour implementation for concrete examples

## Reference

- **Universal Patterns**: See `_dev/_docs/rust/` for universal TUI patterns
- **User Documentation**: See `../README.md` for user-facing documentation
- **Architecture**: See `../ARCHITECTURE.md` for technical architecture
- **Config Structure**: See `../CONFIG-STRUCTURE.md` for config format
- **Migration**: See `MIGRATION.md` for migration guide

## Version Information

- **Documentation Version**: 2.0
- **Last Updated**: 2025-11-07
- **Based on**: Detour TUI implementation + Universal patterns
- **Target Audience**: AI Agents and developers working with Detour

## Notes for AI Agents

- Universal patterns are in `_dev/_docs/rust/` - use these as the foundation
- Detour-specific docs extend universal patterns, don't replace them
- Always reference universal patterns first, then Detour-specific extensions
- Code examples follow both universal and Detour patterns
- Implementation should maintain consistency with universal patterns
