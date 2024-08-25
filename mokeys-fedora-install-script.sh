#!/bin/bash

# Set Downloads in DNF
printf "%s" "
fastestmirror=1
max_parallel_downloads=10
countme=false
" | sudo tee -a /etc/dnf/dnf.conf

# Install RPM Fusion Free Repositories
sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Install app stream meta-data
sudo dnf group update core -y

#Update and Upgrade
sudo dnf -y update
sudo dnf -y upgrade --refresh

# GNOME SETTINGS
# Setting Gnome Menu to stay true during scaling
gsettings set org.gnome.desktop.a11y always-show-universal-access-status true
# Setting minimize, maximize, and close buttons for windows
gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
# Setting clock to show weekday on gnome interface
gsettings set org.gnome.desktop.interface clock-show-weekday true
# Setting clock to show seconds on gnome interface
gsettings set org.gnome.desktop.interface clock-show-seconds true
# Enabling scaling
gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"

#Firmware Updates
sudo dnf autoremove -y
sudo fwupdmgr refresh --force
sudo fwupdmgr get-devices
sudo fwupdmgr get-updates -y
sudo fwupdmgr update -y

#Add Flatpak Repositories
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Nvidia Drivers
sudo dnf -y update
sudo dnf install akmod-nvidia
sudo dnf install -y xorg-x11-drv-nvidia-cuda xorg-x11-drv-nvidia-cuda-libs svt-hevc svt-av1 svt-vp9 nvidia-vaapi-driver libva-utils


#Media Codecs
sudo dnf swap 'ffmpeg-free' 'ffmpeg' --allowerasing
sudo dnf update @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin
sudo dnf update @sound-and-video
sudo dnf group install Multimedia

# Hardware accelleration
sudo dnf install ffmpeg ffmpeg-libs libva libva-utils
sudo dnf config-manager --set-enabled fedora-cisco-openh264
sudo dnf install -y openh264 gstreamer1-plugin-openh264 mozilla-openh264

# Install Flatpaks
mokey_flathub () {
	log "mokey_flathub"
	local -a mokey_flathub_install
	mokey_flathub_install=(
	"com.github.finefindus.eyedropper"
	"com.github.tchx84.Flatseal"
	"com.github.wwmm.easyeffects"
	"com.obsproject.Studio"
	"com.obsproject.Studio.Plugin.OBSVkCapture"
	"com.visualstudio.code"
	"com.valvesoftware.Steam"
	"net.lutris.Lutris"
	"network.loki.Session"
	"org.blender.Blender"
	"org.freedesktop.Platform.VulkanLayer.MangoHud"
	"org.freedesktop.Platform.VulkanLayer.OBSVkCapture"
	"org.gnome.World.PikaBackup"
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
#	---- Optional, Already installed non-flatpaks. Remove RPMs prior to installing---- 
#	"org.getmonero.Monero"
#	"org.gnome.Boxes"
#	"org.gnome.Calculator"
#	"org.gnome.Calendar"
#	"org.gnome.Characters"
#	"org.gnome.Connections"
#	"org.gnome.Contacts"
#	"org.gnome.Evince"
#	"org.gnome.Extensions"
#	"org.gnome.font-viewer"
#	"org.gnome.Logs"
#	"org.gnome.Loupe"
#	"org.gnome.Maps"
#	"org.mozilla.firefox"
)
flatpak install -y flathub ${mokey_flathub_install[*]}
}
mokey_flathub
