#!/usr/bin/env bash
# Elige el fondo de pantalla para el escritorio actual (Windows + W)
#   elegir-fondo.sh            -> menú con miniaturas
#   elegir-fondo.sh --aleatorio -> uno al azar para este escritorio
F=~/.config/hypr/fondos
MAPA=$F/escritorios.conf
MINI=$F/.miniaturas
CARPETAS=("$F" ~/Wallpapers ~/Imágenes/Fondos)
mkdir -p "$MINI"; touch "$MAPA"

ws=$(hyprctl activeworkspace -j | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])')

# Reunir imágenes
mapfile -t fondos < <(find "${CARPETAS[@]}" -maxdepth 1 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) 2>/dev/null | sort -u)

# Crear miniaturas que falten (solo la primera vez, si hay herramienta)
crear_mini() {
    if command -v magick >/dev/null;  then magick "$1" -thumbnail 192x120^ -gravity center -extent 192x120 "$2"
    elif command -v convert >/dev/null; then convert "$1" -thumbnail 192x120^ -gravity center -extent 192x120 "$2"
    elif command -v ffmpeg >/dev/null;  then ffmpeg -loglevel quiet -y -i "$1" -vf "scale=192:120:force_original_aspect_ratio=increase,crop=192:120" "$2"
    fi
}

aplicar() {
    sed -i "/^$ws=/d" "$MAPA"
    [ -n "$1" ] && echo "$ws=$1" >> "$MAPA"
    pkill -USR1 -f fondos-escritorio.py
}

if [ "$1" = "--aleatorio" ]; then
    aplicar "${fondos[RANDOM % ${#fondos[@]}]}"
    exit 0
fi

declare -A ruta_de
lista="★  Usar el fondo del tema\n⟳  Uno al azar\n📂  Abrir carpeta de fondos"
for f in "${fondos[@]}"; do
    nombre=$(basename "${f%.*}")
    ruta_de["$nombre"]="$f"
    m="$MINI/$nombre.jpg"
    # si reemplazaste la imagen, la miniatura vieja se borra y se rehace
    [ -f "$m" ] && [ "$f" -nt "$m" ] && rm -f "$m"
    [ -f "$m" ] || crear_mini "$f" "$m" 2>/dev/null
    if [ -f "$m" ]; then lista+="\nimg:$m:text:$nombre"; else lista+="\n$nombre"; fi
done

sel=$(printf "$lista" | wofi --dmenu --allow-images -D image_size=96 \
      --prompt "Fondo para el escritorio $ws" --width 520 --height 560 --cache-file /dev/null)
[ -z "$sel" ] && exit 0
sel="${sel##*:text:}"

case "$sel" in
    *"fondo del tema") aplicar "" ;;
    *"al azar")        aplicar "${fondos[RANDOM % ${#fondos[@]}]}" ;;
    *"carpeta de fondos") xdg-open "$F" || thunar "$F" & ;;
    *)                 aplicar "${ruta_de[$sel]}"
                       notify-send -a "Fondos" "Escritorio $ws → $sel" ;;
esac
