#!/usr/bin/env bash

set -uo pipefail
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/wofi"
selected=$(printf '%s\n' \
    $'Lock\tLock your screen\tlock\tsystem-lock-screen-symbolic' \
    $'Suspend\tPut your computer to sleep\tsuspend\tweather-clear-night-symbolic' \
    $'Logout\tEnd your current session\tlogout\tsystem-log-out-symbolic' \
    $'Reboot\tRestart your computer\treboot\tsystem-reboot-symbolic' \
    $'Shutdown\tTurn off your computer\tshutdown\tsystem-shutdown-symbolic' \
    | "$config_dir/bin/wifi-panel" "$config_dir/wifi-panel.css" --power) || exit 0

case "$selected" in
    lock) hyprlock ;;
    suspend) systemctl suspend ;;
    logout) hyprctl dispatch exit ;;
    reboot) systemctl reboot ;;
    shutdown) systemctl poweroff ;;
esac
