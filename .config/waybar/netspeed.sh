#!/bin/bash
INTERFACE="wlan0"
MODE="${1:-both}"

while true; do
    read -r RX1 TX1 < <(awk -v interface="$INTERFACE:" '$1 == interface {print $2, $10}' /proc/net/dev)
    sleep 1
    read -r RX2 TX2 < <(awk -v interface="$INTERFACE:" '$1 == interface {print $2, $10}' /proc/net/dev)

    DOWN=$(( (RX2 - RX1) / 1024 ))
    UP=$(( (TX2 - TX1) / 1024 ))

    case "$MODE" in
        download) echo "󰇚 $DOWN kB/s" ;;
        upload) echo "󰕒 $UP kB/s" ;;
        *) echo "󰇚 $DOWN kB/s 󰕒 $UP kB/s" ;;
    esac
done
