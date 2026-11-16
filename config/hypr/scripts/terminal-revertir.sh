#!/usr/bin/env bash
# Regresa la terminal a como estaba antes de terminal-bonita.sh
R=~/.config/hypr/respaldo-terminal
sed -i '/# >>> terminal-bonita >>>/,/# <<< terminal-bonita <<</d' ~/.bashrc ~/.config/kitty/kitty.conf
if [ -f "$R/starship.toml" ]; then cp "$R/starship.toml" ~/.config/starship.toml; else rm -f ~/.config/starship.toml; fi
if [ -f "$R/fastfetch.jsonc" ]; then cp "$R/fastfetch.jsonc" ~/.config/fastfetch/config.jsonc; else rm -f ~/.config/fastfetch/config.jsonc; fi
pkill -USR1 kitty 2>/dev/null
echo ">> Listo. Abre una terminal nueva: ya está como antes."
