#!/bin/bash
# sddm_trigger.sh - Manually trigger SDDM wallpaper update
# This script will check the dedicated sddm folder and apply it.

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
SDDM_WALL_SCRIPT="$SCRIPT_DIR/sddm_wallpaper.sh"

if [[ -f "$SDDM_WALL_SCRIPT" ]]; then
    echo "Triggering SDDM wallpaper update..."
    bash "$SDDM_WALL_SCRIPT"
    echo "Done. Check /tmp/sddm_sync.log for details."
else
    echo "Error: sddm_wallpaper.sh not found in $SCRIPT_DIR"
    exit 1
fi
