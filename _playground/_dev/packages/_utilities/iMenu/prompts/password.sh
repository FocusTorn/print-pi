#!/usr/bin/env bash
# iMenu Prompt: password
# Password prompt with masked input

imenu_password() {
    # Delegate to text prompt with password style
    imenu_text "$1" "$2" "${3:-}" "password" "${4:-}" "${5:-}"
}

