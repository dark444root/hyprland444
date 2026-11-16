#!/usr/bin/env bash
# Capturas de pantalla estilo GNOME
#   captura.sh area      -> arrastra para elegir el área   (Impr Pant / Windows + Shift + S)
#   captura.sh ventana   -> clic en una ventana            (Alt + Impr Pant)
#   captura.sh pantalla  -> pantalla completa              (Shift + Impr Pant)
# Se guarda en Imágenes/Capturas de pantalla y se copia al portapapeles.
modo="${1:-area}"
for p in grim slurp wl-copy; do
    command -v "$p" >/dev/null || { notify-send -a "Captura" "Falta instalar $p" "sudo apt install grim slurp wl-clipboard"; exit 1; }
done

dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Imágenes")/Capturas de pantalla"
mkdir -p "$dir"
archivo="$dir/Captura desde $(date '+%Y-%m-%d %H-%M-%S').png"

# Congelar la pantalla mientras eliges (si hyprpicker está instalado)
congelar() { command -v hyprpicker >/dev/null && { hyprpicker -r -z >/dev/null 2>&1 & sleep 0.15; }; }
descongelar() { pkill -x hyprpicker 2>/dev/null; }

ESTILO=(-b '#00000088' -c '#ffffffdd' -s '#ffffff14' -w 2)

case "$modo" in
  area)
    congelar
    geom=$(slurp -d "${ESTILO[@]}") || { descongelar; exit 0; }
    grim -g "$geom" "$archivo"; descongelar ;;
  ventana)
    # Rectángulos de las ventanas visibles; haces clic en una
    cajas=$(hyprctl monitors -j | python3 -c '
import json,sys,subprocess
ws={m["activeWorkspace"]["id"] for m in json.load(sys.stdin)}
for c in json.loads(subprocess.run(["hyprctl","clients","-j"],capture_output=True,text=True).stdout):
    if c["workspace"]["id"] in ws and c.get("mapped",True) and not c.get("hidden",False):
        x,y=c["at"]; w,h=c["size"]; print(f"{x},{y} {w}x{h}")')
    congelar
    geom=$(echo "$cajas" | slurp -r "${ESTILO[@]}") || { descongelar; exit 0; }
    grim -g "$geom" "$archivo"; descongelar ;;
  pantalla)
    mon=$(hyprctl monitors -j | python3 -c 'import json,sys;print(next(m["name"] for m in json.load(sys.stdin) if m["focused"]))')
    grim -o "$mon" "$archivo" ;;
esac

[ -s "$archivo" ] || exit 1
wl-copy --type image/png < "$archivo"
command -v canberra-gtk-play >/dev/null && canberra-gtk-play -i camera-shutter >/dev/null 2>&1 &

# Notificación con la imagen: clic = editar (si tienes swappy) o abrir
accion=$(notify-send -a "Captura" -i "$archivo" "Captura guardada y copiada" \
         "$(basename "$archivo")" -A "default=Editar" -A "carpeta=Abrir carpeta" --wait 2>/dev/null)
case "$accion" in
  default) if command -v swappy >/dev/null; then swappy -f "$archivo" -o "$archivo"; else xdg-open "$archivo"; fi ;;
  carpeta) xdg-open "$dir" ;;
esac
