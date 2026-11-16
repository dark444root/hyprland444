#!/usr/bin/env bash
# Muestra las ventanas minimizadas y restaura la que elijas al escritorio actual
lista=$(hyprctl clients -j | python3 -c '
import json,sys
for w in json.load(sys.stdin):
    if w["workspace"]["name"]=="special:minimizadas":
        print(w["address"], "  ", w["class"], " — ", w["title"][:50])
')
if [ -z "$lista" ]; then
    notify-send -a "Aurora" "No hay ventanas minimizadas"
    exit 0
fi
if [ "$1" = "--todas" ]; then
    elegidas=$(echo "$lista" | awk '{print $1}')
else
    elegidas=$(echo "$lista" | wofi --dmenu --prompt "Restaurar ventana" --width 560 --height 300 \
               --cache-file /dev/null | awk '{print $1}')
fi
[ -z "$elegidas" ] && exit 0
ws=$(hyprctl activeworkspace -j | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])')
for addr in $elegidas; do
    hyprctl dispatch movetoworkspace "$ws,address:$addr" >/dev/null
done
hyprctl dispatch focuswindow "address:$(echo "$elegidas" | tail -1)" >/dev/null
pkill -RTMIN+8 waybar
