#!/usr/bin/env bash
# Estado de la laptop con barras horizontales (para el widget)
python3 - <<'PY'
import os, glob, shutil, time, json

COLOR = {"CPU": "#7fd6ff", "RAM": "#b9a2ff", "TEMP": "#ffb27a", "DISCO": "#7ff0c8", "BAT": "#a6f0b4"}

def barra(p, nombre, n=19, bateria=False):
    p = max(0, min(100, p))
    llenas = round(p / 100 * n)
    color = COLOR[nombre]
    if bateria:
        if p <= 20: color = "#ff7a8a"
    elif p >= 85:
        color = "#ff7a8a"
    elif p >= 70:
        color = "#ffd27a"
    return (f"<span size='155%' rise='-2048' color='{color}'>{'━' * llenas}</span>"
            f"<span size='155%' rise='-2048' color='#ffffff' alpha='18%'>{'━' * (n - llenas)}</span>")

def cpu():
    cache = "/tmp/.widget-cpu"
    a = list(map(int, open("/proc/stat").readline().split()[1:]))
    total, idle = sum(a), a[3] + a[4]
    try:
        t0, i0 = map(int, open(cache).read().split())
    except Exception:
        time.sleep(0.3)
        b = list(map(int, open("/proc/stat").readline().split()[1:]))
        t0, i0 = total, idle
        total, idle = sum(b), b[3] + b[4]
    open(cache, "w").write(f"{total} {idle}")
    dt = total - t0
    return 0 if dt <= 0 else round(100 * (1 - (idle - i0) / dt))

def ram():
    m = {l.split(":")[0]: int(l.split()[1]) for l in open("/proc/meminfo")}
    return round(100 * (1 - m["MemAvailable"] / m["MemTotal"]))

def temp():
    mejor = None
    for h in glob.glob("/sys/class/hwmon/hwmon*"):
        try:
            nombre = open(f"{h}/name").read().strip()
        except Exception:
            continue
        if nombre in ("k10temp", "coretemp", "zenpower", "cpu_thermal", "acpitz"):
            for f in sorted(glob.glob(f"{h}/temp*_input")):
                v = int(open(f).read()) / 1000
                if nombre != "acpitz" or mejor is None:
                    mejor = v
                break
            if nombre != "acpitz":
                break
    return round(mejor) if mejor is not None else 0

def disco():
    d = shutil.disk_usage("/")
    return round(100 * d.used / d.total)

def bateria():
    for b in glob.glob("/sys/class/power_supply/BAT*"):
        try:
            cap = int(open(f"{b}/capacity").read())
            est = open(f"{b}/status").read().strip()
            return cap, est
        except Exception:
            pass
    return None, None

c, r, t, d = cpu(), ram(), temp(), disco()
bc, be = bateria()
filas = [("CPU",  barra(c, "CPU"), f"{c:>3}%"),
         ("RAM",  barra(r, "RAM"), f"{r:>3}%"),
         ("TEMP", barra(t, "TEMP"), f"{t:>3}°"),
         ("DISCO", barra(d, "DISCO"), f"{d:>3}%")]
if bc is not None:
    rayo = " ⚡" if be in ("Charging", "Full") else ""
    filas.append(("BAT", barra(bc, "BAT", bateria=True), f"{bc:>3}%{rayo}"))
texto = "\n".join(f"<span alpha='80%' weight='bold'>{n:<6}</span>{b} <b>{v}</b>" for n, b, v in filas)

# ---------- Tiempo sin cargador y cuánto se ha descargado ----------
def dur(seg):
    seg = int(max(0, seg)); h, m = seg // 3600, (seg % 3600) // 60
    return f"{h} h {m:02d} min" if h else f"{m} min"

def historial_upower():
    """Hora y % del último momento en que se desconectó el cargador, según UPower."""
    archivos = sorted(glob.glob("/var/lib/upower/history-charge-*.dat"), key=os.path.getmtime)
    if not archivos:
        return None
    try:
        filas = [l.split("\t") for l in open(archivos[-1]).read().splitlines() if l.count("\t") >= 2]
    except Exception:
        return None
    filas = [(float(t), float(p), e.strip()) for t, p, e in filas if t.replace(".", "").isdigit()]
    if not filas or filas[-1][2] != "discharging":
        return None
    i = len(filas) - 1
    while i > 0 and filas[i - 1][2] == "discharging":
        i -= 1
    return filas[i][0], filas[i][1]

def tiempo_sin_cargador():
    ac = None
    for p in glob.glob("/sys/class/power_supply/*"):
        try:
            if open(f"{p}/type").read().strip() == "Mains":
                ac = open(f"{p}/online").read().strip() == "1"
                break
        except Exception:
            pass
    bats = glob.glob("/sys/class/power_supply/BAT*")
    if ac is None or not bats:
        return None
    try:
        pct = int(open(f"{bats[0]}/capacity").read())
    except Exception:
        return None
    ahora = time.time()
    arranque = ahora - float(open("/proc/uptime").read().split()[0])
    reg = os.path.expanduser("~/.cache/widget-cargador")
    try:
        estado, desde, pct0 = open(reg).read().split()
        desde, pct0 = float(desde), float(pct0)
    except Exception:
        estado, desde, pct0 = "", 0.0, 0.0

    if ac:
        if estado != "ac":
            open(reg, "w").write(f"ac {ahora} {pct}")
        return f"<span alpha='70%' weight='bold'>CARGADOR</span>  <b>conectado ⚡</b>"

    if estado == "ac":
        # lo vimos conectado y ahora no: se acaba de desconectar
        desde, pct0 = ahora, pct
        open(reg, "w").write(f"bat {desde} {pct0}")
    elif estado != "bat" or desde < arranque - 60:
        # no sabemos cuándo se desconectó: lo sacamos del historial del sistema
        h = historial_upower()
        if h:
            desde, pct0 = h
            open(reg, "w").write(f"bat {desde} {pct0}")
        else:
            return "<span alpha='70%' weight='bold'>SIN CARGADOR</span>  <b>contando desde ahora…</b>"
            # (la próxima vez que desconectes el cargador se medirá exacto)
    gastado = max(0, round(pct0 - pct))
    return (f"<span alpha='70%' weight='bold'>SIN CARGADOR</span>  <b>{dur(ahora - desde)}</b>"
            f"  <span alpha='75%'>· −{gastado}%  ({round(pct0)}% → {pct}%)</span>")

linea = tiempo_sin_cargador()
if linea:
    texto += f"\n<span size='88%'>{linea}</span>"
print(json.dumps({"text": texto, "tooltip": "Clic: abrir monitor del sistema"}, ensure_ascii=False))
PY
