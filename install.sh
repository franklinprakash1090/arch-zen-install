#!/bin/bash
# Auto-partition Arch Linux + KDE Plasma 6 + Linux-Zen + PipeWire + Plymouth
# WARNING: This will erase the selected disk

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
sleep 2

# 1. Wipe disk and create partitions
echo "=== Wiping and partitioning $DISK ==="
sgdisk --zap-all $DISK
parted -s $DISK mklabel gpt
parted -s $DISK mkpart ESP fat32 1MiB 513MiB
parted -s $DISK set 1 boot on
parted -s $DISK mkpart SWAP linux-swap 513MiB $((8*1024+513))MiB
parted -s $DISK mkpart ROOT ext4 $((8*1024+513))MiB 100%

# Get partition names
EFI="${DISK}1"
SWAP="${DISK}2"
ROOT="${DISK}3"

# 2. Format partitions
mkfs.fat -F32 $EFI
mkswap $SWAP
mkfs.ext4 $ROOT
swapon $SWAP

# 3. Mount partitions
mount $ROOT /mnt
mkdir -p /mnt/boot
mount $EFI /mnt/boot

# 4. Install base system
pacstrap /mnt base linux-zen linux-zen-headers linux-firmware vim sudo grub efibootmgr \
    networkmanager network-manager-applet wpa_supplicant dialog bluez bluez-utils \
    pipewire pipewire-audio pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
    alsa-utils sof-firmware plasma-meta kde-utilities-meta konsole dolphin plasma-wayland-session \
    firefox greetd tuigreet plymouth

# 5. Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# 6. Configure system in chroot
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname

# Enable NetworkManager and Bluetooth
systemctl enable NetworkManager
systemctl enable bluetooth

# Create user
useradd -m -G wheel,network,video,audio -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "root:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel

# Install GRUB bootloader
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/&quiet splash vt.global_cursor_default=0 /' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Configure greetd for KDE Wayland
mkdir -p /etc/greetd
cat > /etc/greetd/config.toml <<GREET
[terminal]
vt = 1
[default_session]
command = "tuigreet --time --cmd 'dbus-run-session startplasma-wayland'"
user = "$USERNAME"
GREET

# Plymouth setup
plymouth-set-default-theme -R spinner
sed -i 's/HOOKS=(base udev autodetect modconf block filesystems fsck)/HOOKS=(base udev plymouth autodetect modconf block filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

systemctl enable greetd
systemctl set-default graphical.target
EOF

# 7. Finish
umount -R /mnt
echo "✅ Installation complete! Reboot to start Arch KDE Plasma 6 with Zen kernel, PipeWire, Plymouth, and NetworkManager."
