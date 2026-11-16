#!/usr/bin/env bash
# Cambia el cursor del mouse (Windows + Alt + C)
#   Elige un tema instalado o descarga uno popular, luego el tamaño.
ICONS=~/.local/share/icons
CONF=~/.config/hypr/cursor.conf
mkdir -p "$ICONS"

declare -A DESCARGA=(
  ["macOS (blanco)"]="https://github.com/ful1e5/apple_cursor/releases/latest/download/macOS.tar.xz|macOS-White"
  ["macOS (negro)"]="https://github.com/ful1e5/apple_cursor/releases/latest/download/macOS.tar.xz|macOS"
  ["Bibata clásico (negro)"]="https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Classic.tar.xz|Bibata-Modern-Classic"
  ["Bibata hielo (blanco)"]="https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Ice.tar.xz|Bibata-Modern-Ice"
  ["Bibata ámbar"]="https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Amber.tar.xz|Bibata-Modern-Amber"
)

# Temas ya instalados (carpetas que tienen cursores)
instalados=$(for d in /usr/share/icons/* ~/.icons/* "$ICONS"/*; do
    [ -d "$d/cursors" ] && basename "$d"; done | sort -u)

opciones=$( { for k in "${!DESCARGA[@]}"; do
                 t=${DESCARGA[$k]#*|}
                 grep -qx "$t" <<< "$instalados" || echo "⬇  $k"
             done | sort
             echo "$instalados" | sed 's/^/●  /'; } )

sel=$(echo "$opciones" | wofi --dmenu --prompt "Elige un cursor" --width 460 --height 480 --cache-file /dev/null)
[ -z "$sel" ] && exit 0

if [[ "$sel" == "⬇  "* ]]; then
    k=${sel#⬇  }; url=${DESCARGA[$k]%|*}; tema=${DESCARGA[$k]#*|}
    notify-send -a "Cursor" "Descargando $k…"
    tmp=$(mktemp -d)
    if curl -sSL -o "$tmp/c.tar.xz" "$url" && tar -xf "$tmp/c.tar.xz" -C "$ICONS"; then
        rm -rf "$tmp"
    else
        rm -rf "$tmp"; notify-send -a "Cursor" "No se pudo descargar $k"; exit 1
    fi
else
    tema=${sel#●  }
fi

tam=$(printf "24\n32\n40\n48\n64" | wofi --dmenu --prompt "Tamaño (actual 24)" --width 300 --height 280 --cache-file /dev/null)
[ -z "$tam" ] && tam=24

# Aplicar ya
hyprctl setcursor "$tema" "$tam" >/dev/null
gsettings set org.gnome.desktop.interface cursor-theme "$tema" 2>/dev/null
gsettings set org.gnome.desktop.interface cursor-size "$tam" 2>/dev/null

# Guardar para los siguientes inicios
cat > "$CONF" <<CONF
# Cursor elegido con cursor.sh (Windows + Alt + C)
env = XCURSOR_THEME,$tema
env = XCURSOR_SIZE,$tam
env = HYPRCURSOR_THEME,$tema
env = HYPRCURSOR_SIZE,$tam
exec-once = hyprctl setcursor $tema $tam
CONF
mkdir -p ~/.icons/default
printf "[Icon Theme]\nInherits=%s\n" "$tema" > ~/.icons/default/index.theme
for v in 3.0 4.0; do
    f=~/.config/gtk-$v/settings.ini; mkdir -p "$(dirname "$f")"; [ -f "$f" ] || echo "[Settings]" > "$f"
    sed -i '/^gtk-cursor-theme-name=/d; /^gtk-cursor-theme-size=/d' "$f"
    sed -i "/^\[Settings\]/a gtk-cursor-theme-name=$tema\ngtk-cursor-theme-size=$tam" "$f"
done
notify-send -a "Cursor" "Cursor cambiado" "$tema · tamaño $tam (algunas apps lo toman al reabrirlas)"
