# Home Assistant Cursor AI Rules

These rules guide Cursor's AI assistance for Home Assistant customizations.

**⚠️ Reference:** See `~/.cursor/rules/workspace-architecture.mdc` for workspace-wide detour/bootstrap principles.

## Rules Overview

1. **home-assistant-standards.mdc** - YAML formatting, configuration patterns, best practices
2. **system-integration.mdc** - Systemd services, bootstrap scripts, path conventions

## Key Principles

- **NEVER** edit files directly in `~/homeassistant/`
- **ALWAYS** edit files in `_playground/home-assistant/`
- **ALWAYS** use `detour apply` after making changes
- **ALWAYS** restart Home Assistant to load changes

These rules ensure all customizations persist across system rebuilds and updates.

