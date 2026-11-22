#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/wofi"

panel_rows() {
    local info devices connected paired tag address name state saved
    info=$(bluetoothctl show)
    if [[ "$info" != *Controller* ]]; then
        printf 'No Bluetooth adapter\tCheck that your adapter is connected\tnone\n'
        return
    fi
    if [[ "$info" != *'Powered: yes'* ]]; then
        printf 'Bluetooth is off\tClick to turn on\ttoggle\n'
        return
    fi
    devices=$(bluetoothctl devices)
    connected=$(bluetoothctl devices Connected)
    paired=$(bluetoothctl devices Paired)
    if [[ -z "$devices" ]]; then
        printf 'Searching for devices…\tPut your device in pairing mode\tnone\n'
        return
    fi
    while read -r tag address name; do
        [[ "$tag" == Device ]] || continue
        saved=''
        [[ "$paired" == *"Device $address "* ]] && saved='saved'
        state='Available · click to pair and connect'
        [[ "$paired" == *"Device $address "* ]] && state='Paired · click to connect'
        [[ "$connected" == *"Device $address "* ]] && state='Connected · click to disconnect'
        name=${name//$'\t'/ }
        printf '%s\t%s\t%s\t%s\n' "$name" "$state" "$address" "$saved"
    done <<< "$devices"
}
if [[ "${1:-}" == --panel-rows ]]; then panel_rows; exit; fi

scan_pid=''
stop_scan() {
    if [[ -n "$scan_pid" ]]; then
        kill "$scan_pid" 2>/dev/null || true
        wait "$scan_pid" 2>/dev/null || true
        scan_pid=''
    fi
}
trap stop_scan EXIT
start_scan() {
    stop_scan
    bluetoothctl --timeout 60 scan on >/dev/null 2>&1 &
    scan_pid=$!
}
error() { notify-send Bluetooth "$1"; }
start_scan
while true; do
    selection=$(panel_rows | "$config_dir/bin/wifi-panel" "$config_dir/wifi-panel.css" \
        "$config_dir/bluetooth-menu.sh" bluetooth Bluetooth) || exit 0
    case "$selection" in
        '') exit ;;
        none) continue ;;
        refresh) start_scan; continue ;;
        forget:*)
            address=${selection#forget:}
            [[ "$address" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] || continue
            result=$(bluetoothctl --timeout 15 remove "$address" 2>&1)
            if [[ "$(bluetoothctl devices Paired)" == *"Device $address "* ]]; then
                error "Could not forget device: $result"
            fi
            continue ;;
        toggle)
            if [[ "$(bluetoothctl show)" == *'Powered: yes'* ]]; then
                stop_scan
                result=$(bluetoothctl power off 2>&1)
            else
                result=$(bluetoothctl power on 2>&1)
                start_scan
            fi
            [[ "$result" == *Failed* ]] && error "$result"
            continue ;;
    esac
    [[ "$selection" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] || exit 0
    info=$(bluetoothctl info "$selection")
    if [[ "$info" == *'Connected: yes'* ]]; then
        result=$(bluetoothctl --timeout 20 disconnect "$selection" 2>&1)
        sleep 0.3
        info=$(bluetoothctl info "$selection")
        [[ "$info" != *'Connected: yes'* ]] || error 'Bluetooth disconnect failed.'
        exit
    fi
    if [[ "$info" != *'Paired: yes'* ]]; then
        "$config_dir/bin/bluetooth-pair" "$selection" "$config_dir/wifi-panel.css" || { error 'Pairing failed or was cancelled.'; exit 1; }
        info=$(bluetoothctl info "$selection")
        [[ "$info" == *'Paired: yes'* ]] || { error 'Bluetooth did not confirm pairing.'; exit 1; }
    fi
    result=$(bluetoothctl --timeout 25 connect "$selection" 2>&1)
    sleep 0.5
    info=$(bluetoothctl info "$selection")
    [[ "$info" == *'Connected: yes'* ]] || error 'Bluetooth connection failed.'
    exit
done
