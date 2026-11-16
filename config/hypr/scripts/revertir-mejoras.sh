#!/usr/bin/env bash
# Regresa todo a como estaba antes de aplicar-mejoras.sh
H=~/.config/hypr
R=$H/respaldo-antes-mejoras
GS=org.gnome.desktop.interface
[ -d "$R" ] || { echo "No encontré el respaldo en $R"; exit 1; }

sed -i '/# Mejoras visuales (se quitan con revertir-mejoras.sh)/d; /source = ~\/.config\/hypr\/mejoras.conf/d' "$H/hyprland.conf"
echo "# (mejoras desactivadas)" > "$H/mejoras.conf"
hyprpm disable hyprexpo 2>/dev/null

for v in 3.0 4.0; do
    if [ -f "$R/gtk-$v.ini" ]; then cp "$R/gtk-$v.ini" ~/.config/gtk-$v/settings.ini
    else : > ~/.config/gtk-$v/settings.ini; fi
done
for k in icon-theme gtk-theme color-scheme; do
    [ -s "$R/$k" ] && gsettings set $GS $k "$(cat "$R/$k")" 2>/dev/null
done

hyprctl reload >/dev/null
pkill waybar; (waybar >/dev/null 2>&1 &)
notify-send -a "Mejoras" "Listo" "Todo regresó a como estaba"
echo ">> Listo, todo regresó a como estaba."
