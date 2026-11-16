#!/usr/bin/env bash
# Menú de Wi-Fi estilo Mac (clic en el icono de Wi-Fi)
#   wifi.sh          -> menú
#   wifi.sh toggle   -> encender / apagar
TEMA=~/.config/hypr/widget/control.rasi
# Origen: "barra" (desplegable arriba a la derecha) o "widget" (flotante sobre el widget)
ORIGEN=barra; [ "$1" = "widget" ] && { ORIGEN=widget; shift; }
if [ "$ORIGEN" = "widget" ]; then
    # Estilo iPhone: pantalla oscurecida y panel grande al centro
    POS='window { padding: 0px; background-color: rgba(0, 0, 0, 58%); }
         fila { children: [ relleno, columna, relleno3 ]; }
         relleno3 { expand: true; }
         columna { width: 480px; children: [ relleno2, mainbox, relleno4 ]; }
         relleno4 { expand: true; }
         mainbox { padding: 22px; spacing: 14px; border-radius: 34px;
                   background-color: rgba(44, 44, 50, 92%); border-color: rgba(255, 255, 255, 10%); }
         inputbar { padding: 4px 8px 8px 8px; }
         prompt { font: "Inter Bold 22"; }
         element { padding: 14px 16px; spacing: 16px; border-radius: 18px; }
         element-text { font: "Inter 14"; }
         element-icon { size: 30px; }
         element selected { background-color: rgba(255, 255, 255, 14%); }
         listview { spacing: 6px; }'
else
    POS='window { padding: 40px 14px 0px 0px; }'
fi
# rofi_menu NUM_FILAS [opciones]: la lista mide exactamente lo que necesita
rofi_menu() { local n=$1; shift; [ "$n" -gt 12 ] && n=12; [ "$n" -lt 1 ] && n=1
              rofi -dmenu -show-icons -i -format i -theme "$TEMA" -theme-str "$POS" -l "$n" "$@"; }
pkill -x rofi && exit 0

if [ "$1" = "toggle" ]; then
    [ "$(nmcli -t -f WIFI g)" = "enabled" ] && nmcli radio wifi off || nmcli radio wifi on
    pkill -RTMIN+11 widgetbar; exit 0
fi

estado=$(nmcli -t -f WIFI g)
filas=(); acciones=()
if [ "$estado" = "enabled" ]; then
    filas+=("Apagar Wi-Fi\0icon\x1fsystem-shutdown"); acciones+=("off")
    nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan auto 2>/dev/null | \
    awk -F: '$2!="" && !v[$2]++' > /tmp/.wifi-lista
    while IFS=: read -r uso ssid senal seg; do
        if   [ "$senal" -ge 75 ]; then ic=network-wireless-signal-excellent
        elif [ "$senal" -ge 50 ]; then ic=network-wireless-signal-good
        elif [ "$senal" -ge 25 ]; then ic=network-wireless-signal-ok
        else ic=network-wireless-signal-weak; fi
        marca=""; [ "$uso" = "*" ] && marca="  ✓"
        candado=""; [ -n "$seg" ] && [ "$seg" != "--" ] && candado="  🔒"
        filas+=("$ssid$marca$candado\0icon\x1f$ic"); acciones+=("red:$ssid:$seg:$uso")
    done < /tmp/.wifi-lista
else
    filas+=("Encender Wi-Fi\0icon\x1fnetwork-wireless"); acciones+=("on")
fi
filas+=("Configuración de red…\0icon\x1fpreferences-system-network"); acciones+=("config")

i=$(printf '%b\n' "${filas[@]}" | rofi_menu ${#filas[@]} -p "Wi-Fi") || exit 0
accion=${acciones[$i]}

case "$accion" in
  off) nmcli radio wifi off; notify-send -a "Wi-Fi" "Wi-Fi apagado" ;;
  on)  nmcli radio wifi on; notify-send -a "Wi-Fi" "Wi-Fi activado" ;;
  config) command -v nm-connection-editor >/dev/null && nm-connection-editor || kitty -e nmtui ;;
  red:*)
    IFS=: read -r _ ssid seg uso <<< "$accion"
    if [ "$uso" = "*" ]; then
        nmcli con down id "$ssid" && notify-send -a "Wi-Fi" "Desconectado de $ssid"
    elif nmcli -t -f NAME con show | grep -qx "$ssid"; then
        nmcli con up id "$ssid" && notify-send -a "Wi-Fi" "Conectado a $ssid" || notify-send -a "Wi-Fi" "No se pudo conectar a $ssid"
    else
        if [ -n "$seg" ] && [ "$seg" != "--" ]; then
            pass=$(rofi -dmenu -password -p "Contraseña de $ssid" -theme "$TEMA" -theme-str "$POS" -l 0 < /dev/null) || exit 0
            nmcli dev wifi connect "$ssid" password "$pass" && notify-send -a "Wi-Fi" "Conectado a $ssid" \
              || notify-send -a "Wi-Fi" "Contraseña incorrecta o error al conectar"
        else
            nmcli dev wifi connect "$ssid" && notify-send -a "Wi-Fi" "Conectado a $ssid"
        fi
    fi ;;
esac
pkill -RTMIN+11 widgetbar
