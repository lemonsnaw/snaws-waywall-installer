# Snaws waywall install script

## Disclaimer
This script is provided as-is, without warranty. It will install system packages, changes configurations to limited scope as well, **will** uninstall Flatpak Prism launcher (backup is taken at runtime) and I am putting decent amount of measures to have your configs backed up before doing any operations still taking backup is highly recommended, I will not be responsible in case any issues arise with system after running it.

## Supported OS
- Fedora/Nobara (42,43,44+)
- Ubuntu 26.01+
- Debian 13+

## Purpose
This is script does following:
- Download and setup default JDK to avoid issue related to headless JDK
- Download and install Prism launcher (removes flatpak prism after taking backup and skips if already installed)
- Downloads and install waywall (skips if already installed)
- Downloads [Gores Generic Config](https://github.com/arjuncgore/waywall_config) sets it up for waywall.
- Configures your minecraft instance to use waywall ( wrapper and glfw setup)
- Setup Ninjabrain bot for boateye (godsens,greenboat,std deviation etc).

    ( **doesnt set sensitivies in waywall** , you have to do it manually.
    Please check guide here https://its-saanvi.github.io/linux-mcsr/minecraft/wayland/boat-eye.html)
- Additional can setup [plug.waywall](https://github.com/its-saanvi/plug.waywall) , for easily adding plugins. This is optional and can be added later.


## How to use 
1. Download the `setup.zip` from releases and extract it and open terminal in the same folder.
3. Run following command to mark it as executable `chmod +x setup.sh`.
4. Run the script `./setup.sh` in terminal and follow onscreen instructions


The main menu provides two paths:

1. Waywall and Prism setup( for fresh and existing install as well)
2. Generic config plugins using plug.waywall

Currently Added plugins:
- Show Ninjabrain bot on f3+c (https://github.com/lemonsnaw/ww_ninbot_f3c)
- Oneshot crosshair (https://github.com/lemonsnaw/ww_oneshot_crosshair)

## Current development plans:
- Port Arch and archbased distro
- Bazzite Support(?)
- Plugins URI support ( to add plugins which are not hardcoded) in plugins folder.


## Thanks!
- [woofdoggo](https://github.com/tesselslate) for waywall,resetti and MCSR on linux possible.
- [its-saanvi](https://github.com/its-saanvi/linux-mcsr) for linux MCSR guide and [plug.waywall](https://github.com/its-saanvi/plug.waywall)
- [arjuncgore](https://github.com/arjuncgore) for Gores generic config and references for scripts for plug waywall
- [qMaxXen](https://github.com/qMaxXen) for nbtracker and a lot help with resetti when I started out.
- [vojta](https://github.com/votisek) review on script as well as general advice and prism config writing.

and many more people in [linux mcsr cord](https://discord.com/invite/3tm4UpUQ8t) who helped and adviced along the way

