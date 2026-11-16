#!/usr/bin/env python3
"""
Galería para elegir una imagen: cuadrícula de miniaturas grandes + carpetas.
Uso: galeria.py [carpeta_inicial]   -> imprime la ruta elegida (o nada si se cancela)
"""
import os, sys, hashlib, subprocess, urllib.parse

EXT = (".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp")
TEMA = os.path.expanduser("~/.config/hypr/widget/galeria.rasi")
CACHE = os.path.expanduser("~/.cache/thumbnails")

def miniatura(ruta):
    """Usa la miniatura que ya generó el gestor de archivos (mucho más rápido)."""
    uri = "file://" + urllib.parse.quote(os.path.abspath(ruta))
    h = hashlib.md5(uri.encode()).hexdigest()
    for tam in ("x-large", "large", "normal"):
        p = f"{CACHE}/{tam}/{h}.png"
        if os.path.isfile(p):
            return p
    return ruta

def listar(d):
    carpetas, imagenes = [], []
    try:
        for n in sorted(os.listdir(d), key=str.lower):
            if n.startswith("."):
                continue
            p = os.path.join(d, n)
            if os.path.isdir(p):
                carpetas.append(p)
            elif n.lower().endswith(EXT):
                imagenes.append(p)
    except PermissionError:
        pass
    return carpetas, imagenes

d = os.path.abspath(os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/Imágenes"))
if not os.path.isdir(d):
    d = os.path.expanduser("~")
LUGARES = [("Inicio", "~"), ("Imágenes", "~/Imágenes"), ("Descargas", "~/Descargas"),
           ("Escritorio", "~/Escritorio"), ("Fondos", "~/.config/hypr/fondos"), ("Wallpapers", "~/Wallpapers")]

while True:
    carpetas, imagenes = listar(d)
    items, filas = [], []
    # Subir
    if d != "/":
        items.append(("dir", os.path.dirname(d)))
        filas.append("⬆  Subir\0icon\x1fgo-up")
    # Carpetas
    for c in carpetas:
        items.append(("dir", c))
        filas.append(f"{os.path.basename(c)}\0icon\x1ffolder")
    # Imágenes
    for i in imagenes:
        items.append(("img", i))
        filas.append(f"{os.path.basename(i)}\0icon\x1f{miniatura(i)}")
    # Lugares rápidos al final
    for nombre, ruta in LUGARES:
        r = os.path.expanduser(ruta)
        if os.path.isdir(r) and r != d:
            items.append(("dir", r))
            filas.append(f"★ {nombre}\0icon\x1fuser-bookmarks")

    titulo = d.replace(os.path.expanduser("~"), "~", 1)
    res = subprocess.run(["rofi", "-dmenu", "-show-icons", "-i", "-format", "i",
                          "-p", f"{titulo}   ({len(imagenes)} imágenes)", "-theme", TEMA],
                         input="\n".join(filas), capture_output=True, text=True)
    sel = res.stdout.strip()
    if res.returncode != 0 or not sel.isdigit():
        sys.exit(0)
    tipo, ruta = items[int(sel)]
    if tipo == "dir":
        d = ruta
        continue
    print(ruta)
    break
