#!/usr/bin/env bash

entries=" Lock\n Suspend\n󰍃 Logout\n󰑐 Reboot\n Shutdown"
selected=$(printf '%b\n' "$entries" | wofi --dmenu --prompt="Power Menu" --cache-file=/dev/null)

case "$selected" in
    " Lock") hyprlock ;;
    " Suspend") systemctl suspend ;;
    "󰍃 Logout") hyprctl dispatch exit ;;
    "󰑐 Reboot") systemctl reboot ;;
    " Shutdown") systemctl poweroff ;;
esac
