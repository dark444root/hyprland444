#!/usr/bin/env bash
# ============================================================
#  Terminal más llamativa: letra con iconos, prompt de cápsulas (starship),
#  info del equipo al abrir (fastfetch) y ls con iconos (eza)
#  Para deshacer:  bash ~/.config/hypr/scripts/terminal-revertir.sh
# ============================================================
H=~/.config/hypr
R=$H/respaldo-terminal
S=$H/terminal
mkdir -p "$R" ~/.config ~/.local/bin ~/.local/share/fonts ~/.config/fastfetch

echo ">> Respaldando tu configuración en $R"
cp ~/.bashrc "$R/bashrc" 2>/dev/null
cp ~/.config/kitty/kitty.conf "$R/kitty.conf" 2>/dev/null
[ -f ~/.config/starship.toml ] && cp ~/.config/starship.toml "$R/starship.toml"
[ -f ~/.config/fastfetch/config.jsonc ] && cp ~/.config/fastfetch/config.jsonc "$R/fastfetch.jsonc"

echo ">> Instalando fastfetch y eza (pide tu contraseña)"
sudo apt install -y fastfetch eza 2>/dev/null || sudo apt install -y fastfetch

echo ">> Instalando starship (prompt)"
if ! command -v starship >/dev/null; then
    sudo apt install -y starship 2>/dev/null || \
    curl -sS https://starship.rs/install.sh | sh -s -- -y -b ~/.local/bin
fi

echo ">> Instalando letra JetBrainsMono Nerd Font (con iconos)"
if ! fc-list | grep -qi "JetBrainsMono Nerd"; then
    tmp=$(mktemp -d)
    curl -sSL -o "$tmp/f.tar.xz" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz \
      && mkdir -p ~/.local/share/fonts/JetBrainsMonoNerd \
      && tar -xf "$tmp/f.tar.xz" -C ~/.local/share/fonts/JetBrainsMonoNerd \
      && fc-cache -f >/dev/null
    rm -rf "$tmp"
fi

echo ">> Configurando"
cp "$S/starship.toml" ~/.config/starship.toml
cp "$S/fastfetch.jsonc" ~/.config/fastfetch/config.jsonc

# Kitty: letra con iconos y detalles
k=~/.config/kitty/kitty.conf
sed -i '/# >>> terminal-bonita >>>/,/# <<< terminal-bonita <<</d' "$k"
cat >> "$k" <<'KITTY'
# >>> terminal-bonita >>>
font_family      JetBrainsMono Nerd Font
bold_font        JetBrainsMono Nerd Font Bold
italic_font      JetBrainsMono Nerd Font Italic
font_size        12
window_padding_width 16
cursor_shape beam
cursor_blink_interval 0.6
cursor_trail 3
cursor_trail_decay 0.1 0.4
background_opacity 0.88
tab_bar_edge top
tab_bar_style powerline
tab_powerline_style round
tab_title_template " {index}: {title} "
# <<< terminal-bonita <<<
KITTY

# Bash: prompt, info al abrir y atajos
sed -i '/# >>> terminal-bonita >>>/,/# <<< terminal-bonita <<</d' ~/.bashrc
cat >> ~/.bashrc <<'BASH'
# >>> terminal-bonita >>>
export PATH="$HOME/.local/bin:$PATH"
if [[ $- == *i* ]]; then
    command -v fastfetch >/dev/null && fastfetch
    if command -v eza >/dev/null; then
        alias ls='eza --icons --group-directories-first'
        alias ll='eza -l --icons --git --group-directories-first'
        alias la='eza -la --icons --git --group-directories-first'
        alias tree='eza --tree --icons'
    fi
    alias grep='grep --color=auto'
    command -v starship >/dev/null && eval "$(starship init bash)"
fi
# <<< terminal-bonita <<<
BASH

pkill -USR1 kitty 2>/dev/null
notify-send -a "Terminal" "Terminal lista" "Abre una terminal nueva (Windows + Enter)"
echo
echo ">> ¡Listo! Abre una terminal nueva para verla."
echo ">> Para regresar como estaba:  bash ~/.config/hypr/scripts/terminal-revertir.sh"
