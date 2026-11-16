#!/usr/bin/env bash
# Menú de Bluetooth estilo Mac
#   bluetooth.sh          -> menú
#   bluetooth.sh toggle   -> encender / apagar
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
encendido() { bluetoothctl show | grep -q "Powered: yes"; }

if [ "$1" = "toggle" ]; then
    if encendido; then bluetoothctl power off; else rfkill unblock bluetooth 2>/dev/null; bluetoothctl power on; fi
    pkill -RTMIN+12 widgetbar; exit 0
fi

filas=(); acciones=()
if encendido; then
    filas+=("Apagar Bluetooth\0icon\x1fsystem-shutdown"); acciones+=("off")
    while read -r _ mac nombre; do
        [ -z "$mac" ] && continue
        info=$(bluetoothctl info "$mac")
        icono=$(awk -F': ' '/Icon:/{print $2}' <<< "$info"); [ -z "$icono" ] && icono=bluetooth
        if grep -q "Connected: yes" <<< "$info"; then
            bat=$(awk -F'[()]' '/Battery Percentage/{print $2}' <<< "$info")
            extra="  ✓"; [ -n "$bat" ] && extra="  ✓  🔋$bat%"
            filas+=("$nombre$extra\0icon\x1f$icono"); acciones+=("des:$mac:$nombre")
        else
            filas+=("$nombre\0icon\x1f$icono"); acciones+=("con:$mac:$nombre")
        fi
    done < <(bluetoothctl devices Paired 2>/dev/null || bluetoothctl paired-devices)
    filas+=("Buscar dispositivos nuevos…\0icon\x1fsystem-search"); acciones+=("buscar")
else
    filas+=("Encender Bluetooth\0icon\x1fbluetooth-active"); acciones+=("on")
fi
filas+=("Configuración de Bluetooth…\0icon\x1fpreferences-system-bluetooth"); acciones+=("config")

i=$(printf '%b\n' "${filas[@]}" | rofi_menu ${#filas[@]} -p "Bluetooth") || exit 0
accion=${acciones[$i]}
case "$accion" in
  off) bluetoothctl power off; notify-send -a "Bluetooth" "Bluetooth apagado" ;;
  on)  rfkill unblock bluetooth 2>/dev/null; bluetoothctl power on; notify-send -a "Bluetooth" "Bluetooth encendido" ;;
  config) blueman-manager & ;;
  con:*) IFS=: read -r _ mac nombre <<< "$accion"
         notify-send -a "Bluetooth" "Conectando a $nombre…"
         bluetoothctl connect "$mac" && notify-send -a "Bluetooth" "Conectado a $nombre" || notify-send -a "Bluetooth" "No se pudo conectar a $nombre" ;;
  des:*) IFS=: read -r _ mac nombre <<< "$accion"
         bluetoothctl disconnect "$mac" && notify-send -a "Bluetooth" "Desconectado de $nombre" ;;
  buscar)
    notify-send -a "Bluetooth" "Buscando dispositivos…" "Pon tu dispositivo en modo de emparejamiento"
    bluetoothctl --timeout 10 scan on >/dev/null 2>&1
    nuevos=(); nf=()
    while read -r _ mac nombre; do
        bluetoothctl info "$mac" | grep -q "Paired: yes" && continue
        [[ "$nombre" =~ ^([0-9A-F]{2}-){5} ]] && continue
        nf+=("$nombre\0icon\x1fbluetooth"); nuevos+=("$mac:$nombre")
    done < <(bluetoothctl devices)
    [ ${#nf[@]} -eq 0 ] && { notify-send -a "Bluetooth" "No se encontraron dispositivos"; exit 0; }
    j=$(printf '%b\n' "${nf[@]}" | rofi_menu ${#nf[@]} -p "Emparejar") || exit 0
    IFS=: read -r mac nombre <<< "${nuevos[$j]}"
    notify-send -a "Bluetooth" "Emparejando $nombre…"
    bluetoothctl pair "$mac" && bluetoothctl trust "$mac" && bluetoothctl connect "$mac" \
      && notify-send -a "Bluetooth" "Conectado a $nombre" || notify-send -a "Bluetooth" "No se pudo emparejar $nombre" ;;
esac
pkill -RTMIN+12 widgetbar
