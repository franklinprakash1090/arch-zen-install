#!/bin/bash
# Arch Linux + KDE Plasma 6 + Linux-Zen + Plymouth + PipeWire + Firefox + NetworkManager
# Target: /dev/sdb
# Run from Arch ISO

DISK="/dev/sdb"
HOSTNAME="arch-zen"
USERNAME="franklinprakash"
PASSWORD="tommy"
TIMEZONE="Asia/Kolkata"

echo "=== Arch Linux (Zen kernel + KDE + PipeWire) installation on $DISK ==="
sleep 3

# 1. Partition disk
sgdisk --zap-all $DISK
parted -s $DISK mklabel gpt
parted -s $DISK mkpart ESP fat32 1MiB 513MiB
parted -s $DISK set 1 boot on
parted -s $DISK mkpart ROOT ext4 513MiB 100%

# 2. Format
mkfs.fat -F32 ${DISK}1
mkfs.ext4 -F ${DISK}2

# 3. Mount
mount ${DISK}2 /mnt
mkdir -p /mnt/boot
mount ${DISK}1 /mnt/boot

# 4. Base install
pacstrap /mnt base linux-zen linux-zen-headers linux-firmware vim sudo grub efibootmgr \
    networkmanager network-manager-applet wpa_supplicant dialog bluez bluez-utils \
    pipewire pipewire-audio pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
    alsa-utils sof-firmware gst-plugin-pipewire

# 5. Fstab
genfstab -U /mnt >> /mnt/etc/fstab

# 6. Configure system in chroot
arch-chroot /mnt /bin/bash <<EOF
echo "=== Configuring system inside chroot ==="

ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname

# Enable services
systemctl enable NetworkManager
systemctl enable bluetooth

# Create user
useradd -m -G wheel,network,video,audio -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "root:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel

# Bootloader (EFI)
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/&quiet splash vt.global_cursor_default=0 /' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# KDE Plasma + Firefox + Plymouth + greetd
pacman -S --noconfirm plasma-meta kde-utilities-meta konsole dolphin plasma-wayland-session firefox greetd tuigreet plymouth

# greetd setup
mkdir -p /etc/greetd
cat > /etc/greetd/config.toml <<GREET
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --cmd 'dbus-run-session startplasma-wayland'"
user = "$USERNAME"
GREET

# Plymouth theme + initramfs hooks
plymouth-set-default-theme -R spinner
sed -i 's/HOOKS=(base udev autodetect modconf block filesystems fsck)/HOOKS=(base udev plymouth autodetect modconf block filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# Enable greetd for auto-login UI
systemctl enable greetd
systemctl set-default graphical.target

echo "=== System ready inside chroot ==="
EOF

# 7. Cleanup
umount -R /mnt
echo "✅ Installation complete. Reboot now to enjoy KDE + PipeWire + Zen kernel."
