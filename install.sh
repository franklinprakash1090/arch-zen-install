#!/bin/bash
# Fully optimized Arch KDE Zen auto-installer
# WARNING: This will erase the selected disk completely

set -e  # Exit on any error

# === 1️⃣ Variables ===
echo "=== Detecting available disks ==="
lsblk -d -o NAME,SIZE,MODEL | grep -v "loop\|sr0\|boot"
echo
read -p "Enter the disk to install Arch on (e.g., sdb): " TARGET

DISK="/dev/$TARGET"
HOSTNAME="arch-zen"
USERNAME="franklinprakash"
PASSWORD="tommy"
TIMEZONE="Asia/Kolkata"
SWAPSIZE="8G"

echo "=== You selected $DISK ==="
sleep 1

# === 2️⃣ Partition disk ===
partition_disk() {
    sgdisk --zap-all $DISK
    parted -s $DISK mklabel gpt
    parted -s $DISK mkpart ESP fat32 1MiB 513MiB
    parted -s $DISK set 1 boot on
    parted -s $DISK mkpart SWAP linux-swap 513MiB $((8*1024+513))MiB
    parted -s $DISK mkpart ROOT ext4 $((8*1024+513))MiB 100%
}

format_mount_disk() {
    EFI="${DISK}1"
    SWAP="${DISK}2"
    ROOT="${DISK}3"

    mkfs.fat -F32 $EFI
    mkswap $SWAP
    mkfs.ext4 -O ^has_journal -E lazy_itable_init=0,lazy_journal_init=0 $ROOT
    swapon $SWAP

    mount $ROOT /mnt
    mkdir -p /mnt/boot
    mount $EFI /mnt/boot
}

partition_disk
format_mount_disk

# === 3️⃣ Update mirrors ===
echo "=== Updating mirrorlist with fastest servers ==="
pacman -Sy --noconfirm reflector pv
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
reflector --latest 30 --country India --protocol https --sort rate --save /etc/pacman.d/mirrorlist
pacman -Syy --noconfirm

# Increase parallel downloads
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 16/' /etc/pacman.conf

# === 4️⃣ Install base + KDE minimal + utilities ===
pacstrap --needed /mnt base linux-zen linux-zen-headers linux-firmware vim sudo grub efibootmgr \
    networkmanager network-manager-applet wpa_supplicant dialog bluez bluez-utils \
    pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber \
    alsa-utils sof-firmware plasma-meta sddm firefox plymouth | pv -pterb > /tmp/pacstrap.log

genfstab -U /mnt >> /mnt/etc/fstab

# === 5️⃣ Configure system inside chroot ===
arch-chroot /mnt /bin/bash <<EOF
set -e

# --- Timezone & locale ---
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname

# --- Enable essential services ---
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable sddm
systemctl enable fstrim.timer
systemctl set-default graphical.target

# --- Create user ---
useradd -m -G wheel,network,video,audio -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "root:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel

# --- GRUB & theme ---
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
pacman -S --noconfirm grub-theme-breeze
echo 'GRUB_THEME="/usr/share/grub/themes/breeze/theme.txt"' >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# --- SDDM theme ---
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/kde.conf <<EOT
[Autologin]
#User=$USERNAME
#Session=plasmawayland

[Theme]
Current=breeze
EOT

# --- Plymouth spinner + initramfs optimization ---
plymouth-set-default-theme -R spinner
sed -i 's/HOOKS=(base udev autodetect modconf block filesystems fsck)/HOOKS=(base udev plymouth autodetect modconf block filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P
EOF

# === 6️⃣ Finish ===
umount -R /mnt
echo "✅ Optimized installation complete!"
echo "Reboot to start KDE Plasma 6 with SDDM + Breeze theme + PipeWire + Plymouth + GRUB theme."
