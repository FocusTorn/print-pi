#!/usr/bin/env bash
set -euo pipefail

# cleanup-media.sh
# Removes empty directories under /media/pi when USB devices are unplugged
# Triggered by udev rule: /etc/udev/rules.d/99-media-cleanup.rules

# Remove empty directories under /media/pi safely
find /media/pi -mindepth 1 -type d -empty -print0 2>/dev/null | xargs -0r rmdir 2>/dev/null || true

