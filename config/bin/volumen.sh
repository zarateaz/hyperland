#!/bin/bash

# Asegúrate de tener pamixer instalado
volume=$(pamixer --get-volume 2>/dev/null || echo 0)
mute=$(pamixer --get-mute 2>/dev/null || echo false)

if ! [[ "$volume" =~ ^[0-9]+$ ]]; then
    volume=0
fi

if [ "$mute" = "true" ]; then
    icon=""
else
    if [ "$volume" -eq 0 ]; then
        icon=""
    elif [ "$volume" -lt 50 ]; then
        icon=""
    else
        icon=""
    fi
fi

echo "$icon  $volume%"

