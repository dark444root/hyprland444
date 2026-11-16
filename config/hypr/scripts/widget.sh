#!/usr/bin/env bash
# Widgets de escritorio estilo iPad, difuminados (en cada monitor)
#   widget.sh          -> lo (re)inicia
#   widget.sh toggle   -> lo muestra / oculta  (Windows + Alt + W)
W=~/.config/hypr/widget
LOG="$W/registro.log"

CENTRO="python3 $HOME/.config/hypr/scripts/centro-control.py escritorio"
if [ "$1" = "toggle" ] && pkill -x widgetbar; then pkill -f "centro-control.py escritorio"; exit 0; fi
pkill -x widgetbar
pkill -f "centro-control.py escritorio"      # cierra TODOS los paneles anteriores (evita duplicados)
sleep 0.3

mkdir -p ~/.local/bin
ln -sf "$(command -v waybar)" ~/.local/bin/widgetbar
[ -f "$W/foto2" ] || cp "$W/foto" "$W/foto2"
[ -f "$W/foto3" ] || cp "$W/foto" "$W/foto3"

# ---- Desenfoque (efecto vidrio) detrás de los widgets ----
# Tu Hyprland es >= 0.51; se prueban las sintaxis nueva y anterior y se anota cuál funcionó
{
echo "== $(date) =="
hyprctl version | head -1
probar() {
    for r in "$@"; do
        res=$(hyprctl keyword layerrule "$r" 2>&1)
        echo "layerrule = $r  ->  $res"
        [[ "$res" == ok* ]] && return 0
    done
    return 1
}
probar "match:namespace waybar, blur on" "blur on, match:namespace waybar" "blur, waybar"
probar "match:namespace waybar, ignore_alpha 0.15" "ignore_alpha 0.15, match:namespace waybar" "ignorealpha 0.15, waybar"
} > "$LOG" 2>&1

python3 ~/.config/hypr/scripts/widget-generar.py >> "$LOG" 2>&1 || { notify-send "Widgets: error, revisa $LOG"; exit 1; }
# Centro de Control fijo en el escritorio, uno por monitor (compacto en pantallas chicas)
for pos in $(hyprctl monitors -j | python3 -c 'import json,sys;[print("%d,%d" % (m["x"], m["y"])) for m in json.load(sys.stdin)]'); do
    setsid $CENTRO "$pos" >> "$LOG" 2>&1 &
done
exec ~/.local/bin/widgetbar -c "$W/config.jsonc" -s "$W/style.css" >> "$LOG" 2>&1
