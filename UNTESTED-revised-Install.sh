#!/bin/bash

set -e

# =======================
# System Configuration
# =======================

# DNF Configuration
echo "Configuring DNF..."
sudo tee -a /etc/dnf/dnf.conf <<EOF
fastestmirror=1
max_parallel_downloads=10
defaultyes=True
keepcache=True
EOF

# Update Package Metadata
echo "Updating package metadata..."
sudo dnf update -y

# System Upgrade
echo "Upgrading system..."
sudo dnf upgrade --refresh -y

# Add RPM Fusion Repositories
echo "Adding RPM Fusion repositories..."
sudo dnf install -y \
    https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Install Core CLI Tools
echo "Installing core CLI tools..."
sudo dnf install -y \
    zsh \
    neofetch \
    htop \
    glances \
    bpytop \
    lm_sensors \
    gparted \
    virt-manager \
    qemu-kvm \
    libvirt \
    libvirt-python \
    libguestfs-tools \
    bridge-utils \
    cockpit \
    nmap \
    wireshark \
    git \
    curl \
    wget \
    thermald \
    tlp

# Install and Configure ZRAM
echo "Installing and configuring ZRAM..."
sudo dnf install -y zram-generator
sudo tee /etc/systemd/zram-generator.conf > /dev/null <<EOF
[zram0]
zram-size = min(ram, 4096)
compression-algorithm = zstd
EOF
sudo systemctl daemon-reload
sudo systemctl start systemd-zram-setup@zram0.service

# =======================
# Application Installation
# =======================

# Install Core Flatpaks
echo "Installing essential Flatpaks..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub \
    com.github.finefindus.eyedropper \
    com.github.tchx84.Flatseal \
    com.github.wwmm.easyeffects \
    com.obsproject.Studio \
    com.obsproject.Studio.Plugin.OBSVkCapture \
    com.visualstudio.code \
    com.valvesoftware.Steam \
    net.lutris.Lutris \
    network.loki.Session \
    org.blender.Blender \
    org.freedesktop.Platform.VulkanLayer.MangoHud \
    org.freedesktop.Platform.VulkanLayer.OBSVkCapture \
    org.gnome.World.PikaBackup \
    org.mozilla.Thunderbird \
    org.pipewire.Helvum \
    org.signal.Signal \
    md.obsidian.Obsidian \
    com.jgraph.drawio.desktop \
    org.gimp.GIMP \
    org.videolan.VLC \
    io.github.shiftey.Desktop \
    org.nmap.Zenmap \
    org.remmina.Remmina \
    com.teamspeak.TeamSpeak \
    dev.vencord.Vesktop \
    com.spotify.Client \
    com.heroicgameslauncher.hgl

# Configure Flatpak to Use System Themes
echo "Configuring Flatpak to use system themes..."
sudo dnf install -y gnome-themes-standard adwaita-gtk2-theme adwaita-gtk3-theme papirus-icon-theme
flatpak override --user --env=GTK_THEME=Adwaita:dark
flatpak override --user --env=ICON_THEME=Papirus

# =======================
# Optimization
# =======================

# Debloat
echo "Removing unnecessary packages..."
sudo dnf -y remove \
    ModemManager \
    adcli \
    anaconda* \
    anthy-unicode \
    atmel-firmware \
    eog \
    libertas-usb8388-firmware \
    orca \
    ppp \
    pptp

# Performance Optimization
echo "Optimizing system performance..."
# Disable GNOME Animations
gsettings set org.gnome.desktop.interface enable-animations false
# Configure Swappiness
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf
sudo sysctl -p /etc/sysctl.d/99-swappiness.conf
# Mask and Stop Tracker
systemctl --user mask tracker-miner-fs-3
systemctl --user stop tracker-miner-fs-3
systemctl --user mask tracker-store
systemctl --user stop tracker-store
# Disable and Mask Bluetooth
# sudo systemctl disable bluetooth.service
# sudo systemctl mask bluetooth.service
# Enable TLP and Thermald
echo "Configuring TLP and Thermald..."
sudo systemctl enable tlp
sudo systemctl start tlp
sudo systemctl enable thermald
sudo systemctl start thermald

# GNOME Wayland Fractional Scaling
echo "Enabling Wayland fractional scaling..."
gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer', 'fractional-scaling']"
gsettings set org.gnome.desktop.interface scaling-factor 2

# Automatic Updates
echo "Configuring automatic updates..."
sudo dnf install -y dnf-automatic
sudo systemctl enable --now dnf-automatic.timer

# =======================
# NVIDIA Drivers and CUDA
# =======================

# Check Secure Boot Status and User Confirmation
echo "Checking Secure Boot status..."
if mokutil --sb-state | grep -q 'Secure Boot: Enabled'; then
    echo "Secure Boot is enabled. This may affect NVIDIA driver installation."
    read -p "Do you want to proceed with NVIDIA driver installation? (yes/no): " user_response
    if [[ "$user_response" != "yes" ]]; then
        echo "Skipping NVIDIA driver installation and hardware acceleration configuration."
        skip_nvidia=true
    else
        skip_nvidia=false
    fi
else
    echo "Secure Boot is not enabled. Proceeding with NVIDIA driver installation."
    skip_nvidia=false
fi

# Install Nvidia Drivers and CUDA (if not skipped)
if [ "$skip_nvidia" != true ]; then
    echo "Installing Nvidia drivers and CUDA..."
    sudo dnf install -y \
        akmod-nvidia \
        xorg-x11-drv-nvidia-cuda \
        xorg-x11-drv-nvidia-cuda-libs \
        svt-hevc \
        svt-av1 \
        svt-vp9 \
        nvidia-vaapi-driver \
        libva-utils

    # Check NVIDIA Driver Installation
    echo "Checking if NVIDIA drivers are installed..."
    MAX_RETRIES=12
    RETRY_INTERVAL=30
    for ((i=1; i<=MAX_RETRIES; i++)); do
        if command -v nvidia-smi >/dev/null 2>&1; then
            echo "NVIDIA drivers are installed. Verifying..."
            if nvidia-smi >/dev/null 2>&1; then
                echo "NVIDIA drivers are working correctly."
                break
            else
                echo "NVIDIA drivers seem to be installed but 'nvidia-smi' is not working. Waiting..."
                sleep $RETRY_INTERVAL
            fi
        else
            echo "NVIDIA drivers are not installed. Please ensure they are installed correctly."
            exit 1
        fi
    done

    if ((i > MAX_RETRIES)); then
        echo "NVIDIA drivers verification failed after several attempts. Please check your installation manually."
        exit 1
    fi

    # Configure Hardware Acceleration
    echo "Configuring hardware acceleration..."
    sudo dnf config-manager --set-enabled fedora-cisco-openh264
    sudo dnf install -y \
        ffmpeg \
        ffmpeg-libs \
        libva \
        libva-utils \
        openh264 \
        gstreamer1-plugin-openh264 \
        mozilla-openh264
fi

# =======================
# Final Checks and Reboot
# =======================

# Cleanup
echo "Cleaning up..."
sudo dnf autoremove -y
sudo dnf clean all

# Reboot Prompt
echo "Setup complete! It's recommended to reboot your system now."

