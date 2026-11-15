#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================="
echo "    Nord-Gruvbox Arch Linux Installer    "
echo "========================================="
echo "Обери профіль системи:"
echo "  1) VMware Virtual Machine"
echo "  2) Laptop / PC (AMD + NVIDIA)"
echo "  3) Minimal (тільки база + WM без важких додатків)"
read -rp "Введи номер [1-3]: " PROFILE_CHOICE

case "$PROFILE_CHOICE" in
    1) PROFILE="vmware" ;;
    2) PROFILE="laptop-nvidia" ;;
    3) PROFILE="minimal" ;;
    *) echo "Невірний вибір. Вихід."; exit 1 ;;
esac

echo "[1/6] Оновлення дзеркал та бази пакетів..."
sudo pacman -Syyu --noconfirm

install_list() {
    local file="$1"
    if [[ -f "$file" ]]; then
        grep -vE '^\s*#|^\s*$' "$file" | sudo pacman -S --needed --noconfirm -
    fi
}

echo "[2/6] Встановлення базових та десктоп-пакетів..."
install_list "$REPO_DIR/packages/core.txt"
install_list "$REPO_DIR/packages/desktop.txt"

if [[ "$PROFILE" != "minimal" ]]; then
    install_list "$REPO_DIR/packages/apps.txt"
    [[ -f "$REPO_DIR/packages/profiles/${PROFILE}.txt" ]] && install_list "$REPO_DIR/packages/profiles/${PROFILE}.txt"
fi

echo "[3/6] Перевірка та встановлення paru (AUR)..."
if ! command -v paru >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm base-devel git
    git clone https://aur.archlinux.org/paru-bin.git /tmp/paru-bin
    (cd /tmp/paru-bin && makepkg -si --noconfirm)
    rm -rf /tmp/paru-bin
fi

if [[ -f "$REPO_DIR/packages/aur.txt" ]]; then
    grep -vE '^\s*#|^\s*$' "$REPO_DIR/packages/aur.txt" | paru -S --needed --noconfirm -
fi

echo "[4/6] Радикальне очищення старих конфігів та деплой нових..."
mkdir -p "$HOME/.config" "$HOME/Pictures" "$HOME/.cache/nord-gruvbox"

# Список усіх конфіг-папок для управління
CONFIGS=(bspwm sxhkd alacritty eww polybar picom rofi dunst nvim yazi flameshot greenclip)

# Повне видалення старих папок без бекапів
for cfg in "${CONFIGS[@]}"; do
    if [ -d "$HOME/.config/$cfg" ]; then
        rm -rf "$HOME/.config/$cfg"
        echo "  [-] Видалено стару папку: ~/.config/$cfg"
    fi
done

# Копіювання файлів із dotfiles/home/ (якщо існують)
for file in "$REPO_DIR/dotfiles/home/".*; do
    [[ -f "$file" ]] || continue
    base="$(basename "$file")"
    [[ -e "$HOME/$base" ]] && rm -f "$HOME/$base"
    cp "$file" "$HOME/$base"
done

# Копіювання нових конфігів із репозиторію
for cfg in "${CONFIGS[@]}"; do
    if [ -d "$REPO_DIR/dotfiles/config/$cfg" ]; then
        cp -r "$REPO_DIR/dotfiles/config/$cfg" "$HOME/.config/"
        echo "  [+] Встановлено новий конфіг: $cfg"
    fi
done

if [ -f "$REPO_DIR/dotfiles/config/starship.toml" ]; then
    cp "$REPO_DIR/dotfiles/config/starship.toml" "$HOME/.config/starship.toml"
    echo "  [+] Встановлено файл: starship.toml"
fi

echo "[4.5/6] Динамічне налаштування шляхів та прав виконання (+x)..."
if [[ -f "$HOME/.config/flameshot/flameshot.ini" ]]; then
    sed -i "s|savePath=.*|savePath=$HOME/Pictures|g" "$HOME/.config/flameshot/flameshot.ini"
fi

if [[ -f "$HOME/.config/greenclip/greenclip.toml" ]]; then
    sed -i "s|/home/nikituch|$HOME|g" "$HOME/.config/greenclip/greenclip.toml"
fi

# Універсальна видача прав на виконання для скриптів
[[ -f "$HOME/.xinitrc" ]] && chmod +x "$HOME/.xinitrc"
[[ -f "$HOME/.config/bspwm/bspwmrc" ]] && chmod +x "$HOME/.config/bspwm/bspwmrc"
[[ -f "$HOME/.config/polybar/launch.sh" ]] && chmod +x "$HOME/.config/polybar/launch.sh"

if [ -d "$HOME/.config/eww/scripts" ]; then
    chmod +x "$HOME/.config/eww/scripts/"*.py
    chmod +x "$HOME/.config/eww/scripts/"*.sh
    echo "  [+] Проставлено права +x для всіх скриптів Eww"
fi

echo "[5/6] Передналаштування софту (LazyVim, Zsh, Picom, GTK)..."
if [[ -f "$HOME/.config/picom/picom.conf" ]] && [[ "$PROFILE" == "vmware" ]]; then
    sed -i 's/backend = "glx"/backend = "xrender"/g' "$HOME/.config/picom/picom.conf"
fi

if [[ "$SHELL" != "/usr/bin/zsh" ]]; then
    sudo chsh -s /usr/bin/zsh "$USER"
fi

gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true

echo "[6/6] Активація системних сервісів..."
sudo systemctl enable NetworkManager.service
if [[ "$PROFILE" == "vmware" ]]; then
    sudo systemctl enable vmtoolsd.service
    sudo systemctl enable vmware-vmblock-fuse.service
elif [[ "$PROFILE" == "laptop-nvidia" ]]; then
    sudo systemctl enable power-profiles-daemon.service
fi

echo "========================================="
echo " Готово! Перезавантаж систему: sudo reboot"
echo "========================================="
