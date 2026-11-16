#!/usr/bin/env bash
# Al encender: entra directo a Hyprland y muestra la pantalla de bloqueo (hyprlock)
# en lugar de la pantalla de inicio de sesión de siempre.
#
#   sudo bash ~/.config/hypr/scripts/bloqueo-al-iniciar.sh            -> activar
#   sudo bash ~/.config/hypr/scripts/bloqueo-al-iniciar.sh --quitar   -> volver a como estaba
#
# Detecta tu gestor de inicio (GDM, SDDM, LightDM, greetd o ninguno/TTY).
set -u
[ "$(id -u)" = 0 ] || { echo "Ejecútalo con sudo:  sudo bash $0 ${1:-}"; exit 1; }
U="${SUDO_USER:-}"
[ -n "$U" ] && [ "$U" != root ] || { echo "Ejecútalo con sudo desde tu usuario (no como root directo)."; exit 1; }
HOGAR=$(getent passwd "$U" | cut -d: -f6)
QUITAR=0; [ "${1:-}" = "--quitar" ] && QUITAR=1
ok()  { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
nota(){ printf '\033[1;33m! %s\033[0m\n' "$*"; }

# Sesión de Hyprland (de apt en /usr/share, compilado en /usr/local/share)
SES=""
for d in /usr/share/wayland-sessions /usr/local/share/wayland-sessions; do
    for f in "$d"/hyprland.desktop "$d"/Hyprland.desktop "$d"/hyprland*.desktop; do
        [ -f "$f" ] && ! grep -qi uwsm "$f" && { SES=$(basename "$f" .desktop); break 2; }
    done
done
[ -z "$SES" ] && SES=hyprland
if [ ! -f /usr/share/wayland-sessions/$SES.desktop ] && [ -f /usr/local/share/wayland-sessions/$SES.desktop ]; then
    ln -sf /usr/local/share/wayland-sessions/$SES.desktop /usr/share/wayland-sessions/$SES.desktop 2>/dev/null
fi

# Gestor de inicio activo
DM=$(basename "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null)" .service)
[ -z "$DM" ] || [ "$DM" = "display-manager" ] && DM=ninguno
echo "Usuario: $U   ·   Sesión: $SES   ·   Gestor de inicio: $DM"
F=""

case "$DM" in
gdm|gdm3)
    F=/etc/gdm3/daemon.conf; [ -f $F ] || F=/etc/gdm3/custom.conf
    [ -f $F.antes-bloqueo ] || cp $F $F.antes-bloqueo
    sed -i '/^AutomaticLoginEnable=/d; /^AutomaticLogin=/d' $F
    if [ $QUITAR = 0 ]; then
        grep -q '^\[daemon\]' $F || echo '[daemon]' >> $F
        sed -i "/^\[daemon\]/a AutomaticLoginEnable=true\nAutomaticLogin=$U" $F
        A=/var/lib/AccountsService/users/$U
        if [ -f $A ]; then sed -i '/^Session=/d; /^XSession=/d' $A; sed -i "/^\[User\]/a Session=$SES" $A
        else mkdir -p "$(dirname $A)"; printf '[User]\nSession=%s\nSystemAccount=false\n' "$SES" > $A; fi
    fi ;;
sddm)
    F=/etc/sddm.conf.d/50-bloqueo-hyprland.conf
    if [ $QUITAR = 0 ]; then mkdir -p /etc/sddm.conf.d
        printf '[Autologin]\nUser=%s\nSession=%s.desktop\nRelogin=false\n' "$U" "$SES" > $F
    else rm -f $F; fi ;;
lightdm)
    F=/etc/lightdm/lightdm.conf.d/50-bloqueo-hyprland.conf
    if [ $QUITAR = 0 ]; then mkdir -p /etc/lightdm/lightdm.conf.d
        groupadd -f autologin; gpasswd -a "$U" autologin >/dev/null
        printf '[Seat:*]\nautologin-user=%s\nautologin-session=%s\n' "$U" "$SES" > $F
    else rm -f $F; fi ;;
greetd)
    F=/etc/greetd/config.toml
    [ -f $F.antes-bloqueo ] || cp $F $F.antes-bloqueo
    if [ $QUITAR = 0 ]; then
        sed -i '/^\[initial_session\]/,/^$/d' $F
        printf '\n[initial_session]\ncommand = "Hyprland"\nuser = "%s"\n\n' "$U" >> $F
    else cp $F.antes-bloqueo $F; fi ;;
ninguno|*)
    # Sin gestor gráfico: inicio automático en la terminal 1 y arranque de Hyprland
    F=/etc/systemd/system/getty@tty1.service.d/autologin.conf
    P="$HOGAR/.bash_profile"
    if [ $QUITAR = 0 ]; then mkdir -p "$(dirname $F)"
        printf '[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin %s --noclear %%I $TERM\n' "$U" > $F
        grep -q "bloqueo-hyprland" "$P" 2>/dev/null || {
            [ -f "$P" ] || { echo '[ -f ~/.bashrc ] && . ~/.bashrc' > "$P"; chown "$U:" "$P"; }
            printf '\n# bloqueo-hyprland: abrir Hyprland al entrar en la terminal 1\nif [ -z "${WAYLAND_DISPLAY:-}" ] && [ "$(tty)" = /dev/tty1 ]; then exec Hyprland; fi\n' >> "$P"; }
    else rm -f $F; sed -i '/bloqueo-hyprland/,+1d' "$P" 2>/dev/null; fi
    systemctl daemon-reload ;;
esac

if [ $QUITAR = 0 ]; then
    sed -i 's/^# exec-once = hyprlock$/exec-once = hyprlock/' "$HOGAR/.config/hypr/hyprland.conf"
    ok "Listo. Al encender entrarás directo a la pantalla de bloqueo de Hyprland."
    echo "  Cambia la imagen con Windows + Alt + L.  Para deshacerlo:  sudo bash $0 --quitar"
    nota "Si Chrome o VS Code te piden la contraseña del 'llavero', es normal con el inicio automático."
else
    ok "Restaurado: volverás a ver tu pantalla de inicio de sesión normal."
    sed -i 's/^exec-once = hyprlock$/# exec-once = hyprlock/' "$HOGAR/.config/hypr/hyprland.conf"
    nota "También desactivé el bloqueo al iniciar en hyprland.conf (para no pedirte la contraseña dos veces)."
fi
[ -n "$F" ] && echo "  Archivo modificado: $F"
