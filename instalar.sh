#!/usr/bin/env bash
# ============================================================
#   Instalador de hyprland-dotfiles
#   Temas (macOS, Aurora, Cielo, Hacker, Windows), widgets, Centro de Control,
#   fondos por escritorio, capturas estilo GNOME, terminal bonita y más.
#
#   Uso:   bash instalar.sh                 (instala todo)
#          bash instalar.sh --sin-paquetes  (no instala programas con apt)
#          bash instalar.sh --tema aurora   (elige el tema inicial)
#          bash instalar.sh --bloqueo-al-iniciar  (al encender, directo a la pantalla de bloqueo)
#          bash instalar.sh --nombre Ana    (nombre que aparece al bloquear/saludar)
# ============================================================
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
C=~/.config
FECHA=$(date +%Y%m%d-%H%M%S)
RESPALDO="$C/respaldo-hyprland-$FECHA"
PAQUETES=1
TEMA=""
NOMBRE=""
BLOQUEO=0
while [ $# -gt 0 ]; do
    case "$1" in
        --sin-paquetes) PAQUETES=0 ;;
        --tema) TEMA="$2"; shift ;;
        --nombre) NOMBRE="$2"; shift ;;
        --bloqueo-al-iniciar) BLOQUEO=1 ;;
    esac
    shift
done

verde() { printf '\033[1;32m%s\033[0m\n' "$*"; }
gris()  { printf '\033[0;37m  %s\033[0m\n' "$*"; }
aviso() { printf '\033[1;33m!! %s\033[0m\n' "$*"; }

echo
verde "=============================================="
verde "     Instalando hyprland-dotfiles"
verde "=============================================="
echo

command -v Hyprland >/dev/null || command -v hyprland >/dev/null || \
    aviso "No encontré Hyprland instalado. Se copiará la configuración igual; instala Hyprland para usarla."

# ---------------------------------------------------- 1. Programas
if [ "$PAQUETES" = 1 ] && command -v apt >/dev/null; then
    verde "[1/7] Instalando programas (pide tu contraseña)…"
    sudo apt update -qq
    LISTA="waybar wofi rofi kitty mako-notifier swaybg swww hyprlock hypridle hyprpicker
           grim slurp wl-clipboard swappy cliphist brightnessctl playerctl pavucontrol
           network-manager-gnome blueman bluez libnotify-bin thunar yad curl imagemagick
           python3 python3-gi python3-gi-cairo gir1.2-gtk-3.0 gir1.2-gtklayershell-0.1
           papirus-icon-theme gnome-themes-extra fonts-inter fonts-font-awesome
           fonts-jetbrains-mono policykit-1-gnome xdg-user-dirs wireplumber
           fastfetch eza btop"
    faltan=()
    for p in $LISTA; do
        if ! dpkg -s "$p" >/dev/null 2>&1; then
            sudo apt install -y -qq "$p" >/dev/null 2>&1 && gris "✓ $p" || faltan+=("$p")
        fi
    done
    [ ${#faltan[@]} -gt 0 ] && aviso "No disponibles en tus repositorios (no es grave): ${faltan[*]}"
else
    verde "[1/7] Saltando instalación de programas"
fi

# ---------------------------------------------------- 2. Respaldo
verde "[2/7] Respaldando tu configuración actual en $RESPALDO"
mkdir -p "$RESPALDO"
for d in hypr waybar wofi rofi kitty mako nwg-drawer; do
    [ -e "$C/$d" ] && cp -a "$C/$d" "$RESPALDO/" && gris "respaldado: $d"
done

# ---------------------------------------------------- 3. Copiar archivos
verde "[3/7] Copiando configuración, temas, scripts y fondos"
mkdir -p "$C/hypr" "$C/kitty" "$C/waybar" "$C/wofi" "$C/rofi" "$C/mako" "$C/nwg-drawer" ~/.local/bin
cp -r "$DIR/config/hypr/." "$C/hypr/"
cp "$DIR/config/kitty/kitty.conf" "$C/kitty/kitty.conf"
# Tu nombre en el saludo, la pantalla de bloqueo y el menú de apagado
if [ -z "$NOMBRE" ]; then
    NOMBRE=$(getent passwd "$USER" | cut -d: -f5 | cut -d, -f1 | awk '{print $1}')
    [ -z "$NOMBRE" ] && NOMBRE="${USER^}"
fi
INICIAL=$(printf %s "$NOMBRE" | cut -c1 | tr "[:lower:]" "[:upper:]")
grep -rlI "__NOMBRE__\|__INICIAL__" "$C/hypr" | xargs -r sed -i "s/__NOMBRE__/$NOMBRE/g; s/__INICIAL__/$INICIAL/g"
gris "nombre: $NOMBRE"
chmod +x "$C/hypr/scripts/"* 2>/dev/null
mkdir -p "$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Imágenes")/Capturas de pantalla"

# ---------------------------------------------------- 4. Tema
[ -z "$TEMA" ] && TEMA=$(cat "$C/hypr/tema-actual" 2>/dev/null || echo macos)
[ -d "$C/hypr/temas/$TEMA" ] || TEMA=macos
verde "[4/7] Aplicando el tema: $TEMA"
bash "$C/hypr/scripts/cambiar-tema.sh" "$TEMA" >/dev/null 2>&1

# ---------------------------------------------------- 5. Botones de ventana (plugin hyprbars)
verde "[5/7] Botones estilo Mac en las ventanas (plugin hyprbars)"
BARRAS=0
if command -v hyprpm >/dev/null && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    if hyprpm list 2>/dev/null | grep -q hyprbars || \
       { hyprpm update && hyprpm add https://github.com/hyprwm/hyprland-plugins; hyprpm enable hyprbars; } >/dev/null 2>&1; then
        hyprpm enable hyprbars >/dev/null 2>&1; BARRAS=1; gris "✓ hyprbars activo"
    fi
fi
if [ "$BARRAS" = 0 ]; then
    sed -i 's#^source = ~/.config/hypr/hyprbars.conf#\# source = ~/.config/hypr/hyprbars.conf   (actívalo con: bash ~/.config/hypr/scripts/instalar-barras.sh)#' "$C/hypr/hyprland.conf"
    aviso "No se pudo activar hyprbars ahora (necesita estar dentro de Hyprland)."
    gris "Después, dentro de Hyprland:  bash ~/.config/hypr/scripts/instalar-barras.sh"
fi

# ---------------------------------------------------- 6. Iconos, modo oscuro y gestos
verde "[6/7] Iconos Papirus, apps en modo oscuro y gestos del touchpad"
bash "$C/hypr/scripts/aplicar-mejoras.sh" </dev/null >/dev/null 2>&1 && gris "✓ listo" || aviso "Se aplicará al entrar a Hyprland: bash ~/.config/hypr/scripts/aplicar-mejoras.sh"

# ---------------------------------------------------- 7. Terminal bonita
verde "[7/7] Terminal con prompt de colores, iconos y fastfetch"
bash "$C/hypr/scripts/terminal-bonita.sh" </dev/null >/dev/null 2>&1 && gris "✓ listo" || aviso "Revisa: bash ~/.config/hypr/scripts/terminal-bonita.sh"

# ---------------------------------------------------- Bloqueo al encender (opcional)
if [ "$BLOQUEO" = 1 ]; then
    sudo bash "$C/hypr/scripts/bloqueo-al-iniciar.sh"
else
    sed -i 's/^exec-once = hyprlock$/# exec-once = hyprlock/' "$C/hypr/hyprland.conf"
fi

# ---------------------------------------------------- Arrancar si ya estamos en Hyprland
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprctl reload >/dev/null 2>&1
    pkill -f fondos-escritorio.py; (python3 "$C/hypr/scripts/fondos-escritorio.py" >/dev/null 2>&1 &)
    (bash "$C/hypr/scripts/widget.sh" >/dev/null 2>&1 &)
fi

echo
verde "=============================================="
verde "   ¡Instalación terminada!"
verde "=============================================="
echo "  • Cierra sesión y vuelve a entrar (o reinicia) para que todo arranque solo."
echo "  • Tu configuración anterior quedó en: $RESPALDO"
echo
echo "  Atajos principales:"
echo "    Windows ............... menú de apps        Windows + Espacio ... buscador"
echo "    Windows + Alt + T ..... cambiar de tema     Windows + W ......... fondo del escritorio"
echo "    Windows + Alt + W ..... mostrar widgets     Windows + Alt + C ... cambiar cursor"
echo "    Impr Pant ............. captura de área     Windows + Tab ....... siguiente escritorio"
echo
