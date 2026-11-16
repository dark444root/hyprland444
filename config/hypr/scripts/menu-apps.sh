#!/usr/bin/env bash
# Menú de aplicaciones estilo Launchpad/GNOME (rápido)
# Presionar otra vez la tecla Windows (o Esc) lo cierra.
pkill -x 'rofi|wofi|nwg-drawer' && exit 0

if command -v rofi >/dev/null; then
    # Solo vuelve a leer las apps si instalaste algo nuevo desde la última vez
    cache="${XDG_CACHE_HOME:-$HOME/.cache}/rofi3.druncache"
    extra=()
    if [ ! -f "$cache" ] || [ -n "$(find /usr/share/applications ~/.local/share/applications \
            /var/lib/flatpak/exports/share/applications -name '*.desktop' -newer "$cache" \
            -print -quit 2>/dev/null)" ]; then
        extra=(-drun-reload-desktop-cache)
    fi
    exec rofi -show drun -theme ~/.config/rofi/menu-gnome.rasi "${extra[@]}"
elif command -v nwg-drawer >/dev/null; then
    exec nwg-drawer -c 7 -is 64 -fm thunar -term kitty
else
    exec wofi --show drun
fi
