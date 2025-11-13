#!/usr/bin/env bash
# iMenu Prompt: password
# Password prompt with masked input
# This file is a library and must be sourced, not executed directly

# Prevent direct execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "Error: This script is a library and must be sourced, not executed directly." >&2
    echo "Usage: source '$(basename "$0")' or use via iMenu.sh" >&2
    exit 1
fi

imenu_password() {
    # Delegate to text prompt with password style
    imenu_text "$1" "$2" "${3:-}" "password" "${4:-}" "${5:-}"
}

