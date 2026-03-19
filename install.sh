#!/usr/bin/env bash
# =============================================================================
# Arch Linux External Drive Installer  v2.0
# Run from Arch ISO live environment
# Usage:  bash arch-install.sh
#         bash arch-install.sh --dry-run   (preview only, no disk changes)
# =============================================================================

set -euo pipefail

# ── Dry-run flag ──────────────────────────────────────────────────────────────
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

# ── Log file ──────────────────────────────────────────────────────────────────
LOG=/tmp/arch-install.log
exec > >(tee -a "$LOG") 2>&1
echo "=== Arch Installer started $(date) ===" >> "$LOG"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
TOTAL_STEPS=10

step()    { echo -e "\n${BOLD}${CYAN}[${1}/${TOTAL_STEPS}] ${2}${RESET}"; }
info()    { echo -e "  ${CYAN}→${RESET} $*"; }
success() { echo -e "  ${GREEN}✓${RESET} $*"; }
warn()    { echo -e "  ${YELLOW}⚠${RESET}  $*"; }
error()   { echo -e "\n${RED}[ERR]${RESET} $*\n  Log: $LOG"; exit 1; }
ask()     { echo -ne "  ${BOLD}?${RESET}  $*"; }
dryrun()  { echo -e "  ${YELLOW}[DRY-RUN]${RESET} would run: $*"; }
run()     {
    if [[ $DRY_RUN -eq 1 ]]; then dryrun "$*"
    else eval "$@"; fi
}

# ── Banner ────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}"
cat << 'EOF'
 █████╗ ██████╗  ██████╗██╗  ██╗    ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗
██╔══██╗██╔══██╗██╔════╝██║  ██║    ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║
███████║██████╔╝██║     ███████║    ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║
██╔══██║██╔══██╗██║     ██╔══██║    ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║
██║  ██║██║  ██║╚██████╗██║  ██║    ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝╚═╝  ╚═══╝╚══════╝  ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝
EOF
echo -e "              External Drive Installer  v2.0${RESET}"
[[ $DRY_RUN -eq 1 ]] && echo -e "  ${YELLOW}▶ DRY-RUN MODE — no disk changes will be made${RESET}"
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# STEP 0 — Pre-flight checks
# ═════════════════════════════════════════════════════════════════════════════
step 0 "Pre-flight checks"
[[ $EUID -ne 0 ]] && error "Run as root: sudo bash arch-install.sh"
ping -c1 -W2 archlinux.org &>/dev/null || error "No internet. Connect first (iwctl / dhcpcd)."
success "Root OK  |  Internet OK"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 1 — Auto-detect USB / external drive
# ═════════════════════════════════════════════════════════════════════════════
step 1 "Detecting external drive"

mapfile -t USB_DRIVES < <(lsblk -d -o NAME,TRAN --noheadings | awk '$2=="usb"{print $1}')
[[ ${#USB_DRIVES[@]} -eq 0 ]] && error "No USB drives detected. Plug in your drive and re-run."

if [[ ${#USB_DRIVES[@]} -eq 1 ]]; then
    DRIVE_NAME="${USB_DRIVES[0]}"
    TARGET_DISK="/dev/${DRIVE_NAME}"
    success "Auto-detected: $(lsblk -d -o NAME,SIZE,MODEL "$TARGET_DISK" | tail -1)"
else
    echo -e "\n  ${BOLD}Multiple USB drives found:${RESET}"
    printf "    %-5s %-10s %-8s %s\n" "No." "NAME" "SIZE" "MODEL"
    IDX=1
    for D in "${USB_DRIVES[@]}"; do
        INFO=$(lsblk -d -o SIZE,MODEL "/dev/$D" --noheadings | xargs)
        printf "    [%-2s] %-10s %s\n" "$IDX" "$D" "$INFO"
        (( IDX++ ))
    done
    echo ""
    ask "Select drive number [1-${#USB_DRIVES[@]}]: "; read -r SELECTION
    [[ ! "$SELECTION" =~ ^[0-9]+$ ]] && error "Invalid input."
    (( SELECTION < 1 || SELECTION > ${#USB_DRIVES[@]} )) && error "Out of range."
    DRIVE_NAME="${USB_DRIVES[$((SELECTION-1))]}"
    TARGET_DISK="/dev/${DRIVE_NAME}"
fi

echo ""
warn "TARGET  : $(lsblk -d -o NAME,SIZE,MODEL "$TARGET_DISK" | tail -1)"
warn "ALL DATA ON $TARGET_DISK WILL BE PERMANENTLY ERASED!"
ask "Type 'YES' to confirm: "; read -r CONFIRM
[[ "$CONFIRM" != "YES" ]] && error "Aborted."

# ═════════════════════════════════════════════════════════════════════════════
# STEP 2 — Smart auto partition layout
# ═════════════════════════════════════════════════════════════════════════════
step 2 "Calculating partition layout"

DISK_BYTES=$(lsblk -b -d -o SIZE --noheadings "$TARGET_DISK" | tr -d ' ')
DISK_GB=$(( DISK_BYTES / 1024 / 1024 / 1024 ))
RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
RAM_GB=$(( RAM_KB / 1024 / 1024 ))
[[ $RAM_GB -lt 1 ]] && RAM_GB=1
(( DISK_GB < 8 )) && error "Drive too small (${DISK_GB} GB). Minimum 8 GB required."

SWAP_GB=$RAM_GB; (( SWAP_GB > 8 )) && SWAP_GB=8
USE_SWAP=1; USE_HOME=0; HOME_GB=0

if   (( DISK_GB <= 16  )); then USE_SWAP=0; SWAP_GB=0; ROOT_GB=$(( DISK_GB - 1 ));            LAYOUT_LABEL="Minimal  (≤16 GB)"
elif (( DISK_GB <= 32  )); then ROOT_GB=$(( DISK_GB - 1 - SWAP_GB ));                          LAYOUT_LABEL="Standard (17-32 GB)"
elif (( DISK_GB <= 128 )); then ROOT_GB=$(( DISK_GB - 1 - SWAP_GB ));                          LAYOUT_LABEL="Comfortable (33-128 GB)"
else                             ROOT_GB=60; HOME_GB=$(( DISK_GB - 1 - SWAP_GB - ROOT_GB )); USE_HOME=1; LAYOUT_LABEL="Full with /home (>128 GB)"
fi

[[ "$DRIVE_NAME" == nvme* ]] && P="p" || P=""
IDX=1
EFI_PART="${TARGET_DISK}${P}${IDX}";  (( IDX++ ))
(( USE_SWAP )) && { SWAP_PART="${TARGET_DISK}${P}${IDX}"; (( IDX++ )); } || SWAP_PART=""
ROOT_PART="${TARGET_DISK}${P}${IDX}"; (( IDX++ ))
[[ $USE_HOME -eq 1 ]] && HOME_PART="${TARGET_DISK}${P}${IDX}" || HOME_PART=""

echo ""
echo -e "  ${BOLD}Drive${RESET}   : ${CYAN}${DISK_GB} GB${RESET}   ${BOLD}RAM${RESET}: ${CYAN}${RAM_GB} GB${RESET}   ${BOLD}Profile${RESET}: ${CYAN}${LAYOUT_LABEL}${RESET}"
echo ""
printf "  ${BOLD}%-22s %-10s %s${RESET}\n" "Partition" "Size" "Type"
printf "  %-22s %-10s %s\n"  "$EFI_PART"  "512 MB"        "EFI System (FAT32)"
[[ -n "$SWAP_PART" ]] && printf "  %-22s %-10s %s\n" "$SWAP_PART" "${SWAP_GB} GB" "Linux Swap"
printf "  %-22s %-10s %s\n"  "$ROOT_PART" "${ROOT_GB} GB" "Linux Root (ext4)"
[[ -n "$HOME_PART" ]] && printf "  %-22s %-10s %s\n" "$HOME_PART" "${HOME_GB} GB" "Linux /home (ext4)"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 3 — Auto-detect GPU + CPU
# ═════════════════════════════════════════════════════════════════════════════
step 3 "Detecting hardware (GPU + CPU)"

GPU_PKGS=""
GPU_LABEL="Generic (mesa)"

if lspci | grep -qi "nvidia"; then
    GPU_PKGS="nvidia nvidia-utils nvidia-settings libva-nvidia-driver"
    GPU_LABEL="NVIDIA"
elif lspci | grep -qi "amd\|radeon\|advanced micro devices"; then
    GPU_PKGS="mesa vulkan-radeon libva-mesa-driver mesa-vdpau xf86-video-amdgpu"
    GPU_LABEL="AMD / Radeon"
elif lspci | grep -qi "intel"; then
    GPU_PKGS="mesa vulkan-intel intel-media-driver libva-intel-driver"
    GPU_LABEL="Intel"
fi

UCODE_PKG=""
CPU_LABEL="Unknown"
if grep -qi "intel" /proc/cpuinfo; then
    UCODE_PKG="intel-ucode"; CPU_LABEL="Intel"
elif grep -qi "amd" /proc/cpuinfo; then
    UCODE_PKG="amd-ucode";   CPU_LABEL="AMD"
fi

success "GPU : $GPU_LABEL  |  CPU : $CPU_LABEL (microcode: ${UCODE_PKG:-none})"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 4 — User configuration
# ═════════════════════════════════════════════════════════════════════════════
step 4 "User configuration"

ask "Hostname [archlinux]: ";    read -r HOSTNAME; HOSTNAME="${HOSTNAME:-archlinux}"
ask "Username: ";                read -r USERNAME
[[ -z "$USERNAME" ]] && error "Username cannot be empty."

echo ""
while true; do
    ask "Root password: ";       read -rs ROOT_PASS;  echo ""
    ask "Confirm root password: "; read -rs ROOT_PASS2; echo ""
    [[ "$ROOT_PASS" == "$ROOT_PASS2" ]] && break
    warn "Passwords do not match. Try again."
done
while true; do
    ask "Password for $USERNAME: ";  read -rs USER_PASS;  echo ""
    ask "Confirm password: ";        read -rs USER_PASS2; echo ""
    [[ "$USER_PASS" == "$USER_PASS2" ]] && break
    warn "Passwords do not match. Try again."
done

echo ""
ask "Timezone [Asia/Kolkata]: "; read -r TIMEZONE; TIMEZONE="${TIMEZONE:-Asia/Kolkata}"
ask "Locale [en_US.UTF-8]: ";   read -r LOCALE;   LOCALE="${LOCALE:-en_US.UTF-8}"

echo ""
echo "  1) None/Minimal  2) GNOME  3) KDE Plasma  4) Hyprland"
ask "Desktop environment [1]: "; read -r DE_CHOICE; DE_CHOICE="${DE_CHOICE:-1}"

case "$DE_CHOICE" in
    2) DE_PKGS="gnome gnome-tweaks gdm";                                         DM="gdm"  ;;
    3) DE_PKGS="plasma plasma-wayland-protocols kde-applications sddm";          DM="sddm" ;;
    4) DE_PKGS="hyprland waybar wofi kitty sddm \
                xdg-desktop-portal-hyprland \
                polkit-kde-agent qt5-wayland qt6-wayland \
                hyprpaper grim slurp wl-clipboard \
                noto-fonts noto-fonts-emoji ttf-jetbrains-mono \
                brightnessctl playerctl network-manager-applet";                 DM="sddm" ;;
    *) DE_PKGS=""; DM="" ;;
esac

[[ $DRY_RUN -eq 1 ]] && { warn "DRY-RUN: would install DE=$DE_CHOICE GPU=$GPU_LABEL CPU=$CPU_LABEL"; }

# ═════════════════════════════════════════════════════════════════════════════
# STEP 5 — Fast mirrors via reflector
# ═════════════════════════════════════════════════════════════════════════════
step 5 "Optimising mirrors (reflector)"

if [[ $DRY_RUN -eq 0 ]]; then
    pacman -Sy --noconfirm reflector &>/dev/null
    reflector --country India,Singapore --latest 10 --sort rate \
              --save /etc/pacman.d/mirrorlist 2>/dev/null \
        && success "Mirrors updated (fastest 10 in India/Singapore)" \
        || warn "reflector failed — using default mirrors"
else
    dryrun "reflector --country India,Singapore --latest 10 --sort rate"
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 6 — Partition + Format + Mount
# ═════════════════════════════════════════════════════════════════════════════
step 6 "Partitioning, formatting, mounting"

if [[ $DRY_RUN -eq 0 ]]; then
    sgdisk --zap-all "$TARGET_DISK" > /dev/null
    N=1
    sgdisk -n ${N}:0:+512M       -t ${N}:ef00 -c ${N}:"EFI"  "$TARGET_DISK" > /dev/null; (( N++ ))
    (( USE_SWAP )) && { sgdisk -n ${N}:0:+${SWAP_GB}G -t ${N}:8200 -c ${N}:"SWAP" "$TARGET_DISK" > /dev/null; (( N++ )); }
    if (( USE_HOME )); then
        sgdisk -n ${N}:0:+${ROOT_GB}G -t ${N}:8300 -c ${N}:"ROOT" "$TARGET_DISK" > /dev/null; (( N++ ))
        sgdisk -n ${N}:0:0            -t ${N}:8300 -c ${N}:"HOME" "$TARGET_DISK" > /dev/null
    else
        sgdisk -n ${N}:0:0            -t ${N}:8300 -c ${N}:"ROOT" "$TARGET_DISK" > /dev/null
    fi
    partprobe "$TARGET_DISK"; sleep 2
    success "Partitioned"

    mkfs.fat -F32 -n EFI  "$EFI_PART"  > /dev/null; success "$EFI_PART  → FAT32"
    [[ -n "$SWAP_PART" ]] && { mkswap -L SWAP "$SWAP_PART" > /dev/null; success "$SWAP_PART → swap"; }
    mkfs.ext4 -L ROOT -F  "$ROOT_PART" > /dev/null; success "$ROOT_PART → ext4 root"
    [[ -n "$HOME_PART" ]] && { mkfs.ext4 -L HOME -F "$HOME_PART" > /dev/null; success "$HOME_PART → ext4 home"; }

    mount "$ROOT_PART" /mnt
    mkdir -p /mnt/boot/efi; mount "$EFI_PART" /mnt/boot/efi
    [[ -n "$SWAP_PART" ]] && swapon "$SWAP_PART"
    [[ -n "$HOME_PART" ]] && { mkdir -p /mnt/home; mount "$HOME_PART" /mnt/home; }
    success "All partitions mounted"
else
    dryrun "sgdisk + mkfs + mount on $TARGET_DISK"
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 7 — pacstrap
# ═════════════════════════════════════════════════════════════════════════════
step 7 "Installing base system"

BASE_PKGS="base base-devel linux linux-firmware linux-headers \
           nano vim networkmanager firewalld grub efibootmgr \
           sudo git wget curl htop neofetch \
           man-db man-pages texinfo \
           wayland wayland-protocols wayland-utils \
           xdg-utils xdg-user-dirs xdg-desktop-portal \
           pipewire pipewire-alsa pipewire-pulse wireplumber \
           mesa vulkan-icd-loader libva \
           $UCODE_PKG"

if [[ $DRY_RUN -eq 0 ]]; then
    # shellcheck disable=SC2086
    pacstrap /mnt $BASE_PKGS $GPU_PKGS $DE_PKGS
    success "Base system installed"
    genfstab -U /mnt >> /mnt/etc/fstab
    success "fstab written"
else
    dryrun "pacstrap /mnt [base + gpu:$GPU_LABEL + de:$DE_CHOICE]"
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 8 — chroot configuration
# ═════════════════════════════════════════════════════════════════════════════
step 8 "Configuring system (chroot)"

if [[ $DRY_RUN -eq 0 ]]; then
arch-chroot /mnt /bin/bash <<CHROOT
set -e

# Timezone & clock
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

# Locale
echo "${LOCALE} UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf

# Hostname
echo "${HOSTNAME}" > /etc/hostname
printf "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t${HOSTNAME}.localdomain ${HOSTNAME}\n" > /etc/hosts

# Passwords (real ones)
echo "root:${ROOT_PASS}" | chpasswd
useradd -m -G wheel,audio,video,storage,optical,network -s /bin/bash "${USERNAME}"
echo "${USERNAME}:${USER_PASS}" | chpasswd

# sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# mkinitcpio — ensure keymap + consolefont hooks
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# Services
systemctl enable NetworkManager
systemctl enable firewalld
systemctl enable fstrim.timer
[[ -n "${DM}" ]] && systemctl enable "${DM}"
systemctl enable pipewire pipewire-pulse wireplumber 2>/dev/null || true

# GRUB — disable os-prober (avoids host GRUB confusion), --removable for portability
sed -i 's/^#GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=true/' /etc/default/grub
grub-install --target=x86_64-efi \
             --efi-directory=/boot/efi \
             --bootloader-id=GRUB \
             --removable \
             --recheck
grub-mkconfig -o /boot/grub/grub.cfg

CHROOT
success "System configured"
else
    dryrun "arch-chroot config (locale, users, grub, services)"
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 9 — Hyprland starter config (if chosen)
# ═════════════════════════════════════════════════════════════════════════════
step 9 "Post-install extras"

if [[ "$DE_CHOICE" == "4" && $DRY_RUN -eq 0 ]]; then
    HYPR_DIR="/mnt/home/${USERNAME}/.config/hypr"
    mkdir -p "$HYPR_DIR"
    cat > "${HYPR_DIR}/hyprland.conf" << 'HYPRCONF'
# ── Hyprland starter config ────────────────────────────────────────────────
monitor=,preferred,auto,1

# Autostart
exec-once = waybar
exec-once = hyprpaper
exec-once = /usr/lib/polkit-kde-authentication-agent-1
exec-once = nm-applet --indicator

# Environment
env = XCURSOR_SIZE,24
env = QT_QPA_PLATFORM,wayland
env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
env = GDK_BACKEND,wayland
env = MOZ_ENABLE_WAYLAND,1

# Input
input {
    kb_layout = us
    follow_mouse = 1
    touchpad { natural_scroll = true }
    sensitivity = 0
}

# General
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(89b4faff) rgba(cba6f7ff) 45deg
    col.inactive_border = rgba(45475aff)
    layout = dwindle
}

# Decoration
decoration {
    rounding = 10
    blur { enabled = true; size = 5; passes = 2 }
    drop_shadow = true
    shadow_range = 8
    shadow_render_power = 3
}

# Animations
animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 5, myBezier
    animation = windowsOut, 1, 4, default, popin 80%
    animation = fade, 1, 5, default
    animation = workspaces, 1, 4, default
}

# Layout
dwindle { pseudotile = true; preserve_split = true }

# ── Keybinds ──────────────────────────────────────────────────────────────
$mod = SUPER

bind = $mod, Return, exec, kitty
bind = $mod, Q,      killactive
bind = $mod, M,      exit
bind = $mod, E,      exec, nautilus
bind = $mod, V,      togglefloating
bind = $mod, R,      exec, wofi --show drun
bind = $mod, P,      pseudo
bind = $mod, J,      togglesplit

# Focus
bind = $mod, left,  movefocus, l
bind = $mod, right, movefocus, r
bind = $mod, up,    movefocus, u
bind = $mod, down,  movefocus, d

# Workspaces 1–9
$w = bind = $mod
bind = $mod, 1, workspace, 1
bind = $mod, 2, workspace, 2
bind = $mod, 3, workspace, 3
bind = $mod, 4, workspace, 4
bind = $mod, 5, workspace, 5

bind = $mod SHIFT, 1, movetoworkspace, 1
bind = $mod SHIFT, 2, movetoworkspace, 2
bind = $mod SHIFT, 3, movetoworkspace, 3
bind = $mod SHIFT, 4, movetoworkspace, 4
bind = $mod SHIFT, 5, movetoworkspace, 5

# Screenshot
bind = , Print, exec, grim -g "$(slurp)" - | wl-copy

# Volume / Brightness
bindel = ,XF86AudioRaiseVolume,  exec, wpctl set-volume @DEFAULT_SINK@ 5%+
bindel = ,XF86AudioLowerVolume,  exec, wpctl set-volume @DEFAULT_SINK@ 5%-
bindel = ,XF86AudioMute,         exec, wpctl set-mute @DEFAULT_SINK@ toggle
bindel = ,XF86MonBrightnessUp,   exec, brightnessctl set 10%+
bindel = ,XF86MonBrightnessDown, exec, brightnessctl set 10%-

# Window rules
windowrule = float, ^(pavucontrol)$
windowrule = float, ^(nm-connection-editor)$
HYPRCONF

    # SDDM Wayland session
    mkdir -p /mnt/etc/sddm.conf.d
    cat > /mnt/etc/sddm.conf.d/wayland.conf << 'SDDMCONF'
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts
SDDMCONF

    arch-chroot /mnt chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.config"
    success "Hyprland starter config written → ~/.config/hypr/hyprland.conf"
    success "SDDM Wayland session configured"
fi

# ── Drop post-install reminder script ─────────────────────────────────────────
if [[ $DRY_RUN -eq 0 ]]; then
cat > "/mnt/home/${USERNAME}/post-install.sh" << POSTINSTALL
#!/usr/bin/env bash
# Run this after first boot as your user
echo "=== Post-install checklist ==="
echo "1. Install AUR helper:"
echo "   git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si"
echo ""
echo "2. If NVIDIA — enable DRM:"
echo "   sudo sed -i 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"nvidia-drm.modeset=1\"/' /etc/default/grub"
echo "   sudo grub-mkconfig -o /boot/grub/grub.cfg"
echo ""
echo "3. Update system:"
echo "   sudo pacman -Syu"
echo ""
echo "4. Check firewall status:"
echo "   sudo firewall-cmd --state"
POSTINSTALL
    chmod +x "/mnt/home/${USERNAME}/post-install.sh"
    arch-chroot /mnt chown "${USERNAME}:${USERNAME}" "/home/${USERNAME}/post-install.sh"
    success "post-install.sh placed in ~/"
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 10 — Unmount & done
# ═════════════════════════════════════════════════════════════════════════════
step 10 "Finalising"

if [[ $DRY_RUN -eq 0 ]]; then
    umount -R /mnt
    [[ -n "$SWAP_PART" ]] && swapoff "$SWAP_PART" 2>/dev/null || true
    success "Unmounted cleanly"
fi

echo ""
echo -e "${BOLD}${GREEN}"
echo "  ╔═══════════════════════════════════════════════════════════╗"
echo "  ║                                                           ║"
[[ $DRY_RUN -eq 1 ]] && \
echo "  ║   DRY-RUN complete — no changes were made                ║" || \
echo "  ║   ✓  Arch Linux installed on ${TARGET_DISK}                  ║"
echo "  ║                                                           ║"
echo "  ║   ► Select drive in BIOS/UEFI boot menu (F12/F11)        ║"
echo "  ║   ► Run ~/post-install.sh after first login              ║"
echo "  ║   ► Full log saved to: $LOG                   ║"
echo "  ║                                                           ║"
echo "  ╚═══════════════════════════════════════════════════════════╝"
echo -e "${RESET}"
