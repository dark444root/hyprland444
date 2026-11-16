#!/usr/bin/env bash
# Instala el plugin hyprbars (barras de título estilo Windows) y lo activa
set -e
echo ">> Preparando hyprpm (puede tardar unos minutos la primera vez)..."
hyprpm update
echo ">> Descargando plugins oficiales de Hyprland..."
hyprpm add https://github.com/hyprwm/hyprland-plugins || true
echo ">> Activando hyprbars..."
hyprpm enable hyprbars
hyprpm reload -n

conf=~/.config/hypr/hyprland.conf
if ! grep -q "hyprbars.conf" "$conf"; then
    printf '\n# Barras de título estilo Windows\nexec-once = hyprpm reload -n\nsource = ~/.config/hypr/hyprbars.conf\n' >> "$conf"
fi
hyprctl reload >/dev/null
notify-send -a "Aurora" "Barras de título activadas" "Ya tienes  —  □  ✕  en tus ventanas"
echo ">> ¡Listo!"
