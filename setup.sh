#!/bin/bash


if [[ ! -f ./.setup.sh.log ]]; then
   echo "Creating log file"
   touch ./.setup.sh.log
   ls -l ./.setup.sh.log
   if [[ ! -f ./.setup.sh.log ]]; then
      echo "[ERROR] Failed to create log file"
      exit 1
   fi
elif [[ -f ./.setup.sh.log ]]; then
   rm -f ./.setup.sh.log
   if [[ -f ./.setup.sh.log ]]; then
      echo "[ERROR] Failed to delete log file"
      exit 1
   fi
   echo "Creating log file"
   touch ./.setup.sh.log
   ls -l ./.setup.sh.log
   if [[ ! -f ./.setup.sh.log ]]; then
      echo "[ERROR] Failed to create log file"
      exit 1
   fi
fi


# Precheck for Fedora
architecture=$(uname -m)
if [[ $architecture != "x86_64" ]]; then
   echo "[ERROR] This script supports only x86_64 architecture"
   exit 1
fi

fedoraString=$(grep ^ID= /etc/os-release | cut -d "=" -f 2 | tr '[:upper:]' '[:lower:]')
fedoraVersion=$(($(grep ^VERSION_ID= /etc/os-release | cut -d "=" -f 2 )))
echo $fedoraString
echo $fedoraVersion

if [[ $fedoraString != "fedora" ]]; then
   echo "[ERROR] Currently this script is supports only Fedora"
   exit 1
fi 


function append_log {
   echo "$1" >> ./.setup.sh.log
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

declare -A setupChoices

setupChoices[installTemurinJDKS]=true
setupChoices[installWaywall]=true
setupChoices[useGenericConfig]=true
setupChoices[addOneShotCrosshair]=false
setupChoices[addNinbotOpenOnF3C]=false
# setting this true automatically sets up all parameters(greenboat, sens std deviation ) for boateye using godsens , 
# you still have to setup waywall sens using calculator provided in guide
setupChoices[ninbotboateyepresetup]=true

# set to used with URI parameter when launching through cmd for prism but it still requires usr input instead of auto downloading 
# so probably not going 
#to use it unless I find some alternative
MCSR_RANKED_PACK_URL="https://redlime.github.io/MCSRMods/modpacks/v4/MCSRRanked-Linux-1.16.1-Basic-w-SS.mrpack"

if [[ $fedoraVersion -lt 44 ]]; then
   echo "[ERROR] This script supports only Fedora 44 and above"
   exit 1
fi

title_print "Installing JDK and Prism Launcher (no user input required)"

# Fedora 44 and above
sudo dnf -y install adoptium-temurin-java-repository
adoptiumRepoAdded=$?
if [[ $adoptiumRepoAdded -ne 0 ]]; then
   append_log "[ERROR] Failed to add adoptium repo"
   exit 1
fi
append_log "[INFO] Adoptium repo added successfully"

sudo fedora-third-party enable
fedoraThirdPartyEnabled=$?
if [[ $fedoraThirdPartyEnabled -ne 0 ]]; then
   append_log "[ERROR] Failed to enable fedora-third-party"
   exit 1
fi
append_log "[INFO] fedora-third-party enabled successfully"

sudo dnf -y makecache
dnfMakeCache=$?
if [[ $dnfMakeCache -ne 0 ]]; then
   append_log "[ERROR] Failed to update the dnf cache"
   exit 1
fi
append_log "[INFO] Cache updated successfully"

sudo dnf -y install temurin-21-jdk
jdkInstall=$?
if [[ $jdkInstall -ne 0 ]]; then
   append_log "[ERROR] Failed to install temurin-21-jdk"
   exit 1
fi
append_log "[INFO] temurin-21-jdk installed successfully"
JDK_VERSION_INSTALLED=21

if [[ ! -d "/usr/lib/jvm/temurin-21-jdk" ]]; then
   append_log "[ERROR] JDK not present at /usr/lib/jvm/temurin-21-jdk"
   exit 1
fi

append_log "[INFO] JDK is present at /usr/lib/jvm/temurin-21-jdk"
sudo alternatives --install /usr/bin/java java /usr/lib/jvm/temurin-21-jdk/bin/java 1
sudo alternatives --set java /usr/lib/jvm/temurin-21-jdk/bin/java
alternativesSet=$?
if [[ $alternativesSet -ne 0 ]]; then
   append_log "[ERROR] Failed to set alternatives for java"
   exit 1
fi
append_log "[INFO] Alternatives for java set successfully"

sudo dnf -y copr enable g3tchoo/prismlauncher
coprEnable=$?
if [[ $coprEnable -ne 0 ]]; then
   append_log "[ERROR] Failed to enable copr g3tchoo/prismlauncher"
   exit 1
fi
append_log "[INFO] Copr g3tchoo/prismlauncher enabled successfully"

sudo dnf -y install prismlauncher
prismInstall=$?
if [[ $prismInstall -ne 0 ]]; then
   append_log "[ERROR] Failed to install prismlauncher"
   exit 1
fi
append_log "[INFO] prismlauncher installed successfully"

title_print "Ranked Instance Path Setup (User Input Required)"
echo "Please launch prism launcher seperately and setup your ranked instance then at least launch the instance once"
echo "then copy the instance path and paste it here and press enter"
echo "If you have already done this, please enter the path to your ranked instance and press enter"
echo "example path: /home/snaw/.local/share/PrismLauncher/instances/MCSRRanked-Linux-1.16.1-Basic-w-SS"
while true; do
   read -p "Enter the path to your ranked instance:" rankedinstancepath
   if [[ -d "$rankedinstancepath" ]] && [[ -f "$rankedinstancepath/instance.cfg" ]]; then
      append_log "[INFO] Ranked instance path is valid and instance file is present: $rankedinstancepath"
      break
   fi

   append_log "[ERROR] Ranked instance path is invalid: $rankedinstancepath"
   echo ""
   echo ""
   echo "Ranked instance path is invalid, please try again or ctrl+c to exit"
done

title_print "Waywall installation and configuration (No user input required)"
append_log "[INFO] Starting waywall installation and configuration"

isWaywallInstalled=$(dnf list installed waywall 2>/dev/null | grep -c waywall)
if [[ $isWaywallInstalled -eq 1 ]]; then
   append_log "[INFO] Waywall is already installed, skipping installation"
elif [[ $isWaywallInstalled -eq 0 ]]; then
   append_log "[INFO] Waywall is not installed, proceeding with installation"
   append_log "[INFO] Downloading waywall.rpm"

   curl -L -o ./waywall.rpm https://github.com/tesselslate/waywall/releases/download/0.2026.06.13/waywall-0.5-1.fc42.x86_64.rpm
   waywallDownload=$?
   if [[ $waywallDownload -ne 0 ]]; then
      append_log "[ERROR] Failed to download waywall.rpm"
      exit 1
   fi
   append_log "[INFO] waywall.rpm downloaded successfully"

   sudo dnf -y install ./waywall.rpm
   waywallInstall=$?
   if [[ $waywallInstall -ne 0 ]]; then
      append_log "[ERROR] Failed to install waywall.rpm"
      exit 1
   fi

   title_print "Waywall verfication in progress"
   append_log "[INFO] Verifying waywall installation"
   if [[ -f /usr/bin/waywall ]]; then
      append_log "[INFO] waywall binary found at /usr/bin/waywall"
   else
      append_log "[ERROR] waywall binary not found at /usr/bin/waywall"
      exit 1
   fi
   if [[ -f /usr/local/lib64/waywall-glfw/libglfw.so ]]; then
      append_log "[INFO] waywall-glfw library found at /usr/local/lib64/waywall-glfw/libglfw.so"
   else
      append_log "[ERROR] waywall-glfw library not found at /usr/local/lib64/waywall-glfw/libglfw.so"
      exit 1
   fi
   append_log "[INFO] waywall.rpm installed successfully"
fi

append_log "[INFO] Starting waywall configuration (using generic config)"
append_log "[INFO] Using target user: $TARGET_USER at $TARGET_HOME"
append_log "[INFO] Backing up existing waywall config if present"
if [[ -d "$HOME"/.config/waywall ]]; then
   append_log "[INFO] Existing waywall config found, backing up to $HOME/.config/waywall.bkp"
   count=1
   while [[ -d "$HOME"/.config/waywall.bkp$count ]]; do
      count=$((count + 1))
      
   mv "$HOME"/.config/waywall "$HOME"/.config/waywall.bkp$count
   done
   append_log "[INFO] Existing waywall config backed up to $HOME/.config/waywall.bkp$count"
fi

sudo dnf -y install git
didGitInstall=$?
if [[ $didGitInstall -ne 0 ]]; then
   append_log "[ERROR] Failed to install git"
   exit 1
fi
append_log "[INFO] git installed successfully"

while true; do
   read -p "Do you want to use 1080(default/0) or 1440(1) config for waywall?(0/1): " waywallConfigChoice
   if [[ $waywallConfigChoice == "0" ]]; then
      append_log "[INFO] User chose 1080 config for waywall"
   elif [[ $waywallConfigChoice == "1" ]]; then
      append_log "[INFO] User chose 1440 config for waywall"
   else
      append_log "[ERROR] Invalid choice for waywall config, please try again"
      echo ""
      echo ""
      echo "Invalid choice for waywall config, please try again or ctrl+c to exit"
      continue
   fi
   break
done
if [[ ! -d "$HOME"/.config ]]; then
   append_log "[INFO] Creating .config directory at $HOME/.config"
   mkdir -p "$HOME"/.config
   mkdirSuccess=$?
   if [[ $mkdirSuccess -ne 0 ]]; then
      append_log "[ERROR] Failed to create .config directory at $HOME/.config"
      exit 1
   fi
   append_log "[INFO] .config directory created successfully at $HOME/.config"
fi

if [[ -d "$HOME"/.config/waywall ]]; then
   # preemptively remove existing waywall config if present since we alread did backup above 
   rm -rf "$HOME"/.config/waywall
fi

if [[ $waywallConfigChoice == "0" ]]; then
   append_log "[INFO] Downloading 1080 config for waywall"
   git clone https://github.com/arjuncgore/waywall_generic_config.git "$HOME"/.config/waywall
   gitCloneSuccess=$?
   if [[ $gitCloneSuccess -ne 0 ]]; then
      append_log "[ERROR] Failed to clone waywall_generic_config repo"
      exit 1
   fi
   append_log "[INFO] waywall_generic_config repo cloned successfully at $HOME/.config/waywall"
elif [[ $waywallConfigChoice == "1" ]]; then
   append_log "[INFO] Downloading 1440 config for waywall"
   git clone -b 1440 https://github.com/arjuncgore/waywall_generic_config.git "$HOME"/.config/waywall
   gitCloneSuccess=$?
   if [[ $gitCloneSuccess -ne 0 ]]; then
      append_log "[ERROR] Failed to clone waywall_generic_config repo"
      exit 1
   fi
   append_log "[INFO] waywall_generic_config repo cloned successfully at $HOME/.config/waywall"
fi

title_print "Prism waywall configuration in progress"
append_log "[INFO] Configuring prism to use waywall"
read -p "Prism launcher and minecraft instance has to closed to write to config , please press any key to continue it will be automically closed if it is open:"

append_log "[INFO] Closing prism launcher if it is open"

prismids="$(ps -e | grep -c prismlauncher)"
if [[ $prismids -gt 0 ]]; then
   append_log "[INFO] Prism launcher is open, closing it"
   # I checked that killing prism it does kill minecraft instances so I am keeping it that way
   # here minecraft instances are also killed
   pkill -f prismlauncher
   if [[ $? -ne 0 ]]; then
      append_log "[ERROR] Failed to close prism launcher"
      exit 1
   fi
   append_log "[INFO] Prism launcher closed successfully"
else
   append_log "[INFO] Prism launcher is not open, proceeding with configuration"
fi

prismConfigFile="$rankedinstancepath/instance.cfg"
if [[ -f "$prismConfigFile" ]]; then
   append_log "[INFO] prism config file found at $prismConfigFile"
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
      ' "$prismConfigFile" > "./test.tmp" && mv -f "./test.tmp"  "$prismConfigFile"
   append_log "[INFO] prism config file updated successfully at $prismConfigFile"
   append_log "[INFO] updating permissions for prism config file at $prismConfigFile"
   chown "$TARGET_USER":"$TARGET_USER" "$prismConfigFile"
   chmod a+rw "$prismConfigFile"
   append_log "[INFO] permissions updated successfully for prism config file at $prismConfigFile"
else
   append_log "[ERROR] prism config file not found at $prismConfigFile"
   exit 1
fi

append_log "[INFO] finished"
title_print "Configuration finished"

   






