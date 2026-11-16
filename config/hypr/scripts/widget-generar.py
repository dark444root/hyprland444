#!/usr/bin/env python3
"""
Genera los widgets de escritorio (uno por monitor):
  · Reloj gigante difuminado, arriba al centro
  · Abajo a la izquierda: foto redonda, estado del sistema (CPU, RAM, temp, disco)
    y tus apps en blanco y negro (lista en ~/.config/hypr/widget/apps.txt)
Lo llama widget.sh; no hace falta ejecutarlo a mano.
"""
import json, os, re, glob, subprocess, configparser

W = os.path.expanduser("~/.config/hypr/widget")
S = os.path.expanduser("~/.config/hypr/scripts")
APPS_TXT = f"{W}/apps.txt"
COLS, CELDA = 4, 94          # columnas del panel de apps y tamaño de cada celda
M = 28                       # margen desde los bordes de la pantalla
ARRIBA = 48                  # debajo de la barra de menú

DIRS_DESKTOP = ["/usr/share/applications", os.path.expanduser("~/.local/share/applications"),
                "/var/lib/flatpak/exports/share/applications",
                os.path.expanduser("~/.local/share/flatpak/exports/share/applications"),
                "/var/lib/snapd/desktop/applications"]
SUGERIDAS = ["google-chrome", "firefox-esr", "firefox", "brave-browser", "kitty", "thunar",
             "org.gnome.Nautilus", "code", "spotify", "discord", "steam", "obs", "com.obsproject.Studio",
             "libreoffice-writer", "postman", "android-studio", "virtualbox", "burpsuite",
             "mongodb-compass", "vlc", "telegram-desktop", "org.telegram.desktop"]

def buscar_desktop(nombre):
    for d in DIRS_DESKTOP:
        for cand in (f"{d}/{nombre}.desktop", f"{d}/{nombre}"):
            if os.path.isfile(cand):
                return cand
    for d in DIRS_DESKTOP:   # búsqueda aproximada
        for f in glob.glob(f"{d}/*.desktop"):
            if nombre.lower() in os.path.basename(f).lower():
                return f
    return None

def leer_desktop(ruta):
    c = configparser.ConfigParser(interpolation=None, strict=False)
    try:
        c.read(ruta, encoding="utf-8")
        e = c["Desktop Entry"]
    except Exception:
        return None
    nombre = e.get("Name[es]") or e.get("Name") or os.path.basename(ruta)
    exe = re.sub(r"\s*%[fFuUdDnNickvm]", "", e.get("Exec", "")).strip()
    return {"nombre": nombre, "exec": exe, "icono": e.get("Icon", "")}

def buscar_icono(icono):
    if not icono:
        return None
    if os.path.isabs(icono) and os.path.isfile(icono):
        return icono
    temas = ["Papirus-Dark", "Papirus", "hicolor", "Adwaita"]
    for t in temas:
        for tam in ("64x64", "48x48", "128x128", "scalable", "256x256", "96x96"):
            for ext in ("svg", "png"):
                p = f"/usr/share/icons/{t}/{tam}/apps/{icono}.{ext}"
                if os.path.isfile(p):
                    return p
    for ext in ("svg", "png", "xpm"):
        p = f"/usr/share/pixmaps/{icono}.{ext}"
        if os.path.isfile(p):
            return p
    for p in glob.glob(f"/var/lib/flatpak/exports/share/icons/hicolor/*/apps/{icono}.*") + \
             glob.glob(os.path.expanduser(f"~/.local/share/icons/hicolor/*/apps/{icono}.*")):
        return p
    return None

# ---------- Lista de apps ----------
if not os.path.isfile(APPS_TXT):
    elegidas = [n for n in SUGERIDAS if buscar_desktop(n)][:8]
    with open(APPS_TXT, "w") as f:
        f.write("# Apps del panel del escritorio (una por línea, nombre del .desktop o parte de él)\n")
        f.write("# Después de editar: Windows + Alt + W dos veces\n")
        f.write("\n".join(elegidas) + "\n")

def cargar_lista(txt):
    res = []
    num_linea = -1
    for linea in open(txt, encoding="utf-8"):
        n = linea.strip()
        if not n or n.startswith("#"):
            continue
        num_linea += 1
        d = buscar_desktop(n)
        info = leer_desktop(d) if d else None
        if info and info["exec"]:
            info["linea"] = num_linea
            info["ruta_icono"] = buscar_icono(info["icono"]) or buscar_icono("application-x-executable")
            if info["ruta_icono"]:
                res.append(info)
    return res

apps = cargar_lista(APPS_TXT)

# ---------- Lista de juegos ----------
JUEGOS_TXT = f"{W}/juegos.txt"
if not os.path.isfile(JUEGOS_TXT):
    detectados = []
    for dd in DIRS_DESKTOP:
        for f in sorted(glob.glob(f"{dd}/*.desktop")):
            try:
                t = open(f, encoding="utf-8", errors="ignore").read()
            except Exception:
                continue
            if ("Categories=" in t and "Game" in t.split("Categories=")[1].split("\n")[0]) or "steam://rungameid" in t:
                if "NoDisplay=true" not in t:
                    detectados.append(os.path.basename(f)[:-8])
    with open(JUEGOS_TXT, "w") as f:
        f.write("# Juegos del widget (se muestran los primeros 4)\n")
        f.write("# Cámbialos con clic derecho en un icono, o Windows + Alt + J para elegir los 4\n")
        f.write("\n".join(dict.fromkeys(detectados)) + "\n")
juegos = cargar_lista(JUEGOS_TXT)

import base64
BN = f"{W}/iconos-bn"
def icono_bn(ruta, clave):
    """Copia del icono en blanco y negro (filtro SVG), sin depender de programas extra."""
    os.makedirs(BN, exist_ok=True)
    dest = f"{BN}/{clave}.svg"
    if os.path.isfile(dest) and os.path.getmtime(dest) >= os.path.getmtime(ruta):
        return dest
    filtro = ('<defs><filter id="bn" color-interpolation-filters="sRGB">'
              '<feColorMatrix type="saturate" values="0"/>'
              '<feComponentTransfer><feFuncR type="linear" slope="1.25"/><feFuncG type="linear" slope="1.25"/>'
              '<feFuncB type="linear" slope="1.25"/></feComponentTransfer></filter></defs>')
    try:
        if ruta.endswith(".svg"):
            txt = open(ruta, encoding="utf-8", errors="ignore").read()
            ini = re.search(r"<svg[^>]*>", txt)
            fin = txt.rfind("</svg>")
            if not ini or fin < 0:
                return ruta
            txt = txt[:ini.end()] + filtro + '<g filter="url(#bn)">' + txt[ini.end():fin] + "</g>" + txt[fin:]
        else:
            tipo = "png" if ruta.endswith(".png") else "x-xpixmap"
            datos = base64.b64encode(open(ruta, "rb").read()).decode()
            txt = ('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
                   'width="64" height="64" viewBox="0 0 64 64">' + filtro +
                   f'<image filter="url(#bn)" width="64" height="64" xlink:href="data:image/{tipo};base64,{datos}"/></svg>')
        open(dest, "w", encoding="utf-8").write(txt)
        return dest
    except Exception:
        return ruta

def panel(nombre, x, y, w, h, out, mods, extra):
    b = {"name": nombre, "output": out, "layer": "bottom", "position": "top",
         "exclusive": False, "passthrough": False, "height": h,
         "margin-top": y, "margin-left": x, "margin-right": 0, "spacing": 0}
    b.update(mods); b.update(extra)
    b["_w"] = w
    return b

S_ = S
cl = f"bash {S_}/clima.sh"
# Fecha en español sin depender del idioma del sistema
FECHA_ES = ("python3 -c \"import datetime as d;n=d.date.today();"
            "print(['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'][n.weekday()],n.day,'de',"
            "['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'][n.month-1])\"")
BAT = ["▱▱▱▱▱▱▱▱▱▱", "▰▱▱▱▱▱▱▱▱▱", "▰▰▱▱▱▱▱▱▱▱", "▰▰▰▱▱▱▱▱▱▱", "▰▰▰▰▱▱▱▱▱▱", "▰▰▰▰▰▱▱▱▱▱",
       "▰▰▰▰▰▰▱▱▱▱", "▰▰▰▰▰▰▰▱▱▱", "▰▰▰▰▰▰▰▰▱▱", "▰▰▰▰▰▰▰▰▰▱", "▰▰▰▰▰▰▰▰▰▰"]

barras = []
monitores = json.loads(subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True).stdout or "[]")
for m in monitores:
    w, h = m["width"], m["height"]
    if m.get("transform", 0) in (1, 3, 5, 7):
        w, h = h, w
    AW, AH = int(w / m.get("scale", 1)), int(h / m.get("scale", 1))
    LIM = AH - 92                       # no invadir el dock
    out = m["name"]
    mios = []

    # ================= Columna abajo a la izquierda =================
    CW = 500                                   # ancho de la columna
    ML = M + 40                                # +1 cm a la izquierda
    LIM = LIM - 40                             # +1 cm abajo
    filas = [apps[:4]] if apps else []          # solo 4 apps, en una fila
    ALTO_FILA = 118
    HF = ALTO_FILA + 16                        # alto de un panel de iconos
    y_cur = LIM
    y_juegos = None
    if juegos:                                  # juegos hasta abajo
        y_juegos = y_cur - HF
        y_cur = y_juegos - 14
    y_apps = y_cur
    if filas:                                   # apps encima de los juegos
        y_apps = y_cur - HF
        y_cur = y_apps - 16
    ALTO_SIS = 238
    y_sis = y_cur - ALTO_SIS
    tam = 258 if juegos else 320
    y_foto = y_sis - 16 - tam

    # Foto redonda
    mios.append(panel("foto-grande", ML, y_foto, CW, tam + 10, out,
        {"modules-center": ["custom/foto"]},
        {"custom/foto": {"format": " ", "tooltip-format": "Clic: cambiar foto",
                         "on-click": f"bash {S_}/widget-foto.sh foto"}}))

    # Estado de la laptop con barras horizontales
    mios.append(panel("sistema", ML, y_sis, CW, ALTO_SIS, out,
        {"modules-left": ["custom/sistema"]},
        {"custom/sistema": {"exec": f"bash {S_}/sistema.sh", "return-type": "json", "interval": 3, "tooltip": False,
                            "on-click": "kitty -e btop"}}))

    # Paneles de apps y juegos en blanco y negro (una fila de 4 cada uno)
    def panel_iconos(lista, tipo, x, y):
        if not lista:
            return
        mods, extra = [], {}
        for j, a in enumerate(lista[:4]):
            k = f"{tipo}{j}"
            cmd = "hyprctl dispatch exec " + json.dumps(a["exec"])
            mods.append(f"image#{k}")
            extra[f"image#{k}"] = {"path": icono_bn(a["ruta_icono"], re.sub(r"\W", "_", a["nombre"])),
                                   "size": 74, "on-click": cmd,
                                   "on-click-right": f"python3 {S_}/elegir-app.py {tipo} {a['linea']}",
                                   "tooltip": True, "tooltip-format": a["nombre"]}
        mios.append(panel("apps-sola", x, y, CW, HF, out, {"modules-center": mods}, extra))

    panel_iconos(apps, "apps", ML, y_apps)
    panel_iconos(juegos, "juegos", ML, y_juegos)

    # (El Centro de Control del escritorio lo dibuja centro-control.py escritorio)

    # ================= Reloj gigante (arriba al centro) =================
    cw = min(780, AW - 2 * M)
    xc = (AW - cw) // 2
    arriba_col = y_foto if y_foto >= ARRIBA - 4 else y_sis
    if xc < ML + CW + 24 and arriba_col < ARRIBA + 270 + 10:
        xc = ML + CW + 24                       # recorre el reloj a la derecha de la columna
        cw = min(cw, AW - M - xc)
    choca = cw < 420
    if cw >= 420 and not choca and AH >= 800:      # en pantallas chicas va el Centro de Control
        mios.append(panel("reloj-gigante", xc, ARRIBA, cw, 270, out,
            {"modules-center": ["group/gigante"]},
            {"group/gigante": {"orientation": "vertical", "modules": ["clock#gig", "custom/fechag"]},
             "clock#gig": {"format": "{:%H:%M}", "interval": 10, "tooltip": False},
             "custom/fechag": {"exec": FECHA_ES, "interval": 60, "tooltip": False}}))

    # Quitar lo que no quepa (pantallas pequeñas) y calcular márgenes
    for b in mios:
        if b["margin-left"] + b["_w"] > AW - 4 or b["margin-top"] + b["height"] > LIM or b["margin-top"] < ARRIBA - 4:
            continue
        b["margin-right"] = max(0, AW - b["margin-left"] - b.pop("_w"))
        barras.append(b)

json.dump(barras, open(f"{W}/config.jsonc", "w"), indent=1, ensure_ascii=False)

css = open(f"{W}/style.plantilla.css").read()
for f in ("foto", "foto2", "foto3"):
    css = css.replace(f"__{f.upper()}__", f"file://{W}/{f}")
open(f"{W}/style.css", "w").write(css)
