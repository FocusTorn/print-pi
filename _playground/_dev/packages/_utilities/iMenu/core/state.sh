#!/usr/bin/env bash
# iMenu Core - State Management

_IMENU_RESPONSES=()
declare -A _IMENU_RESPONSES_MAP
_IMENU_CANCELED=false
declare -A _IMENU_OVERRIDE_VALUES
_IMENU_ONSUBMIT_FUNC=""
_IMENU_ONCANCEL_FUNC=""
_IMENU_INJECTED_VALUES=()
_IMENU_INJECTED_INDEX=0

# Terminal streams (use stderr for display like reference script)
_IMENU_STDIN="${IMENU_STDIN:-/dev/tty}"
_IMENU_STDOUT="${IMENU_STDOUT:-/dev/tty}"

