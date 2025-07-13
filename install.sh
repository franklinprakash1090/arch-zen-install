#!/bin/bash
set -e

echo "==> Installing base system"
pacstrap -K /mnt base linux-zen linux-zen-headers linux-firmware vim sudo nano networkmanager grub efibootmgr os-prober dosfstools mtools base-devel git plymouth

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf

echo archzen > /etc/hostname
cat >> /etc/hosts <<END
127.0.0.1 localhost
::1       localhost
127.0.1.1 archzen.localdomain archzen
END

echo "Creating user franklinprakash"
useradd -m -G wheel franklinprakash
echo "franklinprakash:arch" | chpasswd
echo "root:root" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

systemctl enable NetworkManager

echo "==> Bootloader installation"
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& quiet splash/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo "==> Plymouth hook and splash"
sed -i 's/^HOOKS=(.*/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont plymouth filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

echo "==> Desktop environment (Plasma)"
pacman -Sy --noconfirm plasma-meta kde-applications sddm xorg pipewire wireplumber plasma-wayland-session
systemctl enable sddm

echo "==> Installing zen-browser-bin (AUR)"
cd /home/franklinprakash
git clone https://aur.archlinux.org/zen-browser-bin.git
chown -R franklinprakash:franklinprakash zen-browser-bin
cd zen-browser-bin
sudo -u franklinprakash makepkg -si --noconfirm
EOF

echo "==> Installation complete! You can reboot."
