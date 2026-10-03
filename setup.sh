#!/bin/bash

if [[ -n "${SUDO_USER:-}" || ${EUID:-$(id -u)} -eq 0 ]]; then
   echo "[ERROR] This script must be run as your normal user, not with sudo: bash setup.sh"
   exit 1
fi

SUPPORTED_OS=("fedora" "nobara" "ubuntu" "debian") 
declare -A SUPPORTED_VERSIONS
SUPPORTED_VERSIONS["fedora"]="42 43 44"
SUPPORTED_VERSIONS["nobara"]="42 43 44"
SUPPORTED_VERSIONS["ubuntu"]="26.04"
SUPPORTED_VERSIONS["debian"]="13"


function append_log {
   if [[ $1 == "i" ]]; then
      echo "[INFO] $2" >> "$LOG_FILE"
   elif [[ $1 == "e" ]]; then
      echo "[ERROR] $2" >> "$LOG_FILE"
   else
      echo "[UNKNOWN] $1" >> "$LOG_FILE"
   fi
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/_setup.sh.log"
NINBOT_GREENBOAT_GODSENS_XMLURI="https://raw.githubusercontent.com/lemonsnaw/snaws-waywall-installer/refs/heads/main/prefs.xml"

TMP_DIR="/tmp/snawswaywallinstaller"
mkdir -p "$TMP_DIR"
rm -f "$TMP_DIR/waywall.rpm" "$TMP_DIR/waywall.deb" "$TMP_DIR/prefs.xml" "$TMP_DIR/prism-instance.cfg.tmp"

if [[ ! -f "$LOG_FILE" ]]; then
   echo "Creating log file"
   touch "$LOG_FILE"
   ls -l "$LOG_FILE"
   if [[ ! -f "$LOG_FILE" ]]; then
      echo "[ERROR] Failed to create log file"
      exit 1
   fi
elif [[ -f "$LOG_FILE" ]]; then
   rm -f "$LOG_FILE"
   if [[ -f "$LOG_FILE" ]]; then
      echo "[ERROR] Failed to delete log file"
      exit 1
   fi
   echo "Creating log file"
   touch "$LOG_FILE"
   ls -l "$LOG_FILE"
   if [[ ! -f "$LOG_FILE" ]]; then
      echo "[ERROR] Failed to create log file"
      exit 1
   fi
fi



declare -A genericAddons
genericAddons[oneshot]='oneshot|Do you want to add oneshot crosshair to your config?|uri'
genericAddons[showninbotf3c]='showninbotf3c|Do you want to show ninbot on F3 + C (it doesnt open by default)?|uri'

architecture=$(uname -m)
if [[ $architecture != "x86_64" ]]; then
   echo "[ERROR] This script supports only x86_64 architecture"
   exit 1
fi

OS_ID=$(grep ^ID= /etc/os-release | cut -d "=" -f 2 | tr '[:upper:]' '[:lower:]')
OS_VERSION=$(grep '^VERSION_ID=' /etc/os-release | cut -d '=' -f 2 | tr -d '"')
echo "$OS_ID"
echo "$OS_VERSION"

is_supported_os=false
for os in "${SUPPORTED_OS[@]}"; do
   if [[ "$OS_ID" == "$os" ]]; then
      append_log i "Detected supported OS: $OS_ID"
      append_log i "Checking for supported version: $OS_VERSION"
      for version in ${SUPPORTED_VERSIONS[$os]}; do
         if [[ "$OS_VERSION" == "$version" ]]; then
            is_supported_os=true
            break
         fi
      done
      if [[ "$is_supported_os" == true ]]; then
         echo "Supported OS and version detected: $OS_ID $OS_VERSION"
         append_log i "Supported OS and version detected: $OS_ID $OS_VERSION"
         break
      fi

      echo "Unsupported version for $OS_ID: $OS_VERSION. Supported versions are: ${SUPPORTED_VERSIONS[$os]}"
      append_log e "Unsupported version for $OS_ID: $OS_VERSION. Supported versions are: ${SUPPORTED_VERSIONS[$os]}"
      exit 1
   fi
done
if [[ "$is_supported_os" == false ]]; then
   echo "[ERROR] Unsupported OS: $OS_ID. Supported OS are: ${SUPPORTED_OS[*]}"
   append_log e "Unsupported OS: $OS_ID. Supported OS are: ${SUPPORTED_OS[*]}"
   exit 1
fi 

# I am asssuming here that supported os are already handled at top
# we are safe to proceed for the most part
function osHandler {
   case  "$OS_ID" in
      fedora|nobara)
         if ! fedoraNobaraHandler; then
            append_log e "Fedora/Nobara handler failed"
            echo "Something went wrong while doing the setup for Fedora/Nobara."
            exit 1
         fi 
         ;;
      ubuntu | debian)
         if ! ubuntuDebianHandler  ; then
            append_log e "Ubuntu/Debian handler failed"
            echo "Something went wrong while doing the setup for Ubuntu/Debian."
            exit 1
         fi 
         ;;
      *)
         echo "[ERROR] Unsupported OS: $OS_ID. Supported OS are: ${SUPPORTED_OS[*]}"
         append_log e "Unsupported OS: $OS_ID. Supported OS are: ${SUPPORTED_OS[*]}"
         exit 1
         ;;
   esac
}
function title_print {
   echo "==============================="
   echo "$1"
   echo "==============================="
}
function sigIntHandler {
   echo "[INFO] SIGINT received, exiting..."
   exit 1
}
trap sigIntHandler SIGINT



MCSR_RANKED_PACK_URL="https://redlime.github.io/MCSRMods/modpacks/v4/MCSRRanked-Linux-1.16.1-Basic-w-SS.mrpack"


function flatpakPrismHandler {
   local flatpakApp="org.prismlauncher.PrismLauncher"
   local flatpakInstancesDir="$HOME/.var/app/$flatpakApp/data/PrismLauncher/instances"
   local flatpakBackupDir="$SCRIPT_DIR/backup_flatpak"
   local flatpakBackupInstancesDir="$flatpakBackupDir/instances"

   if ! command -v flatpak >/dev/null 2>&1; then
      echo "flatpak is not installed, skipping flatpak prism check"     
      append_log i "flatpak is not installed, skipping flatpak prism check"
      return 0
   fi

   if ! flatpak info "$flatpakApp" >/dev/null 2>&1; then
      echo "flatpak Prism is not installed, skipping flatpak prism check"
      append_log i "flatpak Prism is not installed, skipping flatpak prism check"
      return 0
   fi

   echo "flatpak Prism doesnt work with waywall it will be uninstalled and instances folder will be backed up in same folder where this script is running at $flatpakBackupDir"
   read -r -n 1 -s -p "Press any key to continue..."
   echo

   if ! mkdir -p "$flatpakBackupDir"; then
      append_log e "Failed to create Flatpak backup directory"
      echo "Failed to create Flatpak backup directory. Flatpak Prism will not be uninstalled."
      return 1
   fi

   if [[ -d "$flatpakInstancesDir" ]]; then
      if [[ -d "$flatpakBackupInstancesDir" ]]; then
         if ! rm -rf "$flatpakBackupInstancesDir"; then
            append_log e "Failed to remove existing Flatpak instances backup"
            echo "Failed to remove the existing Flatpak backup. Flatpak Prism will not be uninstalled."
            return 1
         fi
      fi
      if ! cp -a "$flatpakInstancesDir" "$flatpakBackupInstancesDir"; then
         append_log e "Failed to back up Flatpak instances"
         echo "Failed to back up Flatpak instances. Flatpak Prism will not be uninstalled."
         return 1
      fi
      append_log i "Backed up flatpack isntances from $flatpakInstancesDir to $flatpakBackupInstancesDir"
      echo "Flatpak instances backed up to $flatpakBackupInstancesDir"
   else
      if ! mkdir -p "$flatpakBackupInstancesDir"; then
         append_log e "Failed to create empty Flatpak instances backup directory"
         echo "Failed to create the Flatpak backup directory. Flatpak Prism will not be uninstalled."
         return 1
      fi
      append_log i "No instance directory found, I am assuming that we have not created it and unisntalling prism"
      echo "No instance directory found, flatpak prism will be uninstalled next"
   fi

   flatpak uninstall -y "$flatpakApp"
   if [[ $? -ne 0 ]]; then
      append_log e "Failed to uninstall flatpak launcher"
      echo "Failed to uninstall flatpak launcher. please uninstall it, manually , existing the script"
      return 1
   fi

   append_log i "flatpak prism removed and instances backed up"
   echo "flatpak prism removed and instances backed up"
   return 0
}
function installAdoptiumJDKRedhatBased {
   sudo dnf -y install adoptium-temurin-java-repository
   adoptiumRepoAdded=$?
   if [[ $adoptiumRepoAdded -ne 0 ]]; then
      append_log e "Failed to add adoptium repo"
      return 1
   fi
   append_log i "Adoptium repo added successfully"

   sudo fedora-third-party enable
   fedoraThirdPartyEnabled=$?
   if [[ $fedoraThirdPartyEnabled -ne 0 ]]; then
      append_log e "Failed to enable fedora-third-party"
      return 1
   fi
   append_log i "fedora-third-party enabled successfully"

   sudo dnf -y makecache
   dnfMakeCache=$?
   if [[ $dnfMakeCache -ne 0 ]]; then
      append_log e "Failed to update the dnf cache"
      return 1
   fi
   append_log i "Cache updated successfully"
   sudo dnf -y install temurin-21-jdk
   jdkInstall=$?
   if [[ $jdkInstall -ne 0 ]]; then
      append_log e "Failed to install temurin-21-jdk"
      return 1
   fi
   append_log i "temurin-21-jdk installed successfully"
   JDK_VERSION_INSTALLED=21

   if [[ ! -d "/usr/lib/jvm/temurin-21-jdk" ]]; then
      append_log e "JDK not present at /usr/lib/jvm/temurin-21-jdk"
      return 1
   fi

   append_log i "JDK is present at /usr/lib/jvm/temurin-21-jdk"
   sudo alternatives --install /usr/bin/java java /usr/lib/jvm/temurin-21-jdk/bin/java 1
   sudo alternatives --set java /usr/lib/jvm/temurin-21-jdk/bin/java
   alternativesSet=$?
   if [[ $alternativesSet -ne 0 ]]; then
      append_log e "Failed to set alternatives for java"
      return 1
   fi
   append_log i "Alternatives for java set successfully"
   append_log i "Adoptium java installed successfully"
   return 0
}

# Here I am also assuming OS check is done at top  to proceed
# for fedora/nobara I am just installing Adoptium JDK , even though
# 42 43 might have openjdk , i am too lazy will fix maybe later 
# jdk vendor wouldnt matter much 
function javaHandlerFedoraNobara {
   if ! installAdoptiumJDKRedhatBased ; then
            append_log e "Somethign went wrong while isntalling JDK"
            exit 1
   fi
   echo "JDK installed Successfully"
}

function javaHandleAPTSystems {
   sudo apt -y update
   sudo apt -y install openjdk-21-jdk
   if [[ $? -ne 0 ]]; then
      append_log e "Failed to install openjdk-21-jdk"
      echo "Failed to install openjdk-21-jdk, please install it manually and rerun the script"  
      return 1
   fi
   append_log i "openjdk-21-jdk installed successfully"
   # idk why update-java-alternatives doesnt work , I will debug later
   sudo update-alternatives --set java /usr/lib/jvm/java-21-openjdk-amd64/bin/java
 
   if [[ $? -ne 0 ]]; then
      append_log e "Failed to set java-21-openjdk-amd64 as default"
      echo "Failed to set java-21-openjdk-amd64 as default, please set it manually and rerun the script"  
      return 1
   fi
   append_log i "java-21-openjdk-amd64 set as default successfully"
}

function prismJavahandlerUbuntuDebian {
   flatpakPrismHandler || return 1
   title_print "Installing JDK and Prism Launcher (no user input required)"
   javaHandleAPTSystems || return 1
   sudo wget https://prism-launcher-for-debian.github.io/repo/prismlauncher.gpg -O /usr/share/keyrings/prismlauncher-archive-keyring.gpg \
 && echo "Types: deb
URIs: https://prism-launcher-for-debian.github.io/repo
Suites: $(. /etc/os-release; echo "${UBUNTU_CODENAME:-${DEBIAN_CODENAME:-${VERSION_CODENAME}}}")
Components: main
Signed-By: /usr/share/keyrings/prismlauncher-archive-keyring.gpg" | sudo tee /etc/apt/sources.list.d/prismlauncher.sources \
 && sudo apt -y update \
 && sudo apt -y install prismlauncher
   prismInstall=$?
   if [[ $prismInstall -ne 0 ]]; then
      echo "Failed to install prismlauncher"
      append_log e "Failed to install prismlauncher"
      exit 1
   fi
   append_log i "prismlauncher installed successfully"
   echo "Installing libxkbcommon since its missing causing ninbot to show hotkeys"
   append i "Installing libxkbcommon since its missing causing ninbot to show hotkeys"
   sudo apt install libxkbcommon-x11-dev
   if [[ $? -ne 0 ]]; then
      echo "Failed to install libxkbcommon-x11-dev , package name might be different install manually to avoid issues with ninbot"
      append_log e "Failed to install libxkbcommon-x11-dev package name might be different"
   fi
}

function prismJavaHandlerFedoraNobara {
      
      flatpakPrismHandler || return 1
      title_print "Installing JDK and Prism Launcher (no user input required)"
      javaHandlerFedoraNobara || return 1 
      sudo dnf -y copr enable g3tchoo/prismlauncher
      coprEnable=$?
      if [[ $coprEnable -ne 0 ]]; then
         append_log e "Failed to enable copr g3tchoo/prismlauncher"
         exit 1
      fi
      append_log i "Copr g3tchoo/prismlauncher enabled successfully"

      sudo dnf -y install prismlauncher
      prismInstall=$?
      if [[ $prismInstall -ne 0 ]]; then
         append_log e "Failed to install prismlauncher"
         exit 1
      fi
      append_log i "prismlauncher installed successfully"
}
function ninbotHandler {
   local downloadedPrefsFile="$TMP_DIR/prefs.xml"
   if [[ ! -d "$HOME/.java/.userPrefs/ninjabrainbot" ]]; then
      mkdir -p "$HOME/.java/.userPrefs/ninjabrainbot"
      if [[ $? -ne 0 ]]; then
         append_log e "Failed to create directory $HOME/.java/.userPrefs/ninjabrainbot; ninjabrainbot settings will be skipped"
         return 1
      else
         append_log i "Created directory $HOME/.java/.userPrefs/ninjabrainbot for ninjabrainbot settings"
      fi
   fi

   if [[ -f "$HOME/.java/.userPrefs/ninjabrainbot/prefs.xml" ]]; then
      append_log i "prefs.xml already exists at $HOME/.java/.userPrefs/ninjabrainbot/prefs.xml, skipping modifications to it"
   else
      if [[ -f "$downloadedPrefsFile" ]]; then
         append_log i "prefs.xml found in $downloadedPrefsFile, copying to $HOME/.java/.userPrefs/ninjabrainbot/prefs.xml"
         cp "$downloadedPrefsFile" "$HOME/.java/.userPrefs/ninjabrainbot/prefs.xml"
         if [[ $? -ne 0 ]]; then
            append_log e "Failed to copy prefs.xml to $HOME/.java/.userPrefs/ninjabrainbot/prefs.xml"
            return 1
         else
            append_log i "Copied prefs.xml to $HOME/.java/.userPrefs/ninjabrainbot/prefs.xml"
         fi
      else
         append_log i "prefs.xml not found in $TMP_DIR, downloading from $NINBOT_GREENBOAT_GODSENS_XMLURI"
         curl -fL -o "$downloadedPrefsFile" "$NINBOT_GREENBOAT_GODSENS_XMLURI"
         if [[ $? -ne 0 ]]; then
            append_log e "Failed to download prefs.xml from $NINBOT_GREENBOAT_GODSENS_XMLURI"
            return 1
         else
            append_log i "Downloaded prefs.xml from $NINBOT_GREENBOAT_GODSENS_XMLURI"
            cp "$downloadedPrefsFile" "$HOME/.java/.userPrefs/ninjabrainbot/prefs.xml"
            if [[ $? -ne 0 ]]; then
               append_log e "Failed to copyConfiguration downloaded prefs.xml to $HOME/.java/.userPrefs/ninjabrainbot/prefs.xml"
               return 1
            else
               append_log i "Copied downloaded prefs.xml to $HOME/.java/.userPrefs/ninjabrainbot/prefs.xml"
            fi
         fi
      fi
   fi
   return 0
}
function prismInstanceHandler {
      local prismTempConfig="$TMP_DIR/prism-instance.cfg.tmp"
      title_print "Prism Launcher Ranked Instance Setup (User Input Required)"
      while true; do

      read -p "Do you want to import MCSR Ranked Pack for Prism Launcher? type n if you are already have configured instance , you will be asked for path in next section [y/n] :" prismInstanceChoice
      prismInstanceChoice=$(to_lowercase "$prismInstanceChoice")
      case "$prismInstanceChoice" in
         y|yes)
               
               read -r -n 1 -s -p "Script will open the MCSR Ranked pack in Prism Launcher, accept and press ok and launch the instance. Press any key to continue..."
               echo
               append_log i "Opening Prism Launcher to import MCSR Ranked modpack"
               prismlauncher --import "$MCSR_RANKED_PACK_URL" >/dev/null 2>&1 &
               prismImportPid=$!
               if [[ $? -ne 0 ]]; then
                  append_log e "Failed import mcsr ranked isntance "
                  echo "Failed to start prism launcher."
                  return 1
               fi 
               append_log i "Started Prism Launcher for MCSR Ranked import (PID $prismImportPid)"
               echo "Prism Launcher started in the background (PID $prismImportPid)."
               break;
            ;;
         n|no)
         break
            ;;
         *)
            echo "Invalid choice. Please type y for yes or n for no(you already have mcsr ranked instance setup)."
            ;;
      esac
   done

   title_print "Ranked Instance Path Setup (User Input Required)"
   echo "Complete the import and launch the instance once, then enter its path below."
   echo "example path: /home/snaw/.local/share/PrismLauncher/instances/MCSRRanked-Linux-1.16.1-Basic-w-SS"
   while true; do
      read -p "Enter path:" rankedinstancepath
      if [[ -d "$rankedinstancepath" ]] && [[ -f "$rankedinstancepath/instance.cfg" ]]; then
         append_log i "Ranked instance path is valid and instance file is present: $rankedinstancepath"
         break
      fi

      append_log e "Ranked instance path is invalid: $rankedinstancepath"
      echo ""
      echo ""
      echo "Ranked instance path is invalid, please try again or ctrl+c to exit"
   done

   TARGET_USER="${SUDO_USER:-$(whoami)}"

   title_print "Prism waywall configuration in progress"
   append_log i "Configuring prism to use waywall"
   read -p "Prism launcher and minecraft instance has to closed to write to config , please press any key to continue it will be automically closed if it is open:"

   append_log i "Closing prism launcher if it is open"

   prismids="$(ps -e | grep -c prismlauncher)"
   if [[ $prismids -gt 0 ]]; then
      append_log i "Prism launcher is open, closing it"
      # I checked that killing prism it does kill minecraft instances so I am keeping it that way
      # here minecraft instances are also killed
      pkill -f prismlauncher
      if [[ $? -ne 0 ]]; then
         append_log e "Failed to close prism launcher"
         return 1
      fi
      append_log i "Prism launcher closed successfully"
   else
      append_log i "Prism launcher is not open, proceeding with configuration"
   fi

   prismConfigFile="$rankedinstancepath/instance.cfg"
   if [[ -f "$prismConfigFile" ]]; then
      append_log i "prism config file found at $prismConfigFile"
      awk '
         /^\[General\]/ {
            print
            print "OverrideCommands=true"
            print "OverrideNativeWorkarounds=true"
            print "CustomGLFWPath=/usr/local/lib64/waywall-glfw/libglfw.so"
            print "IgnoreJavaCompatibility=true"
            print "UseNativeGLFW=true"
            print "WrapperCommand=waywall wrap --"
            next
         }
         { print }
         ' "$prismConfigFile" > "$prismTempConfig" && mv -f "$prismTempConfig" "$prismConfigFile"
      if [[ $? -ne 0 ]]; then
         append_log e "Failed to update prism config file at $prismConfigFile"
         echo "Failed to update prism config file at $prismConfigFile, please manually add glfw path and wrapper command"
         return 1
      fi
      append_log i "prism config file updated successfully at $prismConfigFile"
      append_log i "Prism config permissions: $(ls -l "$prismConfigFile")"
   else
      append_log e "prism config file not found at $prismConfigFile"
      return 1
   fi
   return 0
}
function fedoraNobaraHandler {
     if ! command -v curl >/dev/null 2>&1; then
         append_log e "curl is not installed,installing curl"
         sudo dnf -y install curl
      fi
      if ! command -v git >/dev/null 2>&1; then
         append_log e "git is not installed,installing git"
         sudo dnf -y install git
      fi
   if ! prismJavaHandlerFedoraNobara; then
      append_log e "Somethign went wrong while installing jdk and prism"
      echo "Somethign went wrong while installing jdk and prism $LOG_FILE"
      exit 1
   fi

   if ! prismInstanceHandler; then
      append_log e "Prism instance configuration failed"
      echo "Prism Instance configuration, please do the changes manually, waywall,ninbot installation will continue"
      exit 1
   fi
   if ! ninbotHandler; then
      append_log e "ninbot configuration failed for boateye please do it manually"
      echo "ninbot configuration failed for boateye, please setup boateye, waywall installation will continue"
      exit 1
   fi
   waywallFedoraNobaraHandler
}
function ubuntuDebianHandler {
   if ! command -v curl >/dev/null 2>&1; then
         append_log e "curl is not installed,installing curl"
         sudo apt -y install curl
      fi
   if ! command -v git >/dev/null 2>&1; then
         append_log e "git is not installed,installing git"
         sudo apt -y install git
      fi
   if ! prismJavahandlerUbuntuDebian; then
      append_log e "Somethign went wrong while installing jdk and prism"
      echo "Somethign went wrong while installing jdk and prism $LOG_FILE"
      exit 1
   fi
     if ! prismInstanceHandler; then
      append_log e "Prism instance configuration failed"
      echo "Prism Instance configuration, please do the changes manually, waywall,ninbot installation will continue"
      exit 1
   fi
   if ! ninbotHandler; then
      append_log e "ninbot configuration failed for boateye please do it manually"
      echo "ninbot configuration failed for boateye, please setup boateye, waywall installation will continue"
      exit 1
   fi
   waywallUbuntuHandler
}

function waywallUbuntuHandler {
   local waywallDebPath="$TMP_DIR/waywall.deb"
    title_print "Waywall installation and configuration (No user input required)"
   append_log i "Starting waywall installation and configuration"
   if dpkg-query -W -f='${db:Status-Status}' waywall 2>/dev/null | grep -qx 'installed'; then
      append_log i "Waywall is already installed, skipping installation"
      if ! waywallinstalltionVerification; then
         append_log e "Waywall installation verification failed"
         echo "Failed to verify waywall installation"
         exit 1
      fi
   else
      append_log i "Waywall is not installed, proceeding with installation"
      echo "Waywall is not installed, proceeding with installation"
      append_log i "Downloading waywall.deb"

      curl -fL -o "$waywallDebPath" "https://github.com/tesselslate/waywall/releases/download/0.2026.06.13/waywall_0.5-1_amd64.deb"
      waywallDownload=$?
      if [[ $waywallDownload -ne 0 ]]; then
         append_log e "Failed to download waywall.deb"
         exit 1
      fi 
      append_log i "waywall.deb downloaded successfully"
      sudo apt -y install "$waywallDebPath"
      waywallInstall=$?
      if [[ $waywallInstall -ne 0 ]]; then
         append_log e "Failed to install waywall.deb"
         exit 1
      fi
      if ! waywallinstalltionVerification; then
         append_log e "Waywall installation verification failed"
         echo "Failed to verify waywall installation"
         exit 1
      fi
   fi
      echo "Waywall Installed and verified successfully"
}
function waywallFedoraNobaraHandler {
    local waywallRpmPath="$TMP_DIR/waywall.rpm"
    title_print "Waywall installation and configuration (No user input required)"
   append_log i "Starting waywall installation and configuration"
   isWaywallInstalled=$(dnf list installed waywall 2>/dev/null | grep -c waywall)
   if [[ $isWaywallInstalled -eq 1 ]]; then
      append_log i "Waywall is already installed, skipping installation"
      if ! waywallinstalltionVerification; then
         append_log e "Waywall installation verification failed"
         echo "Failed to verify waywall installation"
         exit 1
      fi
   elif [[ $isWaywallInstalled -eq 0 ]]; then
      append_log i "Waywall is not installed, proceeding with installation"
      echo "Waywall is not installed, proceeding with installation"
      append_log i "Downloading waywall.rpm"
    
      curl -fL -o "$waywallRpmPath" https://github.com/tesselslate/waywall/releases/download/0.2026.06.13/waywall-0.5-1.fc42.x86_64.rpm
      waywallDownload=$?
      if [[ $waywallDownload -ne 0 ]]; then
         append_log e "Failed to download waywall.rpm"
         exit 1
      fi
      append_log i "waywall.rpm downloaded successfully"

      sudo dnf -y install "$waywallRpmPath"
      waywallInstall=$?
      if [[ $waywallInstall -ne 0 ]]; then
         append_log e "Failed to install waywall.rpm"
         exit 1
      fi
      if ! waywallinstalltionVerification; then
         append_log e "Waywall installation verification failed"
         echo "Failed to verify waywall installation"

         exit 1
      fi
   fi
   echo "Waywall Installed and verified successfully"
}
function waywallinstalltionVerification {
      title_print "Waywall verfication in progress"
      append_log i "Verifying waywall installation"
      if [[ -f /usr/bin/waywall ]]; then
         append_log i "waywall binary found at /usr/bin/waywall"
      else
         append_log e "waywall binary not found at /usr/bin/waywall"
         append_log i "dir /usr/bin/waywall:"
         append_log i "$(ls -l /usr/bin/waywall)"
         append_log i "dir /usr/local/lib64/waywall-glfw:"
         append_log i "$(ls -l /usr/local/lib64/waywall-glfw)"
         return 1
      fi
      if [[ -f /usr/local/lib64/waywall-glfw/libglfw.so ]]; then
         append_log i "waywall-glfw library found at /usr/local/lib64/waywall-glfw/libglfw.so"
      else
         append_log e "waywall-glfw library not found at /usr/local/lib64/waywall-glfw/libglfw.so"
         append_log i "dir /usr/bin/waywall:"
         append_log i "$(ls -l /usr/bin/waywall)"
         append_log i "dir /usr/local/lib64/waywall-glfw:"
         append_log i "$(ls -l /usr/local/lib64/waywall-glfw)"
         return 1
      fi
      append_log i "waywall.rpm installed successfully"
   return 0
}

   
function to_lowercase
{
   printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

# 0 for yes , 1 for no
function askUseGenericConfig {
   local genericChoice=""
   local confirmDenial=""

   while true; do
      read -p "Do you want to use Generic Config by Gore? [y/n]: " genericChoice
      genericChoice=$(to_lowercase "$genericChoice")

      case "$genericChoice" in
         y|yes)
            return 0
            ;;
         n|no)
            while true; do
               read -p "Generic config is recommended for most people. Please confirm that you DONT want to use generic config and will be configuring manually? [y/n]: " confirmDenial
               confirmDenial=$(to_lowercase "$confirmDenial")

               case "$confirmDenial" in
                  y|yes)
                     return 1
                     ;;
                  n|no)
                     return 0
                     ;;
                  *)
                     echo "Invalid choice. Please type y or n."
                     ;;
               esac
            done
            ;;
         *)
            echo "Invalid choice. Please type y or n."
            ;;
      esac
   done
}


function genericConfigHandler {
   append_log i "Backing up existing waywall config if present"
   append_log i "Starting waywall configuration (using generic config)"
   append_log i "Using target user: $TARGET_USER at $HOME"

   if [[ -d "$HOME/.config/waywall" ]]; then
      append_log i "Existing waywall config found, backing up to $HOME/.config/waywall.bkp"
      count=1
      while [[ -d "$HOME/.config/waywall.bkp$count" ]]; do
         count=$((count + 1))
      done
      mv "$HOME/.config/waywall" "$HOME/.config/waywall.bkp$count"
      append_log i "Existing waywall config backed up to $HOME/.config/waywall.bkp$count"
   fi

   local waywallConfigChoice="0"
   while true; do
      read -p "what resolution are you using 1080p(default/0) or 1440p(1)? [0/1]: " waywallConfigChoice
      case "$waywallConfigChoice" in
         0)
            append_log i "User chose 1080 config for waywall"
            break
            ;;
         1)
            append_log i "User chose 1440 config for waywall"
            break
            ;;
         *)
            append_log e "Invalid choice for waywall config, please try again"
            echo ""
            echo ""
            echo "Invalid choice for waywall config, please try again or ctrl+c to exit"
            ;;
      esac
   done

   if [[ ! -d "$HOME/.config" ]]; then
      mkdir -p "$HOME/.config"
   fi

   if [[ -d "$HOME/.config/waywall" ]]; then
      rm -rf "$HOME/.config/waywall"
   fi


   if [[ "$waywallConfigChoice" == "0" ]]; then
      append_log i "Downloading 1080p config for waywall"
      git clone https://github.com/arjuncgore/waywall_generic_config.git "$HOME/.config/waywall"
      gitCloneSuccess=$?
      if [[ $gitCloneSuccess -ne 0 ]]; then
         append_log e "Failed to clone waywall_generic_config repo"
         exit 1
      fi
      append_log i "waywall_generic_config repo cloned successfully at $HOME/.config/waywall"
   elif [[ "$waywallConfigChoice" == "1" ]]; then
      append_log i "Downloading 1440p config for waywall"
      git clone -b 1440 https://github.com/arjuncgore/waywall_generic_config.git "$HOME/.config/waywall"
      gitCloneSuccess=$?
      if [[ $gitCloneSuccess -ne 0 ]]; then
         append_log e "Failed to clone waywall_generic_config repo"
         exit 1
      fi
      append_log i "waywall_generic_config repo cloned successfully at $HOME/.config/waywall"
   fi
   return 0
}


function waywallConfigHandler {
   title_print "Configure Waywall config (User Input Required)"
   append_log i "Starting waywall configuration"
   append_log i "Using target user: $TARGET_USER at $HOME"

   if askUseGenericConfig; then
      genericConfigHandler
   else
      append_log i "User chose manual waywall configuration"
   fi
}

function plugWaywallHandler {
   title_print "Plug waywall handler"
   echo "Checking for existing plugins"
   append_log i "Checking for existing plug waywall plugins"
   local extrasLuaPath="$HOME/.config/waywall/extras.lua"
   if [[ ! -f "$extrasLuaPath" ]]; then
      append_log i "No extras.lua found, user probably not using generic?"
      echo "No extras.lua found, so you are probably not using generic config. Skipping generic plugin setup."
      return 1
   fi

   if [[ -d "$HOME/.config/waywall/plugins" ]]; then
      echo "Your existing plugins will be backed up before new plugins are installed."
      echo "You can copy them back from the backup directory after setup."

      while true; do
         read -r -p "Create a backup of the existing plugins(no new plugins will be instlaled if cancelled)? [y/n]: " confirmplugwaywall
         case "$(to_lowercase "$confirmplugwaywall")" in
            y|yes)
               break
               ;;
            n|no)
               append_log i "User declined existing plugin backup"
               echo "Plugin backup cancelled; plugin installation aborted."
               return 1
               ;;
            *)
               echo "Invalid choice. Please type y or n."
               ;;
         esac
      done

      count=1
      while [[ -d "$HOME/.config/waywall/plugins.bkp$count" ]]; do
         count=$((count + 1))
      done

      local pluginsBackupPath="$HOME/.config/waywall/plugins.bkp$count"
      if ! mv "$HOME/.config/waywall/plugins" "$pluginsBackupPath"; then
         append_log e "Failed to back up existing plugins"
         return 1
      fi

      append_log i "Existing plugins backed up to $pluginsBackupPath"
      echo "Existing plugins backed up to $pluginsBackupPath"
   fi

   echo "Checking for Generic config"
   append_log i "checking if generic config is being used"

   if [[ -f "$extrasLuaPath" ]]; then
      echo "Generic config/extras.lua found at $HOME/.config/waywall"
      count=1
      while [[ -f "$extrasLuaPath.bkp$count" ]]; do
         count=$((count + 1))
      done

      local extrasBackupPath="$extrasLuaPath.bkp$count"
      if ! cp -f "$extrasLuaPath" "$extrasBackupPath"; then
         append_log e "Failed to back up extras.lua"
         return 1
      fi

      append_log i "Backed up extras.lua to $extrasBackupPath"
      echo "Backed up extras.lua to $extrasBackupPath"
   fi

   cat > "$extrasLuaPath" <<'EOF'
-- Bootstrap plug.waywall
local plug_repo = "https://github.com/its-saanvi/plug.waywall"
local waywall_share = os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share") .. "/waywall"
local plug_path = waywall_share .. "/plug"
local file, err = io.open(plug_path .. "/.check_temp", "w")
if not file and err then
    if string.find(err, "No such file or directory") then
        if not os.execute("mkdir -p " .. waywall_share) then
            print("Failed to create waywall share directory")
        end
        if not os.execute("git clone " .. plug_repo .. " " .. plug_path) then
            print("Failed to clone plug.waywall")
        end
    end
else
    file:close()
    os.remove(plug_path .. "/.check_temp")
end
package.path = package.path .. ";" .. waywall_share .. "/plug/?/init.lua" .. ";" .. plug_path .. "/?.lua"

local plug = require("plug")
local waywall = require("waywall")
local helpers = require("waywall.helpers")

return function(config)
   plug.setup({
      dir = "plugins",
      config = config,
      path = "~/.local/share/waywall/plug",
      log_level = "debug",
   })

    -- Add any extra code here



    -- END
end
EOF

   append_log i "Initialized extras.lua with plug.waywall bootstrap and default template"
   echo "extras.lua initialized with plug.waywall bootstrap and default template"
   if ! mkdir -p $HOME/.config/waywall/plugins; then
      append_log e "Failed to create plugins foldder"
      echo "Failed to create waywall plugins folder"
      return 1
   fi

   local ninbotPlugin="$SCRIPT_DIR/plugins/ww_ninbot_f3c.lua"
   local oneShotPlugin="$SCRIPT_DIR/plugins/ww_oneshot_crosshair.lua"
   local installedPluginsPath="$HOME/.config/waywall/plugins"

   if [[ -n "${selectedGenericAddons[showninbotf3c]+set}" ]]; then
      if [[ ! -f "$ninbotPlugin" ]]; then
         append_log e "ww_ninbot_f3c plugin is missing from $SCRIPT_DIR/plugins"
         echo "ww_ninbot_f3c plugin is missing from $SCRIPT_DIR/plugins"
         return 1
      fi

      if ! cp "$ninbotPlugin" "$installedPluginsPath/ww_ninbot_f3c.lua"; then
         append_log e "Failed to install ww_ninbot_f3c plugin"
         echo "Failed to install ww_ninbot_f3c plugin"
         return 1
      fi

      append_log i "Installed ww_ninbot_f3c plugin"
      echo "Installed ww_ninbot_f3c plugin"
   fi

   if [[ -n "${selectedGenericAddons[oneshot]+set}" ]]; then
      if [[ ! -f "$oneShotPlugin" ]]; then
         append_log e "ww_oneshot_crosshair plugin is missing from $SCRIPT_DIR/plugins"
         echo "ww_oneshot_crosshair plugin is missing from $SCRIPT_DIR/plugins"
         return 1
      fi

      if ! cp "$oneShotPlugin" "$installedPluginsPath/ww_oneshot_crosshair.lua"; then
         append_log e "Failed to install ww_oneshot_crosshair plugin"
         echo "Failed to install ww_oneshot_crosshair plugin"
         return 1
      fi

      append_log i "Installed ww_oneshot_crosshair plugin"
      echo "Installed ww_oneshot_crosshair plugin"
   fi

   return 0
}


function genericConfigAddonsHandler {
   title_print "Generic config plugins Setup"
   local genericConfigConfirmation=""
   while true; do
      echo "This script is intended to be used with generic config by gore"
      echo "PLEASE DO NOT USE IT IN CASE YOU ARE NOT USING GENERIC CONFIG"

      read -p "Do you want to continue [y/n]: " genericConfigConfirmation
      case "$(to_lowercase "$genericConfigConfirmation")" in
         y|yes)
            break
            ;;
         n|no)
            echo "Generic config addon setup cancelled."
            return 1
            ;;
         *)
            echo "Invalid choice. Please type y or n."
            ;;
      esac
   done

   declare -Ag selectedGenericAddons=()
   local addonChoice=""
   local addonName=""
   local addonDescription=""
   local addonType=""
   local invalidAddon=""
   local selectedAddon=""
   local selectedIndex=""
   local addonNumber=1
   local -a addonNames=()

   echo "Available addons:"
   for addonName in "${!genericAddons[@]}"; do
      addonNames[$addonNumber]="$addonName"
      IFS='|' read -r _ addonDescription addonType <<< "${genericAddons[$addonName]}"
      printf '  %-18s %s\n' "$addonNumber" "$addonDescription"
      addonNumber=$((addonNumber + 1))
   done

   while true; do
      read -r -p "Enter addon numbers separated by spaces(1 2 3) or commas(1,2,3) or * for all: " addonChoice
      addonChoice=${addonChoice//,/ }
      selectedGenericAddons=()

      if [[ "$addonChoice" == "*" ]]; then
         for addonName in "${!genericAddons[@]}"; do
            selectedGenericAddons["$addonName"]=1
         done
         break
      fi

      invalidAddon=""
      for selectedAddon in $addonChoice; do
         if [[ "$selectedAddon" =~ ^[0-9]+$ ]] && [[ "$selectedAddon" -gt 0 && "$selectedAddon" -lt "$addonNumber" ]]; then
            selectedIndex="${addonNames[$selectedAddon]}"
            selectedGenericAddons["$selectedIndex"]=1
         else
            invalidAddon="$selectedAddon"
            break
         fi
      done

      if [[ -n "$invalidAddon" ]]; then
         selectedGenericAddons=()
         echo "Unknown addon number: $invalidAddon"
         echo "Choose a number from 1 to $((addonNumber - 1)), or * for all."
         continue
      fi

      if [[ ${#selectedGenericAddons[@]} -eq 0 ]]; then
         echo "Please select at least one addon."
         continue
      fi

      break
   done

   if ! plugWaywallHandler; then
      echo "User declined plugin backup; addon setup cannot continue."
      return 1
   fi

   append_log i "Selected generic addons: ${!selectedGenericAddons[*]}"
   echo "Selected addons: ${!selectedGenericAddons[*]}"
   title_print "Plugin Addons Setup Complete"
}

function mainMenu {
   local menuChoice=""

   while true; do
      title_print "Snaws Waywall Setup"
      echo "1) Waywall and Prism setup"
      echo "2) Generic config plugins using plug.waywall"
      echo "q) Quit"
      read -r -p "Choose an option: " menuChoice

      case "$(to_lowercase "$menuChoice")" in
         1)
            osHandler || return 1
            waywallConfigHandler || return 1
            title_print "Waywall and Prism Setup Complete"
            return 0
            ;;
         2)
            genericConfigAddonsHandler || return 1
            return 0
            ;;
         q|quit)
            echo "Exiting."
            return 0
            ;;
         *)
            echo "Invalid choice. Please choose 1, 2, or q."
            ;;
      esac
   done
}

mainMenu