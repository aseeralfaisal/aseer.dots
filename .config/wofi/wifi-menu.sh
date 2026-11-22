#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/wofi"
panel_rows() {
    local active signal security rest bssid ssid state saved name type profile profiles networks
    local -A saved_networks=()
    # One cached profile query, rather than a separate nmcli process per AP.
    profiles=$(nmcli -t -e no -f NAME,TYPE connection show) || return 1
    networks=$(nmcli -t -e no -f IN-USE,SIGNAL,SECURITY,SSID,BSSID device wifi list ifname "$1" --rescan no) || return 1
    while IFS= read -r profile; do
        type=${profile##*:}
        name=${profile%:*}
        [[ "$type" == 802-11-wireless ]] && saved_networks["$name"]=1
    done <<< "$profiles"
    while IFS=: read -r active signal security rest; do
        [[ ${#rest} -ge 18 ]] || continue
        bssid="${rest: -17}"
        ssid="${rest:0:${#rest}-18}"
        [[ -n "$ssid" ]] || continue
        state=''
        [[ "$active" == '*' ]] && state='Connected · '
        saved=''
        [[ -n "${saved_networks[$ssid]:-}" ]] && saved='saved'
        printf '%s\t%s%s%% · %s\t%s\t%s\n' "$ssid" "$state" "$signal" "${security:---}" "$bssid" "$saved"
    done <<< "$networks"
}
if [[ "${1:-}" == --panel-rows || "${1:-}" == --panel-refresh ]]; then
    if [[ "$1" == --panel-refresh ]]; then
        nmcli --wait 10 device wifi rescan ifname "$2" >/dev/null 2>&1 || exit 1
    fi
    panel_rows "$2"
    exit
fi

report() { notify-send 'Wi-Fi' "$1"; }
run_action() {
    local result
    if result=$(nmcli --wait 20 "$@" 2>&1); then
        : # Successful changes are reflected in Waybar without a popup.
    else
        report "$result"
    fi
}

if ! devices=$(nmcli -t -f DEVICE,TYPE device status 2>&1); then
    report "$devices"
    exit 1
fi
interface=''
while IFS=: read -r device type; do
    if [[ "$type" == wifi ]]; then interface=$device; break; fi
done <<< "$devices"
[[ -n "$interface" ]] || { report 'No Wi-Fi adapter found.'; exit 1; }
# Update NetworkManager's cache without delaying the first frame.
nmcli --wait 10 device wifi rescan ifname "$interface" >/dev/null 2>&1 &

while true; do
    enabled=$(nmcli -t -f WIFI general)
    toggle='Turn Wi-Fi on'
    [[ "$enabled" == enabled ]] && toggle='Turn Wi-Fi off'
    rows=()
    addresses=() names=() securities=() connected=()
    if [[ "$enabled" == enabled ]]; then
        mapfile -t rows < <(panel_rows "$interface")
    fi
    if [[ "$enabled" != enabled ]]; then
        selection=$(printf '%s\n' 'Wi-Fi is off — turn on' | "$config_dir/bin/wifi-panel" "$config_dir/wifi-panel.css") || exit 0
        [[ -n "$selection" ]] || exit 0
        run_action radio wifi on
        continue
    fi
    selection=$(printf '%s\n' "${rows[@]}" | "$config_dir/bin/wifi-panel" "$config_dir/wifi-panel.css" "$config_dir/wifi-menu.sh" "$interface") || exit 0
    case "$selection" in
        toggle) run_action radio wifi off; exit ;;
        refresh) run_action device wifi rescan ifname "$interface"; continue ;;
        forget:*)
            address=${selection#forget:}
            ssid=''
            while IFS=: read -r active signal security rest; do
                [[ ${#rest} -ge 18 ]] || continue
                bssid="${rest: -17}"
                [[ "$bssid" == "$address" ]] || continue
                ssid="${rest:0:${#rest}-18}"
                break
            done < <(nmcli -t -e no -f IN-USE,SIGNAL,SECURITY,SSID,BSSID device wifi list ifname "$interface" --rescan no)
            [[ -n "$ssid" ]] || continue
            nmcli connection delete id "$ssid" >/dev/null 2>&1 || report "Could not forget $ssid"
            continue ;;
    esac
    [[ "$selection" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] || exit 0
    # Resolve the selected BSSID against the latest cache, not a stale row index.
    addresses=() names=() securities=() connected=()
    while IFS=: read -r active signal security rest; do
        [[ ${#rest} -ge 18 ]] || continue
        bssid="${rest: -17}"
        ssid="${rest:0:${#rest}-18}"
        [[ "$bssid" == "$selection" ]] || continue
        addresses+=("$bssid") names+=("$ssid") securities+=("$security") connected+=("$active")
    done < <(nmcli -t -e no -f IN-USE,SIGNAL,SECURITY,SSID,BSSID device wifi list ifname "$interface" --rescan no)
    index=0
    ((index >= 0 && index < ${#addresses[@]})) || exit 0
    if [[ "${connected[index]}" == '*' ]]; then
        run_action device disconnect "$interface"
        exit
    fi
    if result=$(nmcli --wait 15 device wifi connect "${addresses[index]}" ifname "$interface" 2>&1); then
        :
    elif [[ "${securities[index]}" != '--' && -n "${securities[index]}" ]]; then
        password=$("$config_dir/bin/wifi-panel" "$config_dir/wifi-panel.css" \
            --password "${names[index]}" </dev/null) || exit 0
        [[ -n "$password" ]] || exit 0
        # Pass the entered password explicitly; nmcli --ask does not consume a pipe reliably.
        if result=$(nmcli --wait 20 device wifi connect "${addresses[index]}" \
            password "$password" ifname "$interface" 2>&1); then
            :
        else
            report 'Connection failed. Check the password or open Connection settings.'
        fi
        unset password
    else
        report "$result"
    fi
    exit
done
