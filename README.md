# Snaws waywall install script

This is fast script designed for Fedora 44 + which does following:

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

# Current development plans:
- Menu for options (currently it just installs stuff and sets up waywall)
- Ninbot config auto setup for boateye
- Ninbot shows on F3+C
- Oneshot crosshair setup in config
- structure probably and port for debian based distros and fedora 43 and below support


