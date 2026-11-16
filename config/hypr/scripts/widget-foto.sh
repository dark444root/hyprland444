#!/usr/bin/env bash
# Elige la foto del widget en una galería con miniaturas grandes y carpetas
#   widget-foto.sh [foto|foto2|foto3]
W=~/.config/hypr/widget
slot="${1:-foto}"
pkill -x rofi

if command -v rofi >/dev/null; then
    sel=$(python3 ~/.config/hypr/scripts/galeria.py "$HOME/Imágenes")
else
    sel=$(yad --file --title="Elige una foto para el widget" --add-preview --large-preview \
              --file-filter="Imágenes | *.jpg *.jpeg *.png *.webp *.JPG *.PNG" \
              --filename="$HOME/Imágenes/" --width=1100 --height=700 --center 2>/dev/null)
fi

[ -z "$sel" ] || [ ! -f "$sel" ] && exit 0
cp "$sel" "$W/$slot"
bash ~/.config/hypr/scripts/widget.sh >/dev/null 2>&1 &
notify-send -a "Widget" "Foto cambiada" "$(basename "$sel")"
