#!/usr/bin/env bash
# Helper script to import the utility
# Usage: source "$(dirname "$0")/../../../utilities/logger/import.sh"

# Get the directory where this script is located
_PACKAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SCRIPT="${_PACKAGE_DIR}/logger.sh"

if [ -f "$_SCRIPT" ]; then
    source "$_SCRIPT"
else
    echo "ERROR: Logger script not found at $_SCRIPT" >&2
    return 1 2>/dev/null || exit 1
fi

# Cleanup
unset _PACKAGE_DIR _SCRIPT
