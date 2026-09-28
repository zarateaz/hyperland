#!/bin/bash
# Script for Random Wallpaper ( CTRL ALT W)

wallDIR="$HOME/Pictures/wallpapers"
SCRIPTSDIR="$HOME/.config/hypr/scripts"

focused_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')

mapfile -d '' PICS < <(find -L "${wallDIR}" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.pnm" -o -iname "*.tga" -o -iname "*.tiff" -o -iname "*.webp" -o -iname "*.bmp" -o -iname "*.farbfeld" -o -iname "*.gif" \) -print0)

if [ ${#PICS[@]} -eq 0 ]; then
    echo "No wallpapers found in ${wallDIR}"
    exit 0
fi

RANDOMPICS="${PICS[ $RANDOM % ${#PICS[@]} ]}"

# Transition config
FPS=30
TYPE="random"
DURATION=1
BEZIER=".43,1.19,1,.4"
SWWW_PARAMS="--transition-fps $FPS --transition-type $TYPE --transition-duration $DURATION --transition-bezier $BEZIER"

if ! swww query >/dev/null 2>&1; then
    swww-daemon --format xrgb &
    sleep 0.5
fi

swww img -o "$focused_monitor" "$RANDOMPICS" $SWWW_PARAMS

"$SCRIPTSDIR/WallustSwww.sh" "$RANDOMPICS"
sleep 2
"$SCRIPTSDIR/Refresh.sh"

