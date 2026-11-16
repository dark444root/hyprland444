#!/usr/bin/env bash
# Muestra en Waybar cuántas y cuáles ventanas están minimizadas
tema=$(cat ~/.config/hypr/tema-actual 2>/dev/null)
hyprctl clients -j | TEMA="$tema" python3 -c '
import os
import json,sys
ws=[w for w in json.load(sys.stdin) if w["workspace"]["name"]=="special:minimizadas"]
ic=""
if not ws:
    print(json.dumps({"text":ic+"  0","class":"vacio","tooltip":"No hay ventanas minimizadas"}))
else:
    nombres=[w["class"] for w in ws]
    corto=", ".join(nombres[:3])+("…" if len(nombres)>3 else "")
    tip="Minimizadas:\n"+"\n".join("• "+w["class"]+" — "+w["title"][:45] for w in ws)+"\n\nClic: elegir cuál abrir · Clic derecho: abrir todas"
    print(json.dumps({"text":ic+"  "+str(len(ws))+"  "+corto,"class":"hay","tooltip":tip}))
'
