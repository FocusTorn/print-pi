#!/usr/bin/env bash
# iMenu Prompt: invisible
# Invisible input prompt (like sudo)

imenu_invisible() {
    # Delegate to text prompt with invisible style
    imenu_text "$1" "$2" "${3:-}" "invisible" "${4:-}" "${5:-}"
}

