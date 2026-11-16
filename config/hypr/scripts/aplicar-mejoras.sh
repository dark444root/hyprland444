#!/usr/bin/env bash
# ============================================================
#  Mejoras: 1) iconos Papirus  2) apps en modo oscuro
#           4) Mission Control (Windows + Tab)  5) gestos de 3 dedos
#  Para deshacer todo:  bash ~/.config/hypr/scripts/revertir-mejoras.sh
# ============================================================
H=~/.config/hypr
R=$H/respaldo-antes-mejoras
GS=org.gnome.desktop.interface

echo ">> Guardando tu configuración actual en $R"
mkdir -p "$R"
cp "$H/hyprland.conf" "$R/hyprland.conf"
for v in 3.0 4.0; do
    [ -f ~/.config/gtk-$v/settings.ini ] && cp ~/.config/gtk-$v/settings.ini "$R/gtk-$v.ini"
done
gsettings get $GS icon-theme   > "$R/icon-theme"   2>/dev/null
gsettings get $GS gtk-theme    > "$R/gtk-theme"    2>/dev/null
gsettings get $GS color-scheme > "$R/color-scheme" 2>/dev/null

echo ">> Instalando iconos Papirus y tema oscuro (pide tu contraseña)"
sudo apt install -y papirus-icon-theme gnome-themes-extra

echo ">> 1 y 2: iconos y modo oscuro"
for v in 3.0 4.0; do
    mkdir -p ~/.config/gtk-$v
    python3 - "$HOME/.config/gtk-$v/settings.ini" <<'PY'
import sys, configparser
p = sys.argv[1]
c = configparser.ConfigParser(); c.optionxform = str
c.read(p)
if "Settings" not in c: c["Settings"] = {}
s = c["Settings"]
s["gtk-theme-name"] = "Adwaita-dark"
s["gtk-icon-theme-name"] = "Papirus-Dark"
s["gtk-application-prefer-dark-theme"] = "1"
with open(p, "w") as f: c.write(f, space_around_delimiters=False)
PY
done
gsettings set $GS gtk-theme 'Adwaita-dark'     2>/dev/null
gsettings set $GS icon-theme 'Papirus-Dark'    2>/dev/null
gsettings set $GS color-scheme 'prefer-dark'   2>/dev/null

# Versión de Hyprland (la sintaxis de gestos cambió en 0.51)
ver=$(hyprctl version -j 2>/dev/null | python3 -c 'import json,sys,re
d=json.load(sys.stdin); m=re.search(r"(\d+)\.(\d+)", d.get("tag","") or d.get("version",""))
print(f"{m.group(1)} {m.group(2)}" if m else "0 0")')
read mayor menor <<< "$ver"
echo ">> Hyprland $mayor.$menor"

{
echo "# ============================================================"
echo "#  Mejoras (iconos, gestos, Mission Control) — generado por aplicar-mejoras.sh"
echo "#  Para deshacer: bash ~/.config/hypr/scripts/revertir-mejoras.sh"
echo "# ============================================================"
echo
echo "# 5 · Gestos: desliza con 3 dedos a los lados para cambiar de escritorio"
if [ "$mayor" -gt 0 ] || [ "$menor" -ge 51 ]; then
    echo "gesture = 3, horizontal, workspace"
else
    echo "gestures {"
    echo "    workspace_swipe = true"
    echo "    workspace_swipe_fingers = 3"
    echo "    workspace_swipe_cancel_ratio = 0.2"
    echo "}"
fi
} > "$H/mejoras.conf"

echo ">> 4: Mission Control (plugin hyprexpo)"
if hyprpm enable hyprexpo 2>/dev/null || { hyprpm update && hyprpm enable hyprexpo; }; then
    hyprpm reload -n
    cat >> "$H/mejoras.conf" <<'CONF'

# 4 · Mission Control: Windows + Tab muestra todos los escritorios en miniatura
plugin {
    hyprexpo {
        columns = 3
        gap_size = 10
        bg_col = rgb(0b0b0d)
        workspace_method = center current
    }
}
unbind = $mod, Tab
bind = $mod, Tab, hyprexpo:expo, toggle
CONF
    expo="sí"
else
    expo="no (no se pudo compilar el plugin)"
fi

grep -q "mejoras.conf" "$H/hyprland.conf" || \
    printf '\n# Mejoras visuales (se quitan con revertir-mejoras.sh)\nsource = ~/.config/hypr/mejoras.conf\n' >> "$H/hyprland.conf"

hyprctl reload >/dev/null
pkill waybar; (waybar >/dev/null 2>&1 &)
notify-send -a "Mejoras" "Mejoras aplicadas" "Iconos, modo oscuro y gestos listos · Mission Control: $expo"
echo
echo ">> ¡Listo!  Mission Control: $expo"
echo ">> Cierra y vuelve a abrir tus apps para ver los iconos y el modo oscuro."
echo ">> Para regresar como estaba:  bash ~/.config/hypr/scripts/revertir-mejoras.sh"
