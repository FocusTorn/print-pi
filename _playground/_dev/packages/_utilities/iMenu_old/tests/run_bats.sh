#!/usr/bin/env bash
# Run iMenu tests with colorized output
# This script ensures colors are displayed even in non-interactive terminals
# Also colors checkmarks: ✔ (green, bold), ✗ (red), 🞉 (yellow for skipped)

# Set TERM to a color-capable terminal if it's set to 'dumb'
if [ "${TERM:-}" = "dumb" ] || [ -z "${TERM:-}" ]; then
    export TERM=xterm-256color
fi

# Force pretty formatter if not already set
FORMATTER="${BATS_FORMATTER:-pretty}"

# Run bats with the specified formatter and colorize checkmarks
# Use perl if available (better regex handling), otherwise sed
if command -v perl >/dev/null 2>&1; then
    bats --formatter "$FORMATTER" "$@" 2>&1 | perl -pe \
        's/(\x1b\[1G)\s*✓/\1 \x1b[32;1m✔\x1b[0m/g; \
         s/(\x1b\[1G)\s*✗/\1 \x1b[31m✗\x1b[0m/g; \
         s/(\x1b\[1G)\s*-/\1 \x1b[33m🞉\x1b[0m/g'
else
    # Fallback to sed (may not work as well with cursor codes)
    bats --formatter "$FORMATTER" "$@" 2>&1 | sed \
        -e 's/\(^[[:space:]]*\)✓/\1\x1b[32;1m✔\x1b[0m/g' \
        -e 's/\(^[[:space:]]*\)✗/\1\x1b[31m✗\x1b[0m/g' \
        -e 's/\(^[[:space:]]*\)-/\1\x1b[33m🞉\x1b[0m/g'
fi
