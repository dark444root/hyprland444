#!/usr/bin/env python3
"""
Fondos y apps por escritorio · escucha los eventos de Hyprland:
  - cambia el fondo según ~/.config/hypr/fondos/escritorios.conf
  - manda cada app a su escritorio según ~/.config/hypr/apps-escritorios.conf
Fondos por escritorio · cambia el fondo
según ~/.config/hypr/fondos/escritorios.conf  (líneas:  3=/ruta/al/fondo.jpg)
Escritorios sin fondo asignado usan el fondo del tema activo.
Ligero: no hace nada si el fondo no cambia; recarga la config con SIGUSR1.
"""
import os, socket, subprocess, signal, shutil, time, json, threading

HYPR = os.path.expanduser("~/.config/hypr")
MAPA = f"{HYPR}/fondos/escritorios.conf"
TEMA = f"{HYPR}/wallpapers/actual.png"
APPS = f"{HYPR}/apps-escritorios.conf"

sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
run = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
SOCK = next((p for p in (f"{run}/hypr/{sig}/.socket2.sock", f"/tmp/hypr/{sig}/.socket2.sock")
             if os.path.exists(p)), None)

USA_SWWW = shutil.which("swww") is not None
mapa, actual, ultimo_ws, swaybg = {}, None, 1, None
reglas_apps = []   # [(texto_en_minúsculas, escritorio)]
recargar = threading.Event()


def cargar_mapa():
    global mapa
    mapa = {}
    try:
        for linea in open(MAPA, encoding="utf-8"):
            linea = linea.strip()
            if "=" in linea and not linea.startswith("#"):
                ws, ruta = linea.split("=", 1)
                ruta = os.path.expanduser(ruta.strip())
                if os.path.isfile(ruta):
                    mapa[ws.strip()] = ruta
    except FileNotFoundError:
        pass


def cargar_apps():
    global reglas_apps
    reglas_apps = []
    try:
        for linea in open(APPS, encoding="utf-8"):
            linea = linea.split("#", 1)[0].strip()
            if "=" in linea:
                apps, ws = linea.rsplit("=", 1)
                for a in apps.split(","):
                    if a.strip():
                        reglas_apps.append((a.strip().lower(), ws.strip()))
    except FileNotFoundError:
        pass


def ubicar_app(addr, ws_actual, clase):
    clase = clase.lower()
    for texto, destino in reglas_apps:
        if texto in clase:
            if destino != ws_actual:
                # mueve la ventana y te lleva a ese escritorio
                subprocess.run(["hyprctl", "dispatch", "movetoworkspace",
                                f"{destino},address:0x{addr}"], capture_output=True)
            return


def iniciar_swww():
    if subprocess.run(["swww", "query"], capture_output=True).returncode == 0:
        return
    if shutil.which("swww-daemon"):
        subprocess.Popen(["swww-daemon"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
    else:
        subprocess.run(["swww", "init"], capture_output=True)
    for _ in range(50):
        if subprocess.run(["swww", "query"], capture_output=True).returncode == 0:
            return
        time.sleep(0.1)


def poner(ruta, hacia_adelante=True, forzar=False):
    global actual, swaybg
    try:
        clave = (ruta, os.path.getmtime(ruta))   # si reemplazas la imagen, se detecta
    except OSError:
        clave = (ruta, 0)
    if not forzar and clave == actual:
        return                                   # mismo fondo: no gastar nada
    actual = clave
    if USA_SWWW:
        subprocess.Popen(["swww", "img", ruta,
                          "--transition-type", "wipe",
                          "--transition-angle", "30" if hacia_adelante else "210",
                          "--transition-step", "90", "--transition-fps", "60",
                          "--transition-duration", "0.6"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        nuevo = subprocess.Popen(["swaybg", "-i", ruta, "-m", "fill"],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(0.25)                         # evita parpadeo negro
        if swaybg:
            swaybg.terminate()
        swaybg = nuevo


def fondo_de(ws):
    return mapa.get(str(ws), TEMA)


def aplicar(ws, forzar=False):
    global ultimo_ws
    try:
        adelante = int(ws) >= int(ultimo_ws)
    except ValueError:
        adelante = True
    ultimo_ws = ws
    subprocess.run(["pkill", "-RTMIN+9", "waybar"], capture_output=True)  # "Escritorio N"
    poner(fondo_de(ws), adelante, forzar)


def ws_activo():
    try:
        out = subprocess.run(["hyprctl", "activeworkspace", "-j"], capture_output=True, text=True).stdout
        return str(json.loads(out)["id"])
    except Exception:
        return "1"


def avisar_waybar():
    subprocess.run(["pkill", "-RTMIN+8", "waybar"], capture_output=True)


def main():
    if USA_SWWW:
        iniciar_swww()
    else:
        subprocess.run(["pkill", "-x", "swaybg"], capture_output=True)
    cargar_mapa()
    cargar_apps()
    aplicar(ws_activo(), forzar=True)

    signal.signal(signal.SIGUSR1, lambda *_: recargar.set())

    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(SOCK)
    s.settimeout(1.0)
    buf = b""
    pendiente_waybar = 0.0
    while True:
        if recargar.is_set():
            recargar.clear()
            cargar_mapa()
            cargar_apps()
            aplicar(ws_activo(), forzar=True)
        if pendiente_waybar and time.time() >= pendiente_waybar:
            pendiente_waybar = 0.0
            avisar_waybar()
        try:
            datos = s.recv(4096)
            if not datos:
                break                            # Hyprland se cerró
            buf += datos
        except socket.timeout:
            continue
        except InterruptedError:
            continue
        *lineas, buf = buf.split(b"\n")
        for l in lineas:
            ev, _, val = l.decode(errors="ignore").partition(">>")
            if ev == "workspacev2":
                aplicar(val.split(",", 1)[0])
            elif ev == "openwindow":
                partes = val.split(",", 3)
                if len(partes) >= 3 and not partes[1].startswith("special"):
                    ubicar_app(partes[0], partes[1], partes[2])
                pendiente_waybar = time.time() + 0.3
            elif ev in ("closewindow", "movewindowv2"):
                pendiente_waybar = time.time() + 0.3   # agrupa ráfagas de eventos


if __name__ == "__main__":
    if not SOCK:
        raise SystemExit("No encontré el socket de Hyprland")
    main()
