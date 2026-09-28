#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Wallust: derive colors from the current wallpaper and update templates
# Usage: WallustSwww.sh [absolute_path_to_wallpaper]

set -euo pipefail

# Inputs and paths
passed_path="${1:-}"
cache_dir="$HOME/.cache/swww/"
rofi_link="$HOME/.config/rofi/.current_wallpaper"
wallpaper_current="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"

# Helper: get focused monitor name (prefer JSON)
get_focused_monitor() {
  if command -v jq >/dev/null 2>&1; then
    hyprctl monitors -j | jq -r '.[] | select(.focused) | .name'
  else
    hyprctl monitors | awk '/^Monitor/{name=$2} /focused: yes/{print name}'
  fi
}

# Determine wallpaper_path
wallpaper_path=""
if [[ -n "$passed_path" && -f "$passed_path" ]]; then
  wallpaper_path="$passed_path"
else
  # Try to read from swww cache for the focused monitor, with a short retry loop
  current_monitor="$(get_focused_monitor)"
  cache_file="$cache_dir$current_monitor"

  # Wait briefly for swww to write its cache after an image change
  for i in {1..10}; do
    if [[ -f "$cache_file" ]]; then
      break
    fi
    sleep 0.1
  done

  if [[ -f "$cache_file" ]]; then
    wallpaper_path=$(swww query 2>/dev/null | grep "$current_monitor" | sed -E 's/.*image: //' || true)
    if [[ -z "${wallpaper_path:-}" || ! -f "$wallpaper_path" ]]; then
      wallpaper_path=$(swww query 2>/dev/null | head -n 1 | sed -E 's/.*image: //' || true)
    fi
  fi
fi

if [[ -z "${wallpaper_path:-}" || ! -f "$wallpaper_path" ]]; then
  # Nothing to do; avoid failing loudly so callers can continue
  exit 0
fi

# Update helpers that depend on the path
ln -sf "$wallpaper_path" "$rofi_link" || true
mkdir -p "$(dirname "$wallpaper_current")"
if [[ "$wallpaper_path" != "$wallpaper_current" ]]; then
  cp -f "$wallpaper_path" "$wallpaper_current" || true
fi

# Run wallust to regenerate color templates
# Optimization: For very large images, use a downscaled preview for sub-second color generation
if command -v magick >/dev/null 2>&1; then
    magick "$wallpaper_path" -resize 720x720\> /tmp/wallust_preview.jpg 2>/dev/null || true
    if [ -f /tmp/wallust_preview.jpg ]; then
        wallust run -s /tmp/wallust_preview.jpg || wallust run -s "$wallpaper_path" || true
    else
        wallust run -s "$wallpaper_path" || true
    fi
else
    wallust run -s "$wallpaper_path" || true
fi

# Sync with Caelestia Shell (Quickshell)
mkdir -p "$HOME/.local/state/caelestia/wallpaper"
echo "$wallpaper_path" > "$HOME/.local/state/caelestia/wallpaper/path.txt"
if command -v caelestia >/dev/null 2>&1; then
    caelestia shell wallpaper set "$wallpaper_path" 2>/dev/null || true
fi

# Refresh UI components
pkill -SIGUSR2 waybar 2>/dev/null || true   # Waybar colors
pkill -SIGUSR1 kitty  2>/dev/null || true   # Kitty colors

# Update SDDM login screen wallpaper in background
if [[ -f "$HOME/.config/hypr/scripts/sddm_wallpaper.sh" ]]; then
    (bash "$HOME/.config/hypr/scripts/sddm_wallpaper.sh" --normal "$wallpaper_path" >> /tmp/sddm_update.log 2>&1 &)
fi

# Compile and apply dynamic cursor theme if present
if [ -f "$HOME/.config/hypr/scripts/CompileCursor.sh" ]; then
    bash "$HOME/.config/hypr/scripts/CompileCursor.sh" &
fi
