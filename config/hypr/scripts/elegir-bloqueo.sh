#!/usr/bin/env bash
# Cambia la imagen de la pantalla de bloqueo (hyprlock)
#   elegir-bloqueo.sh            -> galería para elegir imagen   (Windows + Alt + L)
#   elegir-bloqueo.sh ruta.jpg   -> usa esa imagen directo
#   elegir-bloqueo.sh --tema     -> vuelve a usar el fondo del tema
B=~/.config/hypr/bloqueo
mkdir -p "$B"
pkill -x rofi

if [ "$1" = "--tema" ]; then
    sel=~/.config/hypr/wallpapers/actual.png
elif [ -n "$1" ]; then
    sel="$1"
elif command -v rofi >/dev/null; then
    sel=$(python3 ~/.config/hypr/scripts/galeria.py "$HOME/Imágenes")
else
    sel=$(yad --file --title="Imagen para la pantalla de bloqueo" --add-preview --large-preview \
              --file-filter="Imágenes | *.jpg *.jpeg *.png *.webp *.JPG *.PNG" \
              --filename="$HOME/Imágenes/" --width=1100 --height=700 --center 2>/dev/null)
fi
[ -z "$sel" ] || [ ! -f "$sel" ] && exit 0

# hyprlock carga mejor PNG: convertir si hay ImageMagick
if command -v magick >/dev/null; then magick "$sel" "$B/fondo.png"
elif command -v convert >/dev/null; then convert "$sel" "$B/fondo.png"
else cp "$sel" "$B/fondo.png"; fi

notify-send -a "Bloqueo" "Imagen de bloqueo cambiada" "$(basename "$sel")  ·  Pruébala con Windows + L" \
    -i "$B/fondo.png" 2>/dev/null
