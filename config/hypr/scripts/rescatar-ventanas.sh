#!/usr/bin/env bash
# Regresa al escritorio actual TODAS las ventanas que estén en escritorios especiales
# (minimizadas, terminal, bolsillo) para que vuelvan a verse.
sleep 1
ws=$(hyprctl activeworkspace -j | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])' 2>/dev/null)
[ -z "$ws" ] && ws=1
n=0
for addr in $(hyprctl clients -j | python3 -c '
import json,sys
for w in json.load(sys.stdin):
    if w["workspace"]["name"].startswith("special"):
        print(w["address"])
'); do
    hyprctl dispatch movetoworkspacesilent "$ws,address:$addr" >/dev/null
    n=$((n+1))
done
# por si alguna quedó fijada en todos los escritorios
for addr in $(hyprctl clients -j | python3 -c '
import json,sys
for w in json.load(sys.stdin):
    if w.get("pinned"): print(w["address"])
'); do
    hyprctl dispatch pin "address:$addr" >/dev/null
done
pkill -RTMIN+8 waybar
notify-send -a "Aurora" "Ventanas recuperadas" "$n ventana(s) regresaron al escritorio $ws"
touch ~/.config/hypr/.rescate-hecho
