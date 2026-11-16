#!/usr/bin/env bash
# Cambia la foto de perfil de la pantalla de bloqueo
#   elegir-perfil.sh            -> galería para elegir foto   (Windows + Alt + P)
#   elegir-perfil.sh ruta.jpg   -> usa esa foto directo
#   elegir-perfil.sh --quitar   -> sin foto (queda el círculo gris)
B=~/.config/hypr/bloqueo
mkdir -p "$B"
pkill -x rofi
if [ "$1" = "--quitar" ]; then
    rm -f "$B/perfil.png"; notify-send -a "Bloqueo" "Foto de perfil quitada"; exit 0
elif [ -n "$1" ]; then sel="$1"
else sel=$(python3 ~/.config/hypr/scripts/galeria.py "$HOME/Imágenes"); fi
[ -z "$sel" ] || [ ! -f "$sel" ] && exit 0

# Recorta al centro en cuadrado y la deja de 300x300
if command -v magick >/dev/null; then IM=magick; elif command -v convert >/dev/null; then IM=convert; else IM=""; fi
if [ -n "$IM" ]; then
    $IM "$sel" -auto-orient -resize "300x300^" -gravity center -extent 300x300 "$B/perfil.png"
else
    cp "$sel" "$B/perfil.png"
fi
cp "$B/perfil.png" ~/.face 2>/dev/null   # también la usa la pantalla de inicio (GDM/SDDM)
notify-send -a "Bloqueo" "Foto de perfil cambiada" "Pruébala con Windows + L" -i "$B/perfil.png" 2>/dev/null
