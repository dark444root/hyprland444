#!/usr/bin/env bash
# "Mostrar escritorio": minimiza todas las ventanas del escritorio actual;
# si no hay ninguna, las regresa (como la esquina de la barra en Windows)
ws=$(hyprctl activeworkspace -j | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])')
dirs=$(hyprctl clients -j | python3 -c "
import json,sys
for w in json.load(sys.stdin):
    if w['workspace']['id']==$ws: print(w['address'])
")
if [ -n "$dirs" ]; then
    for a in $dirs; do hyprctl dispatch movetoworkspacesilent "special:minimizadas,address:$a" >/dev/null; done
    pkill -RTMIN+8 waybar
else
    bash ~/.config/hypr/scripts/restaurar.sh --todas
fi
