#!/usr/bin/env bash
# Minimiza la ventana activa (la guarda en un escritorio oculto "minimizadas")
app=$(hyprctl activewindow -j | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d.get("class",""))' 2>/dev/null)
[ -z "$app" ] && exit 0
hyprctl dispatch movetoworkspacesilent special:minimizadas >/dev/null
pkill -RTMIN+8 waybar
notify-send -a "Aurora" -t 2500 "$app minimizada" "Recupérala en el botón amarillo de la barra superior (o Windows + Shift + M)"
