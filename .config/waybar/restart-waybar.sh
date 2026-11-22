pkill waybar 2>/dev/null || true
waybar > /tmp/waybar.log 2>&1 &
disown
