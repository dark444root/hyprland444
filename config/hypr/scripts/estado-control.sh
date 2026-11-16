#!/usr/bin/env bash
# Estado de Wi-Fi o Bluetooth para el widget (solo icono; el detalle va en el tooltip)
#   estado-control.sh wifi | bt
python3 - "$1" <<'PY'
import json, subprocess, sys
def sh(c):
    import os
    return subprocess.run(c, shell=True, capture_output=True, text=True,
                          env=dict(os.environ, LC_ALL="C.UTF-8", LANG="C.UTF-8")).stdout.strip()
if sys.argv[1] == "wifi":
    on = sh("nmcli -t -f WIFI g") == "enabled"
    red = sh("nmcli -t -f IN-USE,SSID dev wifi list --rescan no | grep '^\\*:' | head -1 | cut -d: -f2-") if on else ""
    tip = f"Wi-Fi: {red}" if red else ("Wi-Fi encendido" if on else "Wi-Fi apagado")
    ic = ""
else:
    on = "Powered: yes" in sh("bluetoothctl show")
    con = sh("bluetoothctl devices Connected 2>/dev/null") if on else ""
    dev = con.splitlines()[0].split(" ", 2)[2] if con else ""
    tip = f"Bluetooth: {dev}" if dev else ("Bluetooth encendido" if on else "Bluetooth apagado")
    ic = ""
print(json.dumps({"text": ic, "class": "on" if on else "off",
                  "tooltip": tip + "\nClic: opciones · Clic derecho: encender/apagar"}, ensure_ascii=False))
PY
