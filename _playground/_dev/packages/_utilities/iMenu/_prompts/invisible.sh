#!/usr/bin/env bash
# iMenu Prompt: invisible
# Invisible input prompt (like sudo)
# This file is a library and must be sourced, not executed directly

# Prevent direct execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "Error: This script is a library and must be sourced, not executed directly." >&2
    echo "Usage: source '$(basename "$0")' or use via iMenu.sh" >&2
    exit 1
fi

_prompt_invisible() {
    # Delegate to text prompt with invisible style
    _prompt_text "$1" "$2" "${3:-}" "invisible" "${4:-}" "${5:-}"
}

