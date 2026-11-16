#!/usr/bin/env bash
# Menú de energía · Tema AURORA
opcion=$(printf "   Bloquear\n   Suspender\n   Cerrar sesión\n   Reiniciar\n   Apagar" \
    | wofi --dmenu --prompt "Hasta luego, __NOMBRE__" --width 320 --height 300 \
           --hide-scroll --cache-file /dev/null)

case "$opcion" in
    *Bloquear)        hyprlock ;;
    *Suspender)       systemctl suspend ;;
    *"Cerrar sesión") hyprctl dispatch exit ;;
    *Reiniciar)       systemctl reboot ;;
    *Apagar)          systemctl poweroff ;;
esac
