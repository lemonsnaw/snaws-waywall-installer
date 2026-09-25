#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$PWD/.setup.sh.log"
NINBOT_GREENBOAT_GODSENS_XMLURI="https://raw.githubusercontent.com/lemonsnaw/snaws-waywall-installer/refs/heads/main/prefs.xml"
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
   if [[ $1 == "i" ]]; then
      echo "[INFO] $2" >> "$LOG_FILE"
   elif [[ $1 == "e" ]]; then
      echo "[ERROR] $2" >> "$LOG_FILE"
   else
      echo "[UNKNOWN] $1" >> "$LOG_FILE"
   fi
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



# set to used with URI parameter when launching through cmd for prism but it still requires usr input instead of auto downloading 
# so probably not going 
#to use it unless I find some alternative
MCSR_RANKED_PACK_URL="https://redlime.github.io/MCSRMods/modpacks/v4/MCSRRanked-Linux-1.16.1-Basic-w-SS.mrpack"

if [[ $fedoraVersion -lt 44 ]]; then
   echo "[ERROR] This script supports only Fedora 44 and above"
   exit 1
fi

function waywallPrismSetup {
title_print "Installing JDK and Prism Launcher (no user input required)"

# Fedora 44 and above
sudo dnf -y install adoptium-temurin-java-repository
adoptiumRepoAdded=$?
if [[ $adoptiumRepoAdded -ne 0 ]]; then
   append_log e "Failed to add adoptium repo"
   exit 1
fi
append_log i "Adoptium repo added successfully"

sudo fedora-third-party enable
fedoraThirdPartyEnabled=$?
if [[ $fedoraThirdPartyEnabled -ne 0 ]]; then
   append_log e "Failed to enable fedora-third-party"
   exit 1
fi
append_log i "fedora-third-party enabled successfully"

sudo dnf -y makecache
dnfMakeCache=$?
if [[ $dnfMakeCache -ne 0 ]]; then
   append_log e "Failed to update the dnf cache"
   exit 1
fi
append_log i "Cache updated successfully"

sudo dnf -y install temurin-21-jdk
jdkInstall=$?
if [[ $jdkInstall -ne 0 ]]; then
   append_log e "Failed to install temurin-21-jdk"
   exit 1
fi
append_log i "temurin-21-jdk installed successfully"
JDK_VERSION_INSTALLED=21

if [[ ! -d "/usr/lib/jvm/temurin-21-jdk" ]]; then
   append_log e "JDK not present at /usr/lib/jvm/temurin-21-jdk"
   exit 1
fi

append_log i "JDK is present at /usr/lib/jvm/temurin-21-jdk"
sudo alternatives --install /usr/bin/java java /usr/lib/jvm/temurin-21-jdk/bin/java 1
sudo alternatives --set java /usr/lib/jvm/temurin-21-jdk/bin/java
alternativesSet=$?
if [[ $alternativesSet -ne 0 ]]; then
   append_log e "Failed to set alternatives for java"
   exit 1
fi
append_log i "Alternatives for java set successfully"

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

title_print "Ranked Instance Path Setup (User Input Required)"
echo "Please launch prism launcher seperately and setup your ranked instance then at least launch the instance once"
echo "then copy the instance path and paste it here and press enter"
echo "If you have already done this, please enter the path to your ranked instance and press enter"
echo "example path: /home/snaw/.local/share/PrismLauncher/instances/MCSRRanked-Linux-1.16.1-Basic-w-SS"
while true; do
   read -p "Enter the path to your ranked instance:" rankedinstancepath
   if [[ -d "$rankedinstancepath" ]] && [[ -f "$rankedinstancepath/instance.cfg" ]]; then
      append_log i "Ranked instance path is valid and instance file is present: $rankedinstancepath"
      break
   fi

   append_log e "Ranked instance path is invalid: $rankedinstancepath"
   echo ""
   echo ""
   echo "Ranked instance path is invalid, please try again or ctrl+c to exit"
done

title_print "Waywall installation and configuration (No user input required)"
append_log i "Starting waywall installation and configuration"

isWaywallInstalled=$(dnf list installed waywall 2>/dev/null | grep -c waywall)
if [[ $isWaywallInstalled -eq 1 ]]; then
   append_log i "Waywall is already installed, skipping installation"
elif [[ $isWaywallInstalled -eq 0 ]]; then
   append_log i "Waywall is not installed, proceeding with installation"
   append_log i "Downloading waywall.rpm"

   curl -L -o ./waywall.rpm https://github.com/tesselslate/waywall/releases/download/0.2026.06.13/waywall-0.5-1.fc42.x86_64.rpm
   waywallDownload=$?
   if [[ $waywallDownload -ne 0 ]]; then
      append_log e "Failed to download waywall.rpm"
      exit 1
   fi
   append_log i "waywall.rpm downloaded successfully"

   sudo dnf -y install ./waywall.rpm
   waywallInstall=$?
   if [[ $waywallInstall -ne 0 ]]; then
      append_log e "Failed to install waywall.rpm"
      exit 1
   fi

   title_print "Waywall verfication in progress"
   append_log i "Verifying waywall installation"
   if [[ -f /usr/bin/waywall ]]; then
      append_log i "waywall binary found at /usr/bin/waywall"
   else
      append_log e "waywall binary not found at /usr/bin/waywall"
      exit 1
   fi
   if [[ -f /usr/local/lib64/waywall-glfw/libglfw.so ]]; then
      append_log i "waywall-glfw library found at /usr/local/lib64/waywall-glfw/libglfw.so"
   else
      append_log e "waywall-glfw library not found at /usr/local/lib64/waywall-glfw/libglfw.so"
      exit 1
   fi
   append_log i "waywall.rpm installed successfully"
fi

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
      exit 1
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
      ' "$prismConfigFile" > "./test.tmp" && mv -f "./test.tmp"  "$prismConfigFile"
   append_log i "prism config file updated successfully at $prismConfigFile"
   append_log i "updating permissions for prism config file at $prismConfigFile"
   chown "$TARGET_USER":"$TARGET_USER" "$prismConfigFile"
   chmod a+rw "$prismConfigFile"
   append_log i "permissions updated successfully for prism config file at $prismConfigFile"
else
   append_log e "prism config file not found at $prismConfigFile"
   exit 1
fi
if [[ ! -d "$HOME/.java/.userPrefs/ninjabrainbot" ]]; then
   mkdir -p "$HOME/.java/.userPrefs/ninjabrainbot"
   if [[ $? -ne 0 ]]; then
      append_log e "Failed to create directory $HOME/.java/.userPrefs/ninjabrainbot; ninjabrainbot settings will be skipped"
   else
      append_log i "Created directory $HOME/.java/.userPrefs/ninjabrainbot for ninjabrainbot settings"
   fi
fi

if [[ -f "$HOME/.java/.userPrefs/ninjabrainbot/prefs.xml" ]]; then
   append_log i "prefs.xml already exists at $HOME/.java/.userPrefs/ninjabrainbot/prefs.xml, skipping modifications to it"
else
   if [[ -f ./prefs.xml ]]; then
      append_log i "prefs.xml found in current directory, copying to $HOME/.java/.userPrefs/ninjabrainbot/prefs.xml"
      cp ./prefs.xml "$HOME/.java/.userPrefs/ninjabrainbot/prefs.xml"
      if [[ $? -ne 0 ]]; then
         append_log e "Failed to copy prefs.xml to $HOME/.java/.userPrefs/ninjabrainbot/prefs.xml"
      else
         append_log i "Copied prefs.xml to $HOME/.java/.userPrefs/ninjabrainbot/prefs.xml"
      fi
   else
      append_log i "prefs.xml not found in current directory, downloading from $NINBOT_GREENBOAT_GODSENS_XMLURI"
      curl -L -o ./prefs.xml "$NINBOT_GREENBOAT_GODSENS_XMLURI"
      if [[ $? -ne 0 ]]; then
         append_log e "Failed to download prefs.xml from $NINBOT_GREENBOAT_GODSENS_XMLURI"
      else
         append_log i "Downloaded prefs.xml from $NINBOT_GREENBOAT_GODSENS_XMLURI"
         cp ./prefs.xml "$HOME/.java/.userPrefs/ninjabrainbot/prefs.xml"
         if [[ $? -ne 0 ]]; then
            append_log e "Failed to copyConfiguration downloaded prefs.xml to $HOME/.java/.userPrefs/ninjabrainbot/prefs.xml"
         else
            append_log i "Copied downloaded prefs.xml to $HOME/.java/.userPrefs/ninjabrainbot/prefs.xml"
         fi
      fi
   fi
fi

append_log i "finished"
title_print "Configuration finished"
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

   sudo dnf -y install git
   didGitInstall=$?
   if [[ $didGitInstall -ne 0 ]]; then
      append_log e "Failed to install git"
      exit 1
   fi
   append_log i "git installed successfully"
   local waywallConfigChoice="0"
   while true; do
      read -p "Do you want to use 1080p(default/0) or 1440p(1) config for waywall? [0/1]: " waywallConfigChoice
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

   local extrasLuaPath="$HOME/.config/waywall/extras.lua"
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
   else
      append_log i "No extras.lua found in generic config, creating default bootstrap version"
      echo "No extras.lua found, creating a default bootstrap version in $extrasLuaPath"
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

   if [[ -n "${selectedGenericAddons[showninbotf3c]+set}" ]]; then
      local ninbotPluginManifest="$SCRIPT_DIR/plugins/ww_ninbot_f3c.lua"
      local installedPluginsPath="$HOME/.config/waywall/plugins"

      if [[ ! -f "$ninbotPluginManifest" ]]; then
         append_log e "ww_ninbot_f3c plugin manifest is missing from $SCRIPT_DIR/plugins"
         echo "ww_ninbot_f3c plugin manifest is missing from $SCRIPT_DIR/plugins"
         return 1
      fi

      if ! cp "$ninbotPluginManifest" "$installedPluginsPath/ww_ninbot_f3c.lua"; then
         append_log e "Failed to install ww_ninbot_f3c plugin"
         echo "Failed to install ww_ninbot_f3c plugin"
         return 1
      fi

      append_log i "Installed ww_ninbot_f3c plugin"
      echo "Installed ww_ninbot_f3c plugin"
   fi

   return 0
}


function genericConfigAddonsHandler {
   title_print "Generic config Addons Setup"

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
   for addonName in "${!genericAddons[@]}"; do      addonNames[$addonNumber]="$addonName"
      IFS='|' read -r _ addonDescription addonType <<< "${genericAddons[$addonName]}"
      printf '  %-18s %s\n' "$addonNumber" "$addonDescription"
      addonNumber=$((addonNumber + 1))
   done

   while true; do
      read -r -p "Enter addon numbers separated by spaces or * for all: " addonChoice
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
         if [[ "$selectedAddon" =~ ^[0-9]+$ ]] && (( selectedAddon > 0 && selectedAddon < addonNumber )); then
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
}

function mainMenu {
   local menuChoice=""

   while true; do
      title_print "Snaws Waywall Setup"
      echo "1) Waywall and Prism setup"
      echo "2) Generic config addons using plug.waywall"
      echo "q) Quit"
      read -r -p "Choose an option: " menuChoice

      case "$(to_lowercase "$menuChoice")" in
         1)
            waywallPrismSetup || return 1
            waywallConfigHandler || return 1
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