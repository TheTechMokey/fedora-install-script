#!/bin/bash

set -e          # Exit on any error
set -o pipefail # Exit if any command in a pipe fails

# Helper function to log messages
log() {
    echo "[INFO] $1"
    logger -t script "[INFO] $1" # Log to system log
}

error() {
    echo "[ERROR] $1"
    logger -t script "[ERROR] $1" # Log to system log
}

# Function to check Secure Boot status
check_secure_boot() {
    log "Checking Secure Boot status..."

    if ! command -v mokutil &>/dev/null; then
        error "mokutil is not installed. Please install mokutil to check Secure Boot status."
        exit 1
    fi

    if mokutil --sb-state | grep -q 'Secure Boot enabled'; then
        log "Secure Boot is enabled."
        read -p "This script was designed to run without Secure Boot. Secure Boot is enabled, would you like to continue? [y/N]: " choice
        case "$choice" in
        [Yy]*) log "Continuing with Secure Boot enabled." ;;
        *)
            log "Exiting script."
            exit 1
            ;;
        esac
    else
        log "Secure Boot is not enabled. Proceeding with the script."
    fi
}

# Modify DNF configuration
configure_dnf() {
    log "Configuring DNF..."

    tmp_file=$(mktemp)

    if ! grep -q '^fastestmirror=1' /etc/dnf/dnf.conf; then
        echo "fastestmirror=1" | sudo tee -a "$tmp_file"
    fi

    if ! grep -q '^max_parallel_downloads=10' /etc/dnf/dnf.conf; then
        echo "max_parallel_downloads=10" | sudo tee -a "$tmp_file"
    fi

    if ! grep -q '^countme=false' /etc/dnf/dnf.conf; then
        echo "countme=false" | sudo tee -a "$tmp_file"
    fi

    if [ -s "$tmp_file" ]; then
        sudo tee -a /etc/dnf/dnf.conf <"$tmp_file"
    else
        log "No new DNF settings to add."
    fi

    rm -f "$tmp_file"
}

# Install RPM Fusion repositories
install_rpm_fusion() {
    log "Installing RPM Fusion repositories..."
    if ! sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm; then
        error "Failed to install RPM Fusion repositories."
        exit 1
    fi
}

# Update and upgrade system
update_system() {
    log "Updating the system..."
    if ! sudo dnf -y update && sudo dnf -y upgrade --refresh; then
        error "Failed to update and upgrade the system."
        exit 1
    fi
}

configure_gnome() {
    log "Configuring GNOME settings..."

    # Set dark theme (equivalent of Breeze Dark for KDE)
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'

    # Enable Night Light
    gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled true

    # Set clock to show seconds
    gsettings set org.gnome.desktop.interface clock-show-seconds true

    # Example: Set resolution scaling for a specific monitor using xrandr
    # First, find the connected monitors
    connected_monitors=$(xrandr --listmonitors | grep -oP '\S+(?=\s+\d)')

    # Apply resolution scaling to a specific monitor (change "HDMI-1" to your desired monitor identifier)
    monitor_to_scale="HDMI-1"  # Example: use xrandr to list monitors and choose the correct one
    scale_factor="1.25"  # Example scale factor

    if echo "$connected_monitors" | grep -q "$monitor_to_scale"; then
        log "Applying resolution scaling of $scale_factor to $monitor_to_scale..."
        xrandr --output "$monitor_to_scale" --scale "${scale_factor}x${scale_factor}"
    else
        log "Monitor $monitor_to_scale not found, skipping resolution scaling."
    fi

    # Additional GNOME configurations can go here
}

# Firmware updates
update_firmware() {
    log "Updating firmware..."
    if ! sudo dnf autoremove -y && sudo fwupdmgr refresh --force && sudo fwupdmgr get-devices && sudo fwupdmgr get-updates -y && sudo fwupdmgr update -y; then
        error "Failed to update firmware."
        exit 1
    fi
}

# Add Flatpak repositories
add_flatpak_repositories() {
    log "Adding Flatpak repositories..."
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}

# Install Nvidia drivers
install_nvidia_drivers() {
    log "Installing Nvidia drivers..."
    if ! sudo dnf -y update && sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda xorg-x11-drv-nvidia-cuda-libs \
        svt-hevc svt-av1 svt-vp9 nvidia-vaapi-driver libva-utils; then
        error "Failed to install Nvidia drivers."
        exit 1
    fi
}

# Install media codecs
install_media_codecs() {
    log "Installing media codecs..."
    if ! sudo dnf swap 'ffmpeg-free' 'ffmpeg' --allowerasing && sudo dnf update @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin && sudo dnf update @sound-and-video && sudo dnf group install Multimedia; then
        error "Failed to install media codecs."
        exit 1
    fi
}

# Enable hardware acceleration
install_hardware_acceleration() {
    log "Enabling hardware acceleration..."
    if ! sudo dnf install -y ffmpeg ffmpeg-libs libva libva-utils && sudo dnf config-manager --set-enabled fedora-cisco-openh264 && sudo dnf install -y openh264 gstreamer1-plugin-openh264 mozilla-openh264; then
        error "Failed to enable hardware acceleration."
        exit 1
    fi
}

# Install Flatpak Applications
install_flatpak_apps() {
    log "Installing Flatpak applications..."
    local -a mokey_flathub_install=(
        "com.github.finefindus.eyedropper"
        "com.github.tchx84.Flatseal"
        "com.github.wwmm.easyeffects"
        "com.obsproject.Studio"
        "com.obsproject.Studio.Plugin.OBSVkCapture"
        "org.freedesktop.Platform.VulkanLayer.OBSVkCapture"
        "oject.Studio.Plugin.GStreamerVaapi"
        "com.obsproject.Studio.Plugin.Gstreamer"
        "com.visualstudio.code"
        "com.valvesoftware.Steam"
        "network.loki.Session"
        "org.blender.Blender"
        "org.freedesktop.Platform.VulkanLayer.MangoHud"
        "org.mozilla.Thunderbird"
        "org.pipewire.Helvum"
        "org.signal.Signal"
        "md.obsidian.Obsidian"
        "com.jgraph.drawio.desktop"
        "org.gimp.GIMP"
        "org.videolan.VLC"
        "io.github.shiftey.Desktop"
        "org.nmap.Zenmap"
        "org.remmina.Remmina"
        "com.teamspeak.TeamSpeak"
        "dev.vencord.Vesktop"
        "com.spotify.Client"
        "com.heroicgameslauncher.hgl"
        "com.jetbrains.IntelliJ-IDEA-Community"
        "com.jetbrains.PyCharm-Community"
        "com.axosoft.GitKraken"
        "com.getpostman.Postman"
        "io.dbeaver.DBeaverCommunity"
        "org.wireshark.Wireshark"
        "com.github.mtkennerly.ludusavi"
        "com.valvesoftware.SteamLink"
        "org.tenacityaudio.Tenacity"
    )
    flatpak install -y flathub "${mokey_flathub_install[@]}"
}

install_steam() {
    log "Installing Steam..."
    sudo dnf install -y steam
}

install_wine_proton_dependencies() {
    log "Installing Wine and Proton dependencies..."

    sudo dnf install -y steam wine lutris wine-core wine-common wine-alsa \
        wine-tahoma-fonts vulkan vulkan-tools vulkan-loader \
        libvkd3d SDL2 SDL2_image SDL2_ttf SDL2_mixer SDL2_net
}

install_gamemode() {
    log "Installing and configuring Gamemode..."
    if ! sudo dnf install -y gamemode; then
        error "Failed to install Gamemode."
        exit 1
    fi

    log "Enabling Gamemode globally..."
    echo "export LD_PRELOAD=/usr/\$LIB/libgamemodeauto.so.0" | sudo tee -a /etc/environment
}

configure_mangohud() {
    log "Configuring MangoHud..."
    echo "MANGOHUD=1" | sudo tee -a /etc/environment
}

# Verify Nvidia installation
verify_nvidia() {
    log "Verifying Nvidia installation... This could take up to 5 minutes."

    local retries=12
    local wait_time=30
    local success=false

    for ((i = 1; i <= retries; i++)); do
        if lsmod | grep -q nvidia; then
            log "Nvidia kernel module is loaded."

            if command -v nvidia-smi &>/dev/null; then
                if sudo nvidia-smi &>/dev/null; then
                    log "Nvidia driver installation verified successfully with 'nvidia-smi'."
                    success=true
                    break
                else
                    error "Nvidia driver installation verification failed with 'nvidia-smi'."
                fi
            else
                error "'nvidia-smi' command not found. Please check if the Nvidia drivers are installed correctly."
            fi
        else
            log "Nvidia kernel module is not loaded yet. Retrying in $wait_time seconds..."
        fi

        sleep $wait_time
    done

    if [ "$success" = true ]; then
        log "Nvidia drivers are properly installed and working."
    else
        error "Nvidia driver installation failed after $((retries * wait_time)) seconds. Please check system logs for more details."
        exit 1
    fi
}

# Main script execution
main() {
    check_secure_boot
    configure_dnf
    install_rpm_fusion
    update_system
    configure_gnome
    update_firmware
    add_flatpak_repositories
    install_nvidia_drivers
    install_media_codecs
    install_hardware_acceleration
    install_flatpak_apps
    install_gamemode
    configure_mangohud
    install_steam
    install_wine_proton_dependencies
    verify_nvidia
}

main

