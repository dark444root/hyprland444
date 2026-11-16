#!/usr/bin/env bash
# Cambia el tema completo (Hyprland, barra, menú, terminal, notificaciones, bloqueo y fondo)
# Uso:  cambiar-tema.sh            -> muestra un menú
#       cambiar-tema.sh hacker     -> cambia directo
H=~/.config/hypr
TEMAS=$H/temas

tema="$1"
if [ -z "$tema" ]; then
    tema=$(ls "$TEMAS" | wofi --dmenu --prompt "Elige un tema" --width 300 --height 220 \
           --cache-file /dev/null)
fi
[ -z "$tema" ] && exit 0
T=$TEMAS/$tema
[ -d "$T" ] || { notify-send "Tema '$tema' no existe"; exit 1; }

mkdir -p ~/.config/wofi ~/.config/mako ~/.config/kitty $H/wallpapers
cp "$T/tema.conf"       $H/tema.conf
cp "$T/hyprbars.conf"   $H/hyprbars.conf
cp "$T/hyprlock.conf"   $H/hyprlock.conf
cp "$T/fondo.png"       $H/wallpapers/actual.png
cp "$T/waybar.jsonc"    ~/.config/waybar/config.jsonc
cp "$T/waybar.css"      ~/.config/waybar/style.css
cp "$T/wofi-config"     ~/.config/wofi/config
cp "$T/wofi.css"        ~/.config/wofi/style.css
cp "$T/mako"            ~/.config/mako/config
cp "$T/kitty-colores.conf" ~/.config/kitty/colores.conf
mkdir -p ~/.config/nwg-drawer
[ -f "$T/drawer.css" ] && cp "$T/drawer.css" ~/.config/nwg-drawer/drawer.css
mkdir -p ~/.config/rofi
[ -f "$T/rofi-menu.rasi" ] && cp "$T/rofi-menu.rasi" ~/.config/rofi/menu-gnome.rasi
echo "$tema" > $H/tema-actual

# Aplicar en vivo
hyprctl reload >/dev/null
pkill -USR1 -f fondos-escritorio.py || (python3 $H/scripts/fondos-escritorio.py >/dev/null 2>&1 &)
pkill waybar; (waybar >/dev/null 2>&1 &)
makoctl reload 2>/dev/null
pkill -USR1 kitty 2>/dev/null
sleep 0.5
notify-send -a "Temas" "Tema activado: $tema"
