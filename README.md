# Arch Zen Install

A simple Arch Linux installation script for:

- ✅ `linux-zen` kernel
- 💻 KDE Plasma desktop (Wayland/X11)
- 🔊 PipeWire + WirePlumber
- 🎨 Plymouth boot splash (clean boot)
- 🌐 Zen Browser (AUR)
- 🗃️ ext4 file system
- 👤 Preconfigured user: `franklinprakash`

---

## 💽 Partition Setup (320GB Disk)

| Mount | Size   | Type | Format |
|-------|--------|------|--------|
| /boot | 512MB  | EFI  | FAT32  |
| swap  | 8GB    | Swap | swap   |
| /     | ~311GB | ext4 | ext4   |

### Format & Mount:
```bash
mkfs.fat -F32 /dev/sda1
mkswap /dev/sda2
mkfs.ext4 /dev/sda3
mount /dev/sda3 /mnt
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot
swapon /dev/sda2

🚀 Install Instructions
Boot into Arch ISO, set up your internet, then run:

bash
Copy
Edit
curl -O https://raw.githubusercontent.com/franklinprakash1090/arch-zen-install/main/install.sh
chmod +x install.sh
./install.sh
After install:

bash
Copy
Edit
umount -R /mnt
reboot
🔐 Credentials
Username: franklinprakash

Password: arch

Root password: root

🎨 Plymouth Theme (Optional)
bash
Copy
Edit
plymouth-set-default-theme -l
plymouth-set-default-theme arch-logo
mkinitcpio -P
📦 AUR: Zen Browser
The script clones and installs zen-browser-bin using makepkg.

📝 License
MIT — free to use and modify.


---

You're now all set to share your installer via:
