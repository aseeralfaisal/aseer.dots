#!/usr/bin/env bash

workspaces=$(hyprctl workspaces -j | jq -r '.[].id' | sort -n)
current=$(hyprctl activeworkspace -j | jq -r '.id')

options=""
for workspace in $workspaces; do
    if [[ "$workspace" == "$current" ]]; then
        options+="󰮯 Workspace $workspace (current)\n"
    else
        options+="󰮮 Workspace $workspace\n"
    fi
done
options+="\n󰐕 New workspace\n"

chosen=$(printf '%b' "$options" | wofi --dmenu --prompt="Workspaces" --cache-file=/dev/null)

if [[ -n "$chosen" ]]; then
    if [[ "$chosen" == *"New workspace"* ]]; then
        hyprctl dispatch workspace +1
    elif [[ "$chosen" == *"Workspace"* ]]; then
        workspace=$(printf '%s\n' "$chosen" | grep -o '[0-9]\+')
        hyprctl dispatch workspace "$workspace"
    fi
fi
