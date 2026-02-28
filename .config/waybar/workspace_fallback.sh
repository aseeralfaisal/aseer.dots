#!/bin/bash

# Fallback workspace manager using rofi
# In case Python GTK is not available

WORKSPACES=$(hyprctl workspaces -j | jq -r '.[].id' | sort -n)
CURRENT=$(hyprctl activeworkspace -j | jq -r '.id')

# Create rofi options
OPTIONS=""
for ws in $WORKSPACES; do
    if [ "$ws" = "$CURRENT" ]; then
        OPTIONS="$OPTIONS󰮯 Workspace $ws (current)\n"
    else
        OPTIONS="$OPTIONS󰮮 Workspace $ws\n"
    fi
done

OPTIONS="$OPTIONS\n󰐕 New workspace"

# Show rofi menu
CHOSEN=$(echo -e "$OPTIONS" | rofi -dmenu -i -p "󰮯 Workspaces" -config ~/.config/rofi/config.rasi)

if [[ -n "$CHOSEN" ]]; then
    if [[ "$CHOSEN" == *"New workspace"* ]]; then
        hyprctl dispatch workspace +1
    elif [[ "$CHOSEN" == *"Workspace"* ]]; then
        WS_NUM=$(echo "$CHOSEN" | grep -o '[0-9]\+')
        hyprctl dispatch workspace "$WS_NUM"
    fi
fi