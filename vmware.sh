#!/bin/sh

if [ -z "$2" ]; then
	echo "Usage: $0 hostname user"
	exit 1
fi

CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

loadkeys fr

printf "${CYAN}[*] ${GREEN}Updating live system's keyring${NC}\n"
pacman -Sy --noconfirm archlinux-keyring

printf "${CYAN}[*] ${GREEN}Formatting disk${NC}\n"
## Pour deux partitions, une ESP, et un ext4 basique
#parted -s /dev/sda mklabel gpt mkpart primary fat32 1 500M mkpart primary ext4 500M "100%" set 1 boot on
# With swap
parted -s /dev/sda mklabel gpt mkpart primary fat32 1 500MB mkpart primary linux-swap 500M 2GB mkpart primary ext4 2GB "100%" set 1 boot on
mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/sda3

printf "${CYAN}[*] ${GREEN}Enabling swap partition${NC}\n"
mkswap /dev/sda2
swapon /dev/sda2

printf "${CYAN}[*] ${GREEN}Mounting system partitions${NC}\n"
mount /dev/sda3 /mnt
mkdir -p /mnt/boot
mount /dev/sda1 /mnt/boot

printf "${CYAN}[*] ${GREEN}Installing packages${NC}\n"
reflector --country France --latest 10 --sort rate --save /etc/pacman.d/mirrorlist 
pacstrap /mnt base base-devel linux-zen linux-firmware htop ntp net-tools vim amd-ucode efibootmgr nmap git openssh tmux lsb-release zsh fzf zsh-autosuggestions zsh-completions zsh-syntax-highlighting

printf "${CYAN}[*] ${GREEN}Generating fstab${NC}\n"
genfstab -U /mnt >> /mnt/etc/fstab

printf "${CYAN}[*] ${GREEN}Configuring languages, timezone, hostname${NC}\n"
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
arch-chroot /mnt hwclock --systohc
sed -i -e "s/#en_US.UTF-8/en_US.UTF-8/g" -e "s/#fr_FR.UTF-8/fr_FR.UTF-8/g" /mnt/etc/locale.gen

arch-chroot /mnt locale-gen
echo 'LANG="fr_FR.UTF-8"' > /mnt/etc/locale.conf
echo 'LANGUAGE="fr_FR"' >> /mnt/etc/locale.conf
echo 'KEYMAP=fr' > /mnt/etc/vconsole.conf 
echo "$1" > /mnt/etc/hostname
echo "127.0.0.1 $1" >> /mnt/etc/hosts

printf "${CYAN}[*] ${GREEN}Installing optionnal packages${NC}\n"
# VMware
pacstrap /mnt open-vm-tools xf86-input-vmmouse xf86-video-vmware mesa
# KDE
pacstrap /mnt plasma yakuake dolphin spectacle kate networkmanager ark gwenview kolourpaint filelight dolphin-plugins kwalletmanager kcalc kcharselect kdialog krdc ktorrent okular partitionmanager krdp
## KDE minimal? 
#pacstrap /mnt plasma-desktop sddm sddm-kcm konsole dolphin
# extra
pacstrap /mnt keepassxc firefox unzip discord docker dos2unix audacity filezilla gimp gnome-sound-recorder grc libreoffice-still ncdu networkmanager-openvpn obs-studio p7zip reflector rsync signal-desktop traceroute tree xclip zip vlc wget yt-dlp
## Gnome
#pacstrap /mnt gnome gnome-software-packagekit-plugin networkmanager
#Hyprland
pacstrap /mnt kitty hyprland 

printf "${CYAN}[*] ${GREEN}Configuring EFI boot${NC}\n"
efibootmgr --create --disk /dev/sda --part 1 --label "Arch Linux" --loader /vmlinuz-linux-zen --unicode 'root=/dev/sda3 rw initrd=\amd-ucode.img initrd=\initramfs-linux-zen.img'
efibootmgr -D

printf "${CYAN}[*] ${GREEN}Setting root password${NC}\n"
arch-chroot /mnt passwd

printf "${CYAN}[*] ${GREEN}Creating user $2 in wheel group${NC}\n"
arch-chroot /mnt useradd -m "$2"
arch-chroot /mnt usermod -a -G wheel "$2"
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /mnt/etc/sudoers
arch-chroot /mnt passwd "$2"

printf "${CYAN}[*] ${GREEN}Changing shell for root and user $2${NC}\n"
arch-chroot /mnt chsh "$2" -s /usr/bin/zsh
arch-chroot /mnt chsh root -s /usr/bin/zsh

printf "${CYAN}[*] ${GREEN}Installing Oh-My-ZSH for user $2${NC}\n"
arch-chroot /mnt su "$2" -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"' < /dev/null

printf "${CYAN}[*] ${GREEN}Enabling services${NC}\n"
arch-chroot /mnt systemctl enable fstrim.timer
arch-chroot /mnt systemctl enable sddm
arch-chroot /mnt systemctl enable NetworkManager
arch-chroot /mnt systemctl enable vmtoolsd

printf "${CYAN}[*] ${GREEN}Enabling autologin for user $2 in SDDM ${NC}\n"
mkdir /mnt/etc/sddm.conf.d/
cat <<EOT >> /mnt/etc/sddm.conf.d/kde_settings.conf
# [Autologin]
# Relogin=false
# Session=plasma
# User=$2

[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot

[Theme]
Current=

[Users]
MaximumUid=60513
MinimumUid=1000
EOT

mkdir -p /mnt/home/$2/.config/hypr
cat <<EOT >> /mnt/home/$2/.config/hypr/hyprland.conf
# This is an example Hyprland config file.
# Refer to the wiki for more information.
# https://wiki.hyprland.org/Configuring/

# Please note not all available settings / options are set here.
# For a full list, see the wiki

# You can split this configuration into multiple files
# Create your files separately and then link them to this file like this:
# source = ~/.config/hypr/myColors.conf


################
### MONITORS ###
################

# See https://wiki.hyprland.org/Configuring/Monitors/
monitor=,preferred,auto,auto


###################
### MY PROGRAMS ###
###################

# See https://wiki.hyprland.org/Configuring/Keywords/

# Set programs that you use
$terminal = kitty
$fileManager = dolphin
$menu = wofi --show drun


#################
### AUTOSTART ###
#################

# Autostart necessary processes (like notifications daemons, status bars, etc.)
# Or execute your favorite apps at launch like this:

# exec-once = $terminal
# exec-once = nm-applet &
# exec-once = waybar & hyprpaper & firefox


#############################
### ENVIRONMENT VARIABLES ###
#############################

# See https://wiki.hyprland.org/Configuring/Environment-variables/

env = XCURSOR_SIZE,24
env = HYPRCURSOR_SIZE,24


#####################
### LOOK AND FEEL ###
#####################

# Refer to https://wiki.hyprland.org/Configuring/Variables/

# https://wiki.hyprland.org/Configuring/Variables/#general
general {
    gaps_in = 5
    gaps_out = 20

    border_size = 2

    # https://wiki.hyprland.org/Configuring/Variables/#variable-types for info about colors
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)

    # Set to true enable resizing windows by clicking and dragging on borders and gaps
    resize_on_border = false

    # Please see https://wiki.hyprland.org/Configuring/Tearing/ before you turn this on
    allow_tearing = false

    layout = dwindle
}

# https://wiki.hyprland.org/Configuring/Variables/#decoration
decoration {
    rounding = 10

    # Change transparency of focused and unfocused windows
    active_opacity = 1.0
    inactive_opacity = 1.0

    shadow {
        enabled = true
        range = 4
        render_power = 3
        color = rgba(1a1a1aee)
    }

    # https://wiki.hyprland.org/Configuring/Variables/#blur
    blur {
        enabled = true
        size = 3
        passes = 1

        vibrancy = 0.1696
    }
}

# https://wiki.hyprland.org/Configuring/Variables/#animations
animations {
    enabled = yes, please :)

    # Default animations, see https://wiki.hyprland.org/Configuring/Animations/ for more

    bezier = easeOutQuint,0.23,1,0.32,1
    bezier = easeInOutCubic,0.65,0.05,0.36,1
    bezier = linear,0,0,1,1
    bezier = almostLinear,0.5,0.5,0.75,1.0
    bezier = quick,0.15,0,0.1,1

    animation = global, 1, 10, default
    animation = border, 1, 5.39, easeOutQuint
    animation = windows, 1, 4.79, easeOutQuint
    animation = windowsIn, 1, 4.1, easeOutQuint, popin 87%
    animation = windowsOut, 1, 1.49, linear, popin 87%
    animation = fadeIn, 1, 1.73, almostLinear
    animation = fadeOut, 1, 1.46, almostLinear
    animation = fade, 1, 3.03, quick
    animation = layers, 1, 3.81, easeOutQuint
    animation = layersIn, 1, 4, easeOutQuint, fade
    animation = layersOut, 1, 1.5, linear, fade
    animation = fadeLayersIn, 1, 1.79, almostLinear
    animation = fadeLayersOut, 1, 1.39, almostLinear
    animation = workspaces, 1, 1.94, almostLinear, fade
    animation = workspacesIn, 1, 1.21, almostLinear, fade
    animation = workspacesOut, 1, 1.94, almostLinear, fade
}

# Ref https://wiki.hyprland.org/Configuring/Workspace-Rules/
# "Smart gaps" / "No gaps when only"
# uncomment all if you wish to use that.
# workspace = w[tv1], gapsout:0, gapsin:0
# workspace = f[1], gapsout:0, gapsin:0
# windowrulev2 = bordersize 0, floating:0, onworkspace:w[tv1]
# windowrulev2 = rounding 0, floating:0, onworkspace:w[tv1]
# windowrulev2 = bordersize 0, floating:0, onworkspace:f[1]
# windowrulev2 = rounding 0, floating:0, onworkspace:f[1]

# See https://wiki.hyprland.org/Configuring/Dwindle-Layout/ for more
dwindle {
    pseudotile = true # Master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
    preserve_split = true # You probably want this
}

# See https://wiki.hyprland.org/Configuring/Master-Layout/ for more
master {
    new_status = master
}

# https://wiki.hyprland.org/Configuring/Variables/#misc
misc {
    force_default_wallpaper = -1 # Set to 0 or 1 to disable the anime mascot wallpapers
    disable_hyprland_logo = false # If true disables the random hyprland logo / anime girl background. :(
}


#############
### INPUT ###
#############

# https://wiki.hyprland.org/Configuring/Variables/#input
input {
    kb_layout = us
    kb_variant =
    kb_model =
    kb_options = altwin:swap_alt_win 
    kb_rules =

    follow_mouse = 1

    sensitivity = 0 # -1.0 - 1.0, 0 means no modification.

    touchpad {
        natural_scroll = false
    }
}

# https://wiki.hyprland.org/Configuring/Variables/#gestures
gestures {
    workspace_swipe = false
}

# Example per-device config
# See https://wiki.hyprland.org/Configuring/Keywords/#per-device-input-configs for more
device {
    name = epic-mouse-v1
    sensitivity = -0.5
}


###################
### KEYBINDINGS ###
###################

# See https://wiki.hyprland.org/Configuring/Keywords/
$mainMod = SUPER # Sets "Windows" key as main modifier

# Example binds, see https://wiki.hyprland.org/Configuring/Binds/ for more
bind = $mainMod, Q, exec, $terminal
bind = $mainMod, C, killactive,
bind = $mainMod, M, exit,
bind = $mainMod, E, exec, $fileManager
bind = $mainMod, V, togglefloating,
bind = $mainMod, R, exec, $menu
bind = $mainMod, P, pseudo, # dwindle
bind = $mainMod, J, togglesplit, # dwindle

# Move focus with mainMod + arrow keys
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Switch workspaces with mainMod + [0-9]
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

# Move active window to a workspace with mainMod + SHIFT + [0-9]
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10

# Example special workspace (scratchpad)
bind = $mainMod, S, togglespecialworkspace, magic
bind = $mainMod SHIFT, S, movetoworkspace, special:magic

# Scroll through existing workspaces with mainMod + scroll
bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up, workspace, e-1

# Move/resize windows with mainMod + LMB/RMB and dragging
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

# Laptop multimedia keys for volume and LCD brightness
bindel = ,XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
bindel = ,XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindel = ,XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindel = ,XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
bindel = ,XF86MonBrightnessUp, exec, brightnessctl s 10%+
bindel = ,XF86MonBrightnessDown, exec, brightnessctl s 10%-

# Requires playerctl
bindl = , XF86AudioNext, exec, playerctl next
bindl = , XF86AudioPause, exec, playerctl play-pause
bindl = , XF86AudioPlay, exec, playerctl play-pause
bindl = , XF86AudioPrev, exec, playerctl previous

##############################
### WINDOWS AND WORKSPACES ###
##############################

# See https://wiki.hyprland.org/Configuring/Window-Rules/ for more
# See https://wiki.hyprland.org/Configuring/Workspace-Rules/ for workspace rules

# Example windowrule v1
# windowrule = float, ^(kitty)$

# Example windowrule v2
# windowrulev2 = float,class:^(kitty)$,title:^(kitty)$

# Ignore maximize requests from apps. You'll probably like this.
windowrulev2 = suppressevent maximize, class:.*

# Fix some dragging issues with XWayland
windowrulev2 = nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0


EOT

printf "${CYAN}[*] ${GREEN}Unmounting partitions ${NC}\n"
umount /dev/sda1
umount /dev/sda3

printf "${CYAN}[*] ${GREEN}Done. To have french keyboard in SDDM, run this as root after reboot : localectl set-x11-keymap fr${NC}\n"



###############################################
# Original:

## on reste volontairement en clavier qwerty pour taper le mot de passe luks tel quel
#
## on partitionne d'abord le disque avec fdisk
## une partition efi de 500m ou 1g et le reste en btrfs
#fdisk -l
#
#
## Pour deux partitions, une ESP, et un ext4 basique
#parted -s /dev/sda mklabel gpt mkpart primary fat32 1 500M mkpart primary 
#ext4 500M "100%" set 1 boot on
## Sinon: 
#fdisk /dev/sda
#mkfs.fat -F32 /dev/sda1
#
## création du conteneur luks en luks1 pour la compat avec grub2
#cryptsetup --type luks1 luksFormat /dev/sda2
#
## on déverrouille, formatte et monte le fs
#cryptsetup open /dev/sda2 luks
#mkfs.btrfs -L btrfs_root /dev/mapper/luks 
#mount /dev/mapper/luks /mnt
#
## on crée les volumes btrfs
#btrfs subvolume create /mnt/@
#btrfs subvolume create /mnt/@home
## btrfs subvolume create /mnt/@snapshots # plus besoin
#
## on démonte et on remonte comme dans la configuration cible
#umount /mnt
#mount -o compress=zstd,subvol=@,ssd,noatime /dev/mapper/luks /mnt
#mkdir -p /mnt/home /mnt/boot/EFI
#mount -o compress=zstd,subvol=@home,ssd,noatime /dev/mapper/luks /mnt/home
#mount /dev/sda1 /mnt/boot/EFI
#
## Installation des packages
#reflector --country France --country Germany --latest 10 --sort rate --save /etc/pacman.d/mirrorlist 
#pacstrap /mnt base base-devel linux linux-firmware btrfs-progs snapper htop net-tools vim intel-ucode grub grub-btrfs efibootmgr nmap git openssh tmux lsb-release zsh fzf zsh-autosuggestions zsh-completions zsh-syntax-highlighting
#
## Génération fstab
#genfstab -U /mnt >> /mnt/etc/fstab
#
## configuration langues, timezone, hostname
#arch-chroot /mnt
#ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
#hwclock --systohc
#sed -i -e "s/#en_US.UTF-8/en_US.UTF-8/g" -e "s/#fr_FR.UTF-8/fr_FR.UTF-8/g" /etc/locale.gen
#
#locale-gen
#echo 'LANG="fr_FR.UTF-8"' > /etc/locale.conf
#echo 'LANGUAGE="fr_FR"' >> /etc/locale.conf
#echo 'KEYMAP=fr' > /etc/vconsole.conf 
#echo 'hostname' > /etc/hostname
#echo '127.0.0.1 hostname' >> /etc/hosts
#exit 
#
## VMware
#pacstrap /mnt open-vm-tools xf86-input-vmmouse xf86-video-vmware mesa
## KDE
#pacstrap /mnt plasma yakuake dolphin spectacle kate networkmanager 
## KDE minimal? 
#pacstrap /mnt plasma-desktop sddm sddm-kcm konsole dolphin
## extra
#pacstrap /mnt firefox unzip gparted
## Gnome
#pacstrap /mnt gnome gnome-software-packagekit-plugin networkmanager
#
## configuration de l'initramfs (/etc/mkinitcpio.conf) 
#BINARIES=(/usr/bin/btrfs)
#FILES=(/crypto_keyfile.bin)
#HOOKS="base udev autodetect modconf block encrypt filesystems keyboard fsck" 
#
## création d'un fichier clé qui sera dans l'initramfs
#dd bs=512 count=4 if=/dev/random of=/mnt/crypto_keyfile.bin
#cryptsetup luksAddKey /dev/sda2 /mnt/crypto_keyfile.bin 
#arch-chroot /mnt
#mkinitcpio -P
#chmod 000 /crypto_keyfile.bin
#
## configuration de grub /etc/default/grub 
#GRUB_ENABLE_CRYPTODISK=y
#GRUB_CMDLINE_LINUX="cryptdevice=/dev/sda2:luks" 
#
#grub-install --target=x86_64-efi --efi-directory=/boot/EFI --bootloader-id=BOOT
#grub-mkconfig -o /boot/grub/grub.cfg
#
## gestion users
#passwd
#useradd -m almazys
#passwd almazys
#
## pour le trim
#systemctl enable fstrim.timer
#
## optionnel
#systemctl enable sddm
#systemctl enable NetworkManager
#systemctl enable vmtoolsd
#localectl set-x11-keymap fr
