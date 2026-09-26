# Snaws waywall install script

This is script designed for Fedora 44 + which does following:

- Download and setup default JDK for Fedora to avoid issue related to headless JDK
- Download and install Prism launcher
- Downloads and install waywall
- Downloads [Gores Generic Config](https://github.com/arjuncgore/waywall_config) sets it up for waywall.
- Configures your minecraft instance to use waywall ( wrapper and glfw setup)

# How to use 
1. Download the `setup.sh` script.
2. Open a terminal and change the directory wherever the setup.sh is present. i.e if it's in downloads then `cd path`, example `cd ~/Downloads/`.
3. Run following command to mark it as executable `chmod +x setup.sh`.
4. Run the script `./setup.sh` in terminal and follow onscreen instructions

The main menu provides two paths:

1. Waywall and Prism setup
2. Generic config addons using plug.waywall

# Current development plans:
- structure probably and port for debian based distros and fedora 43 and below support


# Thanks!
- [woofdoggo](https://github.com/tesselslate) for waywall,resetti and MCSR on linux possible.
- [its-saanvi](https://github.com/its-saanvi/linux-mcsr) for linux MCSR guide and plug.waywall
- [arjuncgore](https://github.com/arjuncgore) for Gores generic config and references for scripts for plug waywall
- [qMaxXen](https://github.com/qMaxXen) for nbtracker and a lot help with resetti when I started out.
- [vojta](https://github.com/votisek) review on script as well as general advice and prism config writing.

and many more people in [linux mcsr cord](https://discord.com/invite/3tm4UpUQ8t) who helped and adviced along the way