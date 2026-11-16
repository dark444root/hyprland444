#!/usr/bin/env bash
# Datos del clima para los widgets (una consulta cada 30 min, en caché)
#   clima.sh ciudad | temp | cielo | rango | pronostico
C="${XDG_CACHE_HOME:-$HOME/.cache}/widget-clima.json"
if [ ! -s "$C" ] || [ $(( $(date +%s) - $(stat -c %Y "$C") )) -gt 1700 ]; then
    curl -sf --max-time 8 'https://wttr.in/?format=j1&lang=es' -o "$C.tmp" && mv "$C.tmp" "$C"
fi
python3 - "$1" "$C" <<'PY'
import json, sys, datetime
campo, ruta = sys.argv[1], sys.argv[2]
def icono(cod):
    cod = int(cod)
    return ("☀️" if cod == 113 else "⛅" if cod == 116 else "☁️" if cod in (119, 122)
            else "🌫️" if cod in (143, 248, 260) else "⛈️" if cod in (200, 386, 389, 392, 395)
            else "❄️" if cod in (179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371) else "🌧️")
DIAS = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]
try:
    d = json.load(open(ruta))
    cc = d["current_condition"][0]; hoy = d["weather"][0]
    ciudad = d["nearest_area"][0]["areaName"][0]["value"]
    desc = (cc.get("lang_es") or cc["weatherDesc"])[0]["value"].strip().capitalize()
    if campo == "pronostico":
        lineas = [f"<b>{ciudad}</b>",
                  f"<span size='300%' weight='light'>{cc['temp_C']}°</span>   {icono(cc['weatherCode'])}",
                  f"{desc}", ""]
        for w in d["weather"][:3]:
            dia = DIAS[datetime.date.fromisoformat(w["date"]).weekday()]
            cod = w["hourly"][4]["weatherCode"] if len(w.get("hourly", [])) > 4 else cc["weatherCode"]
            lineas.append(f"{dia}    {icono(cod)}    {w['mintempC']}°  <b>{w['maxtempC']}°</b>")
        print("\n".join(lineas))
    else:
        print({"ciudad": ciudad, "temp": f'{cc["temp_C"]}°', "cielo": f"{icono(cc['weatherCode'])}  {desc}",
               "rango": f'Máx {hoy["maxtempC"]}°  Mín {hoy["mintempC"]}°'}.get(campo, ""))
except Exception:
    print({"pronostico": "Clima\n\nSin conexión", "ciudad": "Clima", "temp": "--°",
           "cielo": "Sin conexión", "rango": ""}.get(campo, ""))
PY
