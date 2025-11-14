# Product Requirements Document: iMenu Refactoring

## Overview

Refactor iMenu from a monolithic prompt library into a modular, extensible architecture with clear separation of concerns. The new structure separates internal prompt implementations from public interfaces, enabling both single-use prompts (iPrompt) and multi-step wizards (iWizard) while maintaining a unified API.

## Goals

1. **Modular Architecture**: Separate concerns into distinct modules with clear boundaries
2. **Internal Library**: Prompts become internal library functions, not directly callable
3. **Public Interfaces**: iPrompt and iWizard are the only public interfaces
4. **Shared Resources**: Core utilities and prompts are shared across all modules
5. **Backward Compatibility**: Maintain API compatibility where possible during transition

## Architecture

### Directory Structure

```
iMenu/
├── iMenu.sh              # Main entry point - sources all modules
├── _shared/              # Shared core utilities (colors, terminal, utils, state)
├── _prompts/             # Internal prompt library (not directly callable)
├── iPrompt/              # Single-use prompt interface
└── iWizard/              # Multi-step wizard interface
```

### Module Relationships

```
iMenu.sh
├── Sources _shared/ (core utilities)
├── Sources _prompts/ (internal library)
├── Sources iPrompt/ (public interface for single prompts)
└── Sources iWizard/ (public interface for wizards)
```

## Components

### _shared/
**Purpose**: Core utilities shared by all modules

**Contents**:
- `colors.sh` - Color definitions and ANSI codes
- `terminal.sh` - Terminal I/O functions (read_char, read_escape, cursor control)
- `utils.sh` - Utility functions (function checks, property evaluation)
- `state.sh` - State management (if needed)
- `header.sh` - Header printing utilities (if needed)

**Access**: Internal - used by _prompts, iPrompt, and iWizard

### _prompts/
**Purpose**: Internal prompt library - implementation of all prompt types

**Contents**:
- `confirm.sh` - Yes/no confirmation prompt
- `text.sh` - Text input prompt
- `multiselect.sh` - Multi-selection menu
- `select.sh` - Single selection menu
- `number.sh` - Number input prompt
- `list.sh` - List input prompt
- `toggle.sh` - Toggle switch prompt
- `password.sh` - Password input prompt
- `invisible.sh` - Invisible input prompt
- `autocomplete.sh` - Autocomplete prompt
- `date.sh` - Date/time input prompt

**Function Naming**: All functions prefixed with `_prompt_` (e.g., `_prompt_confirm()`)

**Access Control**: 
- Functions are internal (prefixed with `_`)
- Cannot be called directly from user scripts
- Only accessible via iPrompt or iWizard interfaces

**Responsibilities**:
- Draw prompt UI starting from current cursor position
- Handle user input
- Return result value
- For text prompts: show cursor for character entry
- NO cursor positioning (caller handles this)
- NO clearing logic (caller handles this)
- NO wizard-specific logic

### iPrompt/
**Purpose**: Public interface for single-use prompts

**See**: `PRD_iPrompt.md` for detailed requirements

**Responsibilities**:
- Provide clean API for running single prompts
- Handle flag parsing (--initial, --preselect, --min, --max, etc.)
- Route to appropriate _prompts function
- Handle configuration presets
- Return result and exit code

### iWizard/
**Purpose**: Public interface for multi-step wizard flows

**See**: `PRD_iWizard.md` for detailed requirements

**Responsibilities**:
- Orchestrate multi-step wizard flows
- Manage wizard state and data
- Handle step transitions and navigation
- Display sent section (completed steps)
- Return JSON results

## API Design

### Main Entry Point: iMenu.sh

```bash
source "/path/to/iMenu/iMenu.sh"

# Single prompt via iPrompt
result=$(iprompt_run "confirm" "Do you agree?" "--initial" "true")

# Multi-step wizard via iWizard
results=$(iwizard_run_json "wizard_config.json")
```

### Module Loading Order

1. Load _shared/ core utilities
2. Load _prompts/ internal library
3. Load iPrompt/ module
4. Load iWizard/ module

## Migration Strategy

### Phase 1: Setup Structure
- Create new directory structure
- Copy core utilities to _shared/
- Copy prompts to _prompts/ and refactor

### Phase 2: Implement iWizard
- Create iWizard module (current focus)
- Implement data management
- Implement display functions
- Implement orchestrator

### Phase 3: Implement iPrompt
- Create iPrompt module
- Implement prompt dispatcher
- Create public API

### Phase 4: Integration
- Create main iMenu.sh entry point
- Test all modules together
- Update documentation

## Success Criteria

1. ✅ Prompts are internal and cannot be called directly
2. ✅ iPrompt provides clean API for single prompts
3. ✅ iWizard provides clean API for multi-step flows
4. ✅ All modules share core utilities from _shared/
5. ✅ Clear separation of concerns
6. ✅ Comprehensive test coverage
7. ✅ Documentation complete

## Non-Goals

- Backward compatibility with old iMenu API (during transition)
- Supporting direct prompt function calls
- Duplicating core utilities across modules

