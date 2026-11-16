#!/usr/bin/env python3
"""
Elige con el mouse las apps o juegos del widget.
  elegir-app.py [apps|juegos] [0..3|todas]
     apps 2      -> cambia solo la posición 3 del panel de apps (clic derecho en el icono)
     juegos todas-> eliges los 4 juegos uno tras otro (Windows + Alt + J)
"""
import os, sys, glob, subprocess, configparser

W = os.path.expanduser("~/.config/hypr/widget")
TEMA = f"{W}/apps-picker.rasi"
DIRS = ["/usr/share/applications", os.path.expanduser("~/.local/share/applications"),
        "/var/lib/flatpak/exports/share/applications",
        os.path.expanduser("~/.local/share/flatpak/exports/share/applications"),
        "/var/lib/snapd/desktop/applications"]

args = sys.argv[1:]
lista_nombre = args.pop(0) if args and args[0] in ("apps", "juegos") else "apps"
modo = args[0] if args else "todas"
TXT = f"{W}/{lista_nombre}.txt"

def es_juego(e):
    cats = e.get("Categories", "")
    exe = e.get("Exec", "")
    return ("Game" in cats.split(";") or "steam://rungameid" in exe or "heroic://" in exe
            or "lutris:rungame" in exe or "minecraft" in exe.lower())

def instaladas(solo_juegos):
    vistas, apps = set(), []
    for d in DIRS:
        for f in glob.glob(f"{d}/*.desktop"):
            clave = os.path.basename(f)[:-8]
            if clave in vistas:
                continue
            c = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                c.read(f, encoding="utf-8"); e = c["Desktop Entry"]
            except Exception:
                continue
            if e.get("NoDisplay", "false").lower() == "true" or e.get("Type", "Application") != "Application":
                continue
            if solo_juegos and not es_juego(e):
                continue
            vistas.add(clave)
            apps.append((e.get("Name[es]") or e.get("Name") or clave, e.get("Icon", "application-x-executable"), clave))
    return sorted(apps, key=lambda a: a[0].lower())

def leer():
    try:
        return [l.strip() for l in open(TXT, encoding="utf-8") if l.strip() and not l.startswith("#")]
    except FileNotFoundError:
        return []

def guardar(lista):
    with open(TXT, "w", encoding="utf-8") as f:
        f.write(f"# {lista_nombre.capitalize()} del widget (se muestran los primeros 4)\n")
        f.write("# Cámbialos con clic derecho en un icono\n")
        f.write("\n".join(lista) + "\n")

def elegir(titulo, opciones, extra=None):
    filas = [f"{n}\0icon\x1f{i}" for n, i, _ in opciones]
    if extra:
        filas.append(f"{extra}\0icon\x1fview-more")
    r = subprocess.run(["rofi", "-dmenu", "-show-icons", "-i", "-format", "i", "-p", titulo, "-theme", TEMA],
                       input="\n".join(filas), capture_output=True, text=True)
    s = r.stdout.strip()
    if r.returncode != 0 or not s.isdigit():
        return None
    k = int(s)
    return "__mas__" if k >= len(opciones) else opciones[k][2]

subprocess.run(["pkill", "-x", "rofi"])
juegos = instaladas(True) if lista_nombre == "juegos" else []
todas = instaladas(False)
lista = leer()
while len(lista) < 4:
    lista.append("")

posiciones = range(4) if modo == "todas" else [int(modo)]
cambio = False
for p in posiciones:
    titulo = f"{'Juego' if lista_nombre == 'juegos' else 'App'} {p + 1} de 4"
    if juegos:
        nueva = elegir(titulo, juegos, "Ver todas las apps…")
        if nueva == "__mas__":
            nueva = elegir(titulo, todas)
    else:
        nueva = elegir(titulo, todas)
    if nueva is None:
        break
    lista[p] = nueva
    cambio = True

if cambio:
    guardar([a for a in lista if a])
    subprocess.Popen(["bash", os.path.expanduser("~/.config/hypr/scripts/widget.sh")],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    subprocess.run(["notify-send", "-a", "Widget", f"{lista_nombre.capitalize()} actualizados"])
