#!/usr/bin/env bash
# Instala la extensión "background" para poner una imagen de fondo en VS Code
echo ">> Cierra VS Code antes de continuar (Enter para seguir)"; read -r
code_bin=$(readlink -f "$(command -v code)")
dir=$(dirname "$(dirname "$code_bin")")          # normalmente /usr/share/code
if [[ "$dir" == /snap/* ]]; then
    echo "!! VS Code está instalado como snap y no permite fondos. Instálalo desde el .deb oficial."; exit 1
fi
echo ">> Dando permiso a la extensión para modificar VS Code ($dir) — pide tu contraseña"
sudo chown -R "$USER" "$dir"
echo ">> Instalando la extensión background"
code --install-extension shalldie.background --force
echo
echo ">> ¡Listo! Abre VS Code. Si sale un aviso de 'instalación dañada', elige 'No volver a mostrar':"
echo "   es normal con esta extensión y no afecta nada."
echo ">> Para cambiar la imagen:  bash ~/.config/hypr/scripts/vscode-fondo.sh"
