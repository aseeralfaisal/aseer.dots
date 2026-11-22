#!/usr/bin/env bash
icon_dir="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/icons"
case "${1:-}" in
    cpu|disk|memory)
        kind=$1
        state_dir="${XDG_RUNTIME_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}/waybar-resource-activity"
        mkdir -p "$state_dir"
        previous=0 previous_idle=0 previous_usage=0 until=0
        if [[ -r "$state_dir/$kind" ]]; then
            read -r previous previous_idle previous_usage until < "$state_dir/$kind"
        fi
        for value in previous previous_idle previous_usage until; do
            [[ "${!value}" =~ ^[0-9]+$ ]] || printf -v "$value" 0
        done
        current=0 current_idle=0 usage=0 changed=0
        case "$kind" in
            cpu)
                read -r tag user nice system idle iowait irq softirq steal rest < /proc/stat
                current=$((user + nice + system + idle + iowait + irq + softirq + steal))
                current_idle=$((idle + iowait))
                delta=$((current - previous))
                if ((previous > 0 && delta > 0)); then
                    usage=$((100 * (delta - current_idle + previous_idle) / delta))
                    change=$((usage - previous_usage)); ((change < 0)) && change=$((-change))
                    ((usage >= 25 || change >= 5)) && changed=1
                fi
                ;;
            disk)
                while read -r major minor device reads merged read_sectors read_time writes write_merged write_sectors rest; do
                    [[ "$device" =~ ^(nvme[0-9]+n[0-9]+|sd[a-z]+|vd[a-z]+|mmcblk[0-9]+)$ ]] || continue
                    current=$((current + read_sectors + write_sectors))
                done < /proc/diskstats
                ((previous > 0 && current > previous)) && changed=1
                ;;
            memory)
                total=0 available=0
                while read -r key amount unit; do
                    case "$key" in MemTotal:) total=$amount ;; MemAvailable:) available=$amount ;; esac
                done < /proc/meminfo
                current=$((total - available))
                change=$((current - previous)); ((change < 0)) && change=$((-change))
                ((previous > 0 && change >= 16384)) && changed=1
                ((total > 0 && current * 100 / total >= 80)) && changed=1
                ;;
        esac
        ((changed)) && until=$((EPOCHSECONDS + 4))
        printf '%s %s %s %s\n' "$current" "$current_idle" "$usage" "$until" > "$state_dir/$kind"
        if ((EPOCHSECONDS < until)); then
            printf '[{"path":"%s/transparent@2x.png","marker":"%s-active"}]\n' "$icon_dir" "$kind"
        else
            printf '[{"path":"%s/%s@2x.png","marker":"idle"}]\n' "$icon_dir" "$kind"
        fi
        exit 0
        ;;
    network|bluetooth)
        kind=$1
        active=false
        if [[ "$kind" == network ]]; then
            for radio in /sys/class/net/*/wireless; do
                [[ -d "$radio" ]] || continue
                read -r carrier < "${radio%/wireless}/carrier" 2>/dev/null || carrier=0
                [[ "$carrier" == 1 ]] && active=true
            done
            icon_name=wifi
        else
            status=$(timeout 2 bluetoothctl show 2>/dev/null) || status=''
            [[ "$status" == *'Powered: yes'* ]] && active=true
            icon_name=bluetooth
        fi
        if [[ "$active" == true ]]; then
            printf '[{"path":"%s/transparent@2x.png","marker":"%s-active"}]\n' "$icon_dir" "$kind"
        else
            printf '[{"path":"%s/%s@2x.png","marker":"idle"}]\n' "$icon_dir" "$icon_name"
        fi
        exit 0
        ;;
    weather)
        icon_name=weather-cloud
        cache="${XDG_CACHE_HOME:-$HOME/.cache}/waybar/weather-icon"
        [[ -r "$cache" ]] && read -r icon_name < "$cache"
        [[ "$icon_name" == weather-* && -f "$icon_dir/$icon_name.svg" ]] || icon_name=weather-cloud
        printf '[{"path":"%s/transparent@2x.png","marker":"%s"}]\n' "$icon_dir" "$icon_name"
        exit 0
        ;;
    download|upload)
        icon_name=$1
        state_dir="${XDG_RUNTIME_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}/waybar-transfers"
        timestamp=0 bytes=0
        if [[ -r "$state_dir/$1" ]]; then
            read -r timestamp bytes < "$state_dir/$1"
        fi
        if [[ "$timestamp" =~ ^[0-9]+$ && "$bytes" =~ ^[0-9]+$ ]] &&
           ((EPOCHSECONDS - timestamp <= 3 && bytes > 0)); then
            printf '\nTransferring data\n'
            exit 0
        fi
        ;;
    notification)
        count=$(timeout 2 swaync-client -sw -c 2>/dev/null) || count=0
        dnd=$(timeout 2 swaync-client -sw -D 2>/dev/null) || dnd=false
        if [[ "$count" =~ ^[0-9]+$ ]] && ((count > 0)) && [[ "$dnd" != true ]]; then
            printf '[{"path":"%s/transparent@2x.png","marker":"unread","tooltip":"%s notifications"}]\n' "$icon_dir" "$count"
        else
            printf '[{"path":"%s/bell@2x.png","marker":"idle","tooltip":"Notifications"}]\n' "$icon_dir"
        fi
        exit 0
        ;;
    battery)
        icon_name=battery-4
        for battery in /sys/class/power_supply/BAT*; do
            [[ -r "$battery/status" ]] || continue
            read -r status < "$battery/status"
            read -r capacity < "$battery/capacity"
            if [[ "$status" == Charging ]]; then
                # An empty image enables the GTK-rendered charging animation.
                printf '\nCharging\n'
                exit 0
            else
                level=$((capacity / 20))
                ((level > 4)) && level=4
                icon_name="battery-$level"
            fi
            break
        done
        ;;
    *) exit 1 ;;
esac
printf '%s/%s@2x.png\n' "$icon_dir" "$icon_name"
