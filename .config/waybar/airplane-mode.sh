#!/usr/bin/env bash

set -u

state_file="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-airplane-state"
action="${1:-status}"

wifi_state() {
  nmcli -t -f WIFI radio 2>/dev/null || printf 'disabled\n'
}

wwan_state() {
  nmcli -t -f WWAN radio 2>/dev/null || printf 'disabled\n'
}

bluetooth_state() {
  if bluetoothctl show 2>/dev/null | grep -q $'\tPowered: yes'; then
    printf 'enabled\n'
  else
    printf 'disabled\n'
  fi
}

is_airplane_on() {
  [[ "$(wifi_state)" == "disabled" && "$(bluetooth_state)" == "disabled" ]]
}

show_status() {
  if is_airplane_on; then
    printf '{"text":"","alt":"on","tooltip":"Airplane mode enabled · click to restore radios","class":"on"}\n'
  else
    printf '{"text":"","alt":"off","tooltip":"Airplane mode disabled · click to disable Wi-Fi and Bluetooth","class":"off"}\n'
  fi
}

toggle() {
  if is_airplane_on; then
    previous_wifi="enabled"
    previous_wwan="enabled"
    previous_bluetooth="enabled"

    if [[ -r "$state_file" ]]; then
      previous_wifi="$(sed -n 's/^wifi=//p' "$state_file")"
      previous_wwan="$(sed -n 's/^wwan=//p' "$state_file")"
      previous_bluetooth="$(sed -n 's/^bluetooth=//p' "$state_file")"
    fi

    [[ "$previous_wifi" == "enabled" ]] && nmcli radio wifi on >/dev/null 2>&1
    [[ "$previous_wwan" == "enabled" ]] && nmcli radio wwan on >/dev/null 2>&1
    [[ "$previous_bluetooth" == "enabled" ]] && bluetoothctl power on >/dev/null 2>&1
    rm -f "$state_file"
  else
    mkdir -p "$(dirname "$state_file")"
    printf 'wifi=%s\nwwan=%s\nbluetooth=%s\n' \
      "$(wifi_state)" "$(wwan_state)" "$(bluetooth_state)" > "$state_file"
    nmcli radio wifi off >/dev/null 2>&1
    nmcli radio wwan off >/dev/null 2>&1
    bluetoothctl power off >/dev/null 2>&1
  fi

  show_status

}

case "$action" in
  toggle) toggle ;;
  status) show_status ;;
  icon)
    icon_dir="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/icons"
    if is_airplane_on; then
      printf '%s/airplane-on@2x.png\nAirplane mode enabled · click to restore radios\n' "$icon_dir"
    else
      printf '%s/airplane-off@2x.png\nAirplane mode disabled · click to disable Wi-Fi and Bluetooth\n' "$icon_dir"
    fi
    ;;
  *) printf 'Usage: %s [status|toggle|icon]\n' "$0" >&2; exit 2 ;;
esac
