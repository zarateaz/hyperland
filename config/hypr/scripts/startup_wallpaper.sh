#!/bin/bash
# startup_wallpaper.sh - Ensures swww starts correctly without black screens

SCRIPTS_DIR="$HOME/.config/hypr/scripts"
WALL_CURRENT="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
PICS_DIR=$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")

# Find a dynamic default wallpaper from user Pictures or bundled wallpapers
DEFAULT_WALL=$(find "$PICS_DIR/wallpapers" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | head -n 1)
if [[ -z "$DEFAULT_WALL" || ! -f "$DEFAULT_WALL" ]]; then
    DEFAULT_WALL=$(find "$HOME/.config/quickshell/caelestia/wallpapers" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | head -n 1)
fi

# 1. Start swww-daemon if not running
if ! pgrep -x "swww-daemon" > /dev/null; then
    swww-daemon --format xrgb &
    # Wait for the socket to be available
    for i in {1..50}; do
        if swww query > /dev/null 2>&1; then
            break
        fi
        sleep 0.1
    done
fi

# 2. Determine which wallpaper to load
WALL=""
if [ -f "$WALL_CURRENT" ]; then
    WALL=$(cat "$WALL_CURRENT" 2>/dev/null || true)
fi

if [[ -z "$WALL" || ! -f "$WALL" ]]; then
    WALL="$DEFAULT_WALL"
fi

# 3. Apply the wallpaper
if [[ -n "$WALL" && -f "$WALL" ]]; then
    echo "Applying startup wallpaper: $WALL"
    swww img "$WALL" --transition-type none || true
    
    # 4. Trigger a full sync in the background to ensure colors and SDDM match
    if [ -f "$SCRIPTS_DIR/WallustSwww.sh" ]; then
        bash "$SCRIPTS_DIR/WallustSwww.sh" "$WALL" &
    fi
else
    echo "Notice: No wallpaper found to apply at startup."
fi
