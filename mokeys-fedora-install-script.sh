#!/bin/bash

echo "Setting up fast mirror max parallel downloads"
# Configure dnf (In order: automatically select fastest mirror, parallel downloads, and disable telemetry)
# fastestmirror=1
printf "%s" "
fastestmirror=1
max_parallel_downloads=10
countme=false
" | sudo tee -a /etc/dnf/dnf.conf

echo "Setting up RPM Fusion Repository"
# Setup RPMFusion
sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-"$(rpm -E %fedora)".noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-"$(rpm -E %fedora)".noarch.rpm
echo "Initiating dnf group update"
sudo dnf groupupdate core -y

echo "Upgrading packages"
# echo 'Make sure your system has been fully-updated by running "sudo dnf upgrade -y" and reboot it once.'
sudo dnf upgrade -y

systemctl daemon-reload

echo "Setting umask Permissions"
#Setting umask to 077
# No one except wheel user and root get read/write files
umask 077
sudo sed -i 's/umask 022/umask 077/g' /etc/bashrc

#Removing unwanted things
echo "Removing unwanted things"
mokey_debloat () {
	log "mokey_debloat"
	local -a mokey_debloating_stuff
	mokey_debloating_stuff=(
	"ModemManager"
	"adcli"
	"alsa-sof-firmware"
	"anaconda*"
	"anthy-unicode"
	"atmel-firmware"
	"avahi"
	"baobab"
	"boost-date-time"
	"brasero-libs"
	"cheese"
	"cyrus-sasl-plain"
	"dos2unix"
	"eog"
	"evince"
	"evince-djvu"
	"fedora-bookmarks"
	"fedora-chromium-config"
	"geolite2*"
#	"gnome-backgrounds"
#	"gnome-boxes"
#	"gnome-calculator"
#	"gnome-calendar"
#	"gnome-characters"
#	"gnome-classic-session"
#	"gnome-clocks"
#	"gnome-color-manager"
#	"gnome-connections"
#	"gnome-contacts"
#	"gnome-font-viewer"
#	"gnome-logs"
#	"gnome-maps"
#	"gnome-remote-desktop"
#	"gnome-shell-extension*"
#	"gnome-shell-extension-background-logo"
#	"gnome-themes-extra"
#	"gnome-user-docs"
#	"gnome-weather"
	"hyperv*"
	"kpartx"
	"libertas-usb8388-firmware"
	"loupe"
	"mailcap"
	"mozilla-filesystem"
	"mtr"
	"ppp"
	"pptp"
	"qemu-guest-agent"
	"qgnomeplatform"
	"realmd"
	"rsync"
	"sane*"
	"simple-scan"
	"snapshot"
	"sos"
	"teamd"
	"thermald"
	"totem"
	"trousers"
	"unbound-libs"
	"vpnc"
	"xorg-x11-drv-vmware"
	"yajl"
	"yelp"
	"zd1211-firmware"
)
sudo dnf -y rm ${mokey_debloating_stuff[*]}
}
mokey_debloat


echo "Autoremoving unnecessary dependency packages"
sudo dnf autoremove -y
echo "updating firmware"
sudo fwupdmgr get-devices
sudo fwupdmgr refresh --force
sudo fwupdmgr get-updates -y
sudo fwupdmgr update -y

# Configure GNOME
echo "Configuring Gnome and extensions"
echo "Setting Gnome Menu to stay true during scaling"
gsettings set org.gnome.desktop.a11y always-show-universal-access-status true
echo "Setting minimize, maximize, and close buttons for windows"
gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
echo "Setting clock to show weekday on gnome interface"
gsettings set org.gnome.desktop.interface clock-show-weekday true
echo "Setting clock to show seconds on gnome interface"
gsettings set org.gnome.desktop.interface clock-show-seconds true
echo "Enabling scaling"
gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"

# Setup Flathub beta and third party packages
echo "Enabling fedora third party repositories"
sudo fedora-third-party enable
echo "Refreshing third party repositories"
sudo fedora-third-party refresh
echo "adding flatpak repository"
flatpak remote-add --if-not-exists flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo

# Install my things from flathub
echo "Installing custom flatpak packages"
mokey_flathub () {
	log "mokey_flathub"
	local -a mokey_flathub_install
	mokey_flathub_install=(
	"ch.protonmail.protonmail-bridge"
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
	"org.getmonero.Monero"
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
	"org.mozilla.firefox"
	"com.spotify.Client"
)
flatpak install -y flathub ${mokey_flathub_install[*]}
}
mokey_flathub

# Install Repos, Codecs, Drivers
echo "Installing fedora multimedia repository"
sudo dnf config-manager --add-repo=https://negativo17.org/repos/fedora-multimedia.repo
echo "Installing plugins and codecs"
sudo dnf install -y dnf-plugins-core steam-devices xorg-x11-drv-nvidia-cuda-libs svt-hevc svt-av1 svt-vp9 nvidia-vaapi-driver libva-utils ffmpeg mpv smplayer compat-ffmpeg4 akmod-v4l2loopback @virtualization guestfs-tools podman simple-scan --best --allowerasing
sudo dnf install xorg-x11-drv-nvidia-cuda-libs svt-hevc svt-av1 svt-vp9 nvidia-vaapi-driver libva-utils
echo "swapping mesa-va-drivers to mesa-va-drivers-freeworld"
sudo dnf swap mesa-va-drivers mesa-va-drivers-freeworld

# Initialize virtualization
echo "Initiliazing virtaulization"
sudo sed -i 's/#unix_sock_group = "libvirt"/unix_sock_group = "libvirt"/g' /etc/libvirt/libvirtd.conf
sudo sed -i 's/#unix_sock_rw_perms = "0770"/unix_sock_rw_perms = "0770"/g' /etc/libvirt/libvirtd.conf
sudo systemctl enable libvirtd
sudo usermod -aG libvirt "$(whoami)"

echo "Final update and cleanup"
sudo dnf autoremove -y
sudo dnf update -y
sudo dnf upgrade -y
systemctl daemon-reload

echo "The configuration is now complete and will now reboot in 30 seconds"
sleep 30
sudo reboot