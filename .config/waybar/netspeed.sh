#!/usr/bin/env bash
# Follow the default route and read kernel counters without per-sample nmcli calls.
MODE="${1:-both}"
state_dir="${XDG_RUNTIME_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}/waybar-transfers"
mkdir -p "$state_dir"
select_interface() {
    local dev destination gateway flags ref use metric mask rest best=2147483647
    INTERFACE=''
    while read -r dev destination gateway flags ref use metric mask rest; do
        [[ "$destination" == 00000000 && "$mask" == 00000000 && "$metric" =~ ^[0-9]+$ ]] || continue
        if ((metric < best)); then INTERFACE=$dev; best=$metric; fi
    done < /proc/net/route
    # IPv6-only connections: inspect the kernel IPv6 default-route table.
    if [[ -z "$INTERFACE" && -r /proc/net/ipv6_route ]]; then
        while read -r destination prefix source source_prefix gateway metric ref use flags dev; do
            [[ "$destination" == 00000000000000000000000000000000 && "$prefix" == 00 && "$dev" != lo ]] || continue
            INTERFACE=$dev; break
        done < /proc/net/ipv6_route
    fi
}
read_counters() {
    RX=0 TX=0
    [[ -n "$INTERFACE" ]] || return 0
    read -r RX < "/sys/class/net/$INTERFACE/statistics/rx_bytes" 2>/dev/null || RX=0
    read -r TX < "/sys/class/net/$INTERFACE/statistics/tx_bytes" 2>/dev/null || TX=0
}
DISPLAY_UNIT=KB
format_rate() {
    local bytes=$1 divisor hundredths
    # Separate thresholds prevent unit flicker around 1 MB/s.
    if [[ "$DISPLAY_UNIT" == KB ]] && ((bytes >= 1100000)); then DISPLAY_UNIT=MB; fi
    if [[ "$DISPLAY_UNIT" == MB ]] && ((bytes <= 900000)); then DISPLAY_UNIT=KB; fi
    if [[ "$DISPLAY_UNIT" == MB ]]; then divisor=1000000; else divisor=1000; fi
    hundredths=$(((bytes * 100 + divisor / 2) / divisor))
    printf -v RATE '%d.%02d%s/s' "$((hundredths / 100))" "$((hundredths % 100))" "$DISPLAY_UNIT"
}
recent_down=(0 0 0); recent_up=(0 0 0)
sum_down=0 sum_up=0 samples=0 last_text=''
while true; do
    select_interface
    read_counters; RX1=$RX TX1=$TX
    sleep 1
    read_counters
    DOWN=$((RX - RX1)); UP=$((TX - TX1))
    ((DOWN < 0)) && DOWN=0
    ((UP < 0)) && UP=0
    # Raw counters drive icon motion independently of smoothed label updates.
    case "$MODE" in
        download) printf '%s %s\n' "$EPOCHSECONDS" "$DOWN" > "$state_dir/download" ;;
        upload) printf '%s %s\n' "$EPOCHSECONDS" "$UP" > "$state_dir/upload" ;;
    esac
    slot=$((samples % 3))
    sum_down=$((sum_down - recent_down[slot] + DOWN))
    sum_up=$((sum_up - recent_up[slot] + UP))
    recent_down[slot]=$DOWN; recent_up[slot]=$UP
    samples=$((samples + 1)); count=$samples; ((count > 3)) && count=3
    if ((samples == 1 || samples % 3 == 0)); then
        case "$MODE" in
            download) format_rate "$((sum_down / count))"; text=$RATE ;;
            upload) format_rate "$((sum_up / count))"; text=$RATE ;;
            *) format_rate "$((sum_down / count))"; down_text=$RATE
               format_rate "$((sum_up / count))"; text="$down_text $RATE" ;;
        esac
        if [[ "$text" != "$last_text" ]]; then printf '%s\n' "$text"; last_text=$text; fi
    fi
done
