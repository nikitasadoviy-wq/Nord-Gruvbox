#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

echo "========================================="
echo "   Nord-Gruvbox Arch Linux Installer     "
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

echo "[4/6] Бекап старих конфігів та деплой нових..."
mkdir -p "$BACKUP_DIR" "$HOME/.config" "$HOME/Pictures"

for file in "$REPO_DIR/dotfiles/home/".*; do
    [[ -f "$file" ]] || continue
    base="$(basename "$file")"
    [[ -e "$HOME/$base" ]] && mv "$HOME/$base" "$BACKUP_DIR/"
    cp "$file" "$HOME/$base"
done

for dir in "$REPO_DIR/dotfiles/config/"*; do
    [[ -e "$dir" ]] || continue
    base="$(basename "$dir")"
    [[ -e "$HOME/.config/$base" ]] && mv "$HOME/.config/$base" "$BACKUP_DIR/"
    cp -r "$dir" "$HOME/.config/$base"
done

# Видача прав на виконання
chmod +x "$HOME/.xinitrc"
[[ -f "$HOME/.config/bspwm/bspwmrc" ]] && chmod +x "$HOME/.config/bspwm/bspwmrc"
[[ -f "$HOME/.config/polybar/launch.sh" ]] && chmod +x "$HOME/.config/polybar/launch.sh"
[[ -f "$HOME/.config/eww/scripts/quote_manager.py" ]] && chmod +x "$HOME/.config/eww/scripts/quote_manager.py"
[[ -f "$HOME/.config/eww/scripts/weather_engine.py" ]] && chmod +x "$HOME/.config/eww/scripts/weather_engine.py" 
[[ -f "$HOME/.config/eww/scripts/sysinfo.sh" ]] && chmod +x "$HOME/.config/eww/scripts/sysinfo.sh"

echo "[5/6] Передналаштування софту (LazyVim, Zsh, Picom, GTK)..."
if [[ -f "$HOME/.config/picom/picom.conf" ]] && [[ "$PROFILE" == "vmware" ]]; then
    sed -i 's/backend = "glx"/backend = "xrender"/g' "$HOME/.config/picom/picom.conf"
fi

# Ініціалізація LazyVim поверх базового шаблону, якщо плагіни ще не стягнуті
if [[ ! -d "$HOME/.local/share/nvim/lazy" ]]; then
    echo "Підготовка середовища Neovim + LazyVim..."
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
