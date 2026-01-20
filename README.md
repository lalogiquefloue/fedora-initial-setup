# Fedora Setup Script

Work in progress. Since I sometimes like to distro hop but usually come back to Fedora for my ready-to-go productive environment, I made this script to quickly rebuild the essentials of my setup after a fresh install. It should be easy to extend and adapt to your own preferences.

## Usage

1. Clone this repository
```bash
git clone https://github.com/lalogiquefloue/fedora-initial-setup.git
cd fedora-initial-setup
```

2. Make the script executable
```bash
chmod +x fedora_setup.sh
```

3. Run as root
```bash
sudo ./fedora_setup.sh
```

## Features

### System Setup
- **Flatpak support**: Installs Flatpak if not present and adds Flathub repository
- **RPM Fusion**: Automatically enables RPM Fusion free and nonfree repositories
- **System updates**: Full system package update and upgrade

### Package Management
- **Batch DNF installation**: Install multiple DNF packages from a `dnf_packages` file
- **Batch Flatpak installation**: Install multiple Flatpaks from a `flatpaks` file
- **NVIDIA driver detection**: Automatically detects NVIDIA GPUs and installs appropriate drivers

### Software Installation
- **Visual Studio Code**: Complete setup with Microsoft repository configuration
- **Multimedia codecs**: Install multimedia codec group for media playback
- **Tailscale**: VPN mesh network installation and systemd service enablement
- **Insync**: Google Drive/OneDrive sync client installation

### Development Tools
- **C/C++ environment**: Installs development-tools group, clang, gdb, valgrind, and debugging utilities
- More to come...

## Extending the Script

### Adding DNF Packages
Create or edit a `dnf_packages` file in the same directory:
```
# Comments are supported
vim
git
```

### Adding Flatpaks
Create or edit a `flatpaks` file in the same directory:
```
# Comments are supported
com.spotify.Client
org.gimp.GIMP
```