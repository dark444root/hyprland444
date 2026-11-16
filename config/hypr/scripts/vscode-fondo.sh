#!/usr/bin/env bash
# Cambia la imagen de fondo de VS Code con la galería de miniaturas
sel=$(python3 ~/.config/hypr/scripts/galeria.py "$HOME/Imágenes")
[ -z "$sel" ] || [ ! -f "$sel" ] && exit 0
cp "$sel" ~/.config/hypr/vscode/fondo.jpg
notify-send -a "VS Code" "Fondo cambiado" "En VS Code: Ctrl+Shift+P → 'Reload Window' para verlo"
