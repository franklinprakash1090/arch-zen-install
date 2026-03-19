<div align="center">

```
 █████╗ ██████╗  ██████╗██╗  ██╗    ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗
██╔══██╗██╔══██╗██╔════╝██║  ██║    ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║
███████║██████╔╝██║     ███████║    ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║
██╔══██║██╔══██╗██║     ██╔══██║    ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║
██║  ██║██║  ██║╚██████╗██║  ██║    ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝╚═╝  ╚═══╝╚══════╝  ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝
```

**Automated Arch Linux installer for external / USB drives**

![Bash](https://img.shields.io/badge/bash-5.0%2B-4EAA25?style=flat-square&logo=gnubash&logoColor=white)
![Arch Linux](https://img.shields.io/badge/Arch%20Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white)
![Wayland](https://img.shields.io/badge/Wayland-only-orange?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)

</div>

---

## ✨ Features

| Feature | Details |
|---|---|
| 🔍 **Auto drive detection** | Finds USB drives via `lsblk TRAN=usb` — no manual `/dev/sdX` guessing |
| 📐 **Smart partition layout** | Calculates EFI / swap / root / home sizes from drive size + RAM |
| 🎮 **GPU auto-detection** | Installs correct drivers for NVIDIA / AMD / Intel automatically |
| 🖥️ **CPU microcode** | Auto-installs `intel-ucode` or `amd-ucode` |
| 🌊 **Pure Wayland** | No Xorg. Supports GNOME, KDE Plasma, and Hyprland |
| 🔒 **Secure passwords** | Prompts for real passwords at install time — no hardcoded defaults |
| ⚡ **Fast mirrors** | Runs `reflector` before `pacstrap` for fastest regional mirrors |
| 🛡️ **Firewall** | `firewalld` enabled by default on every install |
| 🚀 **Hyprland ready** | Drops a working `hyprland.conf` so you boot straight into a desktop |
| 🪵 **Full logging** | Everything logged to `/tmp/arch-install.log` |
| 🧪 **Dry-run mode** | Preview the full install plan without touching your disk |

---

## 🚀 Quick Start

Boot into the **Arch Linux ISO**, connect to the internet, then run:

```bash
bash <(curl -s https://raw.githubusercontent.com/YOUR_USERNAME/arch-install/main/arch-install.sh)
```

Or clone and run locally:

```bash
git clone https://github.com/YOUR_USERNAME/arch-install.git
cd arch-install
bash arch-install.sh
```

Preview without making any changes:

```bash
bash arch-install.sh --dry-run
```

---

## 📋 Requirements

- Booted into **Arch Linux ISO** (live environment)
- External / USB drive connected (**8 GB minimum**)
- Active internet connection
- UEFI system (GPT + EFI)

---

## 🗂️ Partition Layout

The script reads your drive size and RAM, then picks the best layout automatically:

| Drive Size | EFI | Swap | Root | /home | Profile |
|---|---|---|---|---|---|
| ≤ 16 GB | 512 MB | — | rest | — | Minimal |
| 17 – 32 GB | 512 MB | = RAM (max 8 GB) | rest | — | Standard |
| 33 – 128 GB | 512 MB | = RAM (max 8 GB) | rest | — | Comfortable |
| > 128 GB | 512 MB | = RAM (max 8 GB) | 60 GB | rest | Full |

> Supports both SATA/USB (`sdb1`, `sdb2`) and NVMe (`nvme0n1p1`, `nvme0n1p2`) naming automatically.

---

## 🎮 GPU Drivers (auto-detected)

| GPU | Packages installed |
|---|---|
| NVIDIA | `nvidia` `nvidia-utils` `nvidia-settings` `libva-nvidia-driver` |
| AMD / Radeon | `mesa` `vulkan-radeon` `libva-mesa-driver` `mesa-vdpau` `xf86-video-amdgpu` |
| Intel | `mesa` `vulkan-intel` `intel-media-driver` `libva-intel-driver` |

---

## 🖥️ Desktop Environments

| Option | DE | Display Manager | Notes |
|---|---|---|---|
| 1 | None / Minimal | — | CLI only |
| 2 | GNOME | GDM | Wayland session |
| 3 | KDE Plasma | SDDM | Wayland session |
| 4 | **Hyprland** | SDDM | Starter config included |

### Hyprland Default Keybinds

| Keys | Action |
|---|---|
| `Super + Enter` | Open terminal (kitty) |
| `Super + R` | App launcher (wofi) |
| `Super + Q` | Close window |
| `Super + V` | Toggle floating |
| `Super + 1–5` | Switch workspace |
| `Super + Shift + 1–5` | Move window to workspace |
| `Print` | Screenshot (region → clipboard) |
| `XF86AudioRaiseVolume/LowerVolume` | Volume control |
| `XF86MonBrightnessUp/Down` | Brightness control |

---

## 🔧 What Gets Installed (Base)

```
base  base-devel  linux  linux-firmware  linux-headers
networkmanager  firewalld  grub  efibootmgr
wayland  wayland-protocols  pipewire  wireplumber
mesa  vulkan-icd-loader  libva
sudo  git  wget  curl  vim  nano  htop  neofetch
+ CPU microcode  + GPU drivers  + chosen DE
```

---

## 📝 After First Boot

A `~/post-install.sh` script is left on your new system with reminders:

```bash
bash ~/post-install.sh
```

It covers:
- Installing an AUR helper (`yay`)
- Enabling NVIDIA DRM kernel mode (if applicable)
- Full system update
- Firewall status check

---

## 🪵 Logs

If anything goes wrong, the full install log is at:

```
/tmp/arch-install.log
```

---

## ⚠️ Disclaimer

This script **will erase all data** on the selected drive. Always double-check the target device before confirming. The author is not responsible for data loss.

---

## 📄 License

MIT — do whatever you want with it.

---

<div align="center">
Made for CachyOS / Arch users who like to carry their OS in their pocket.
</div>
