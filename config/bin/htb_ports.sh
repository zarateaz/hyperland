#!/bin/bash

if [ -f ~/.config/bin/ports ]; then
    PORTS=$(cat ~/.config/bin/ports | tr ' ' '|')
    if [ -n "$PORTS" ]; then
        echo "Ψ $PORTS"
    else
        echo "Ψ No ports"
    fi
else
    echo "Ψ No ports"
fi

