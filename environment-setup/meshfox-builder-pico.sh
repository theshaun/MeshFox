#!/bin/bash

# MeshFox builder script for Luckfox Pico
# Run this to set up your build environment and build the image. 
# You can also run this script with different arguments to just build certain steps, for example `./meshfox-builder-pico.sh build_rootfs` to just build the rootfs. 
# Run `./meshfox-builder-pico.sh help` for more information. 
#
# Based on Foxbuntu by Femtofox (https://github.com/femtofox/femtofox)

################ TODO ################
# Add more error handling
# Package selection with curses
# Switch chroot packages install
# Modify DTS etc to enable SPI1
######################################

if [[ $(id -u) != 0 ]]; then
  echo "This script must be run as root; use sudo"
  exit 1
fi

[ -f /etc/os-release ] && . /etc/os-release

if [ "$VERSION_ID" != "22.04" ] || [ "$NAME" != "Ubuntu" ]; then
    echo -e "This script is intended for Ubuntu 22.04, your operating system is not supported (but may work).\nPress Ctrl+C to cancel, or Enter to continue."
    read
fi

sudoer=$(echo $SUDO_USER)

################ BOARD CONFIGURATION ################
# Define board-specific settings here
declare -A BOARD_CONFIG

# Femtofox configuration
BOARD_CONFIG[femtofox_title]="Femtofox Board"
BOARD_CONFIG[femtofox_rootfs_path]="rootfs_uclibc_rv1106"
BOARD_CONFIG[femtofox_kernel_version]="5.10.160"
BOARD_CONFIG[femtofox_chroot_script]="/home/${sudoer}/meshfox/environment-setup/meshfox-femtofox.chroot"
BOARD_CONFIG[femtofox_defconfig]="femtofox_rv1106_linux_defconfig"
BOARD_CONFIG[femtofox_board_config]="BoardConfig-SD_CARD-Ubuntu-RV1103_Luckfox_Pico_Mini-IPC.mk"
BOARD_CONFIG[femtofox_radio_settings]="femtofox-radio-settings.json"

# Luckfox Pico Ultra configuration
BOARD_CONFIG[pico-ultra_title]="Luckfox Pico Ultra"
BOARD_CONFIG[pico-ultra_rootfs_path]="rootfs_uclibc_rv1106"
BOARD_CONFIG[pico-ultra_kernel_version]="5.10.160"
BOARD_CONFIG[pico-ultra_chroot_script]="/home/${sudoer}/meshfox/environment-setup/meshfox-pico-ultra.chroot"
BOARD_CONFIG[pico-ultra_defconfig]="luckfox_rv1106_linux_defconfig"
BOARD_CONFIG[pico-ultra_board_config]="BoardConfig-EMMC-Ubuntu-RV1106_Luckfox_Pico_Ultra-IPC.mk"
BOARD_CONFIG[pico-ultra_radio_settings]="pico-ultra-radio-settings.json"

# Default board (can be overridden by command line or environment variable)
TARGET_BOARD="${TARGET_BOARD:-femtofox}"

# Function to get board-specific config value
get_board_config() {
  local key="${TARGET_BOARD}_${1}"
  echo "${BOARD_CONFIG[$key]}"
}

###################################################

# Check if 'dialog' is installed, install it if missing
if ! command -v dialog &> /dev/null; then
  echo "The 'dialog' package is required to run this script. Press any key to install it."
  read -n 1 -s -r
  apt update && apt install -y dialog
fi

install_prerequisites() {
  echo "Setting up MeshFox build environment..."
  apt update
  apt install -y git ssh make gcc gcc-multilib g++-multilib module-assistant expect g++ gawk texinfo libssl-dev bison flex fakeroot cmake unzip gperf autoconf device-tree-compiler libncurses5-dev pkg-config bc python-is-python3 passwd openssl openssh-server openssh-client vim file cpio rsync qemu-user-static binfmt-support dialog
}

clone_repos() {
  echo "Cloning repos..."
  cd /home/${sudoer}/ || return 1

  clone_with_retries() {
    local repo_url="$1"
    local retries=3
    local count=0
    local success=0

    while [ $count -lt $retries ]; do
      echo "Attempting to clone $repo_url (Attempt $((count + 1))/$retries)"
      git clone "$repo_url" && success=1 && break
      count=$((count + 1))
      echo "Retrying..."
    done

    if [ $success -eq 0 ]; then
      echo "Failed to clone $repo_url after $retries attempts."
      return 1
    fi
  }

  clone_with_retries "https://github.com/theshaun/luckfox-pico.git" || return 1
  clone_with_retries "https://github.com/theshaun/meshfox.git" || return 1

  return 0
}

build_env() {
  echo "Setting up SDK env..."
  cp /home/${sudoer}/luckfox-pico/project/cfg/BoardConfig_IPC/$(get_board_config board_config) /home/${sudoer}/luckfox-pico/.BoardConfig.mk
  cd /home/${sudoer}/luckfox-pico
  ./build.sh env
}

build_uboot() {
  echo "Building uboot..."
  cd /home/${sudoer}/luckfox-pico
  ./build.sh uboot
}

build_rootfs() {
  echo "Building rootfs..."
  cd /home/${sudoer}/luckfox-pico
  ./build.sh rootfs
}

build_firmware() {
  echo "Building firmware..."
  cd /home/${sudoer}/luckfox-pico/
  ./build.sh firmware
}

sync_meshfox_changes() {
  SOURCE_DIR=/home/${sudoer}/meshfox/meshfox
  DEST_DIR=/home/${sudoer}/luckfox-pico

  cd "$SOURCE_DIR" || exit
  git pull

  cd "$SOURCE_DIR" || exit
  git ls-files > /tmp/source_files.txt

  echo "Merging in MeshFox modifications..."
  rsync -aHAXv --progress --keep-dirlinks --itemize-changes /home/${sudoer}/meshfox/meshfox/sysdrv/ /home/${sudoer}/luckfox-pico/sysdrv/
  rsync -aHAXv --progress --keep-dirlinks --itemize-changes /home/${sudoer}/meshfox/meshfox/project/ /home/${sudoer}/luckfox-pico/project/
  rsync -aHAXv --progress --keep-dirlinks --itemize-changes /home/${sudoer}/meshfox/meshfox/output/image/ /home/${sudoer}/luckfox-pico/output/image/

  while read -r file; do
      src_file="$SOURCE_DIR/$file"
      dest_file="$DEST_DIR/$file"

      if [ ! -f "$src_file" ] && [ -f "$dest_file" ]; then
          echo "Deleting $dest_file as it is no longer in the git repository."
          rm -f "$dest_file"
      fi
  done < /tmp/source_files.txt

  rm /tmp/source_files.txt

  echo "Synchronization complete."
}

build_kernelconfig() {
  echo "Building kernelconfig... Please exit without making any changes unless you know what you are doing."
  echo "Press any key to continue building the kernel..."
  read -n 1 -s -r
  cd /home/${sudoer}/luckfox-pico
  ./build.sh kernelconfig
  ./build.sh kernel
}

modify_kernel() {
  echo "Building kernel... ."
  echo "After making kernel configuration changes, make sure to save as .config (default) before exiting."
  echo "Press any key to continue building the kernel..."
  read -n 1 -s -r
  
  local kernel_version=$(get_board_config kernel_version)
  local rootfs_path=$(get_board_config rootfs_path)
  
  cd /home/${sudoer}/luckfox-pico
  ./build.sh kernelconfig
  ./build.sh kernel
  build_rootfs
  build_firmware
  cp /home/${sudoer}/luckfox-pico/sysdrv/out/kernel_drv_ko/* /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/lib/modules/${kernel_version}/
  echo "Entering chroot..."
  mount --bind /proc /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/proc
  mount --bind /sys /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/sys
  mount --bind /dev /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/dev
  mount --bind /dev/pts /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/dev/pts
  chroot /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path} /bin/bash <<EOF
echo "Inside chroot environment..."
echo "Setting up kernel modules..."
depmod -a ${kernel_version}
echo "Cleaning up chroot..."
apt clean && rm -rf /var/lib/apt/lists/* && rm -rf /tmp/* && rm -rf /var/tmp/* && find /var/log -type f -exec truncate -s 0 {} + && : > /root/.bash_history && history -c
exit
EOF

  umount /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/dev/pts
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/proc
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/sys
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/dev
  build_rootfs
  build_firmware
  create_image
}

rebuild_chroot() {  
  cp /home/${sudoer}/meshfox/environment-setup/distributables/radio-settings/$(get_board_config radio_settings) /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/var/lib/pymc_repeater/radio-settings-dist.json
  chroot_script=${CHROOT_SCRIPT:-$(get_board_config chroot_script)}
  if [[ ! -f $chroot_script ]]; then
    echo "Error: Chroot script $chroot_script not found."
    exit 1
  fi

  echo "Press any key to wipe and rebuild chroot..."
  read -n 1 -s -r
  cd /home/${sudoer}/luckfox-pico
  ./build.sh clean rootfs
  cd /home/${sudoer}/
  rsync -aHAXv --progress --keep-dirlinks --itemize-changes /home/${sudoer}/meshfox/meshfox/sysdrv/ /home/${sudoer}/luckfox-pico/sysdrv/
  rsync -aHAXv --progress --keep-dirlinks --itemize-changes /home/${sudoer}/meshfox/meshfox/project/ /home/${sudoer}/luckfox-pico/project/
  build_rootfs
  rsync -aHAXv --progress --keep-dirlinks --itemize-changes /home/${sudoer}/meshfox/meshfox/sysdrv/out/rootfs/ /home/${sudoer}/luckfox-pico/sysdrv/out/$(get_board_config rootfs_path)/
  build_firmware
  install_rootfs
  build_rootfs
  build_firmware
  create_image
}

inject_chroot() {  
  cp /home/${sudoer}/meshfox/environment-setup/distributables/radio-settings/$(get_board_config radio_settings) /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/var/lib/pymc_repeater/radio-settings-dist.json
  chroot_script=${CHROOT_SCRIPT:-$(get_board_config chroot_script)}
  if [[ ! -f $chroot_script ]]; then
    echo "Error: Chroot script $chroot_script not found."
    exit 1
  fi

  cp "$chroot_script" /home/${sudoer}/luckfox-pico/sysdrv/out/$(get_board_config rootfs_path)/tmp/chroot_script.sh
  chmod +x /home/${sudoer}/luckfox-pico/sysdrv/out/$(get_board_config rootfs_path)/tmp/chroot_script.sh

  echo "Press any key to continue entering chroot..."
  read -n 1 -s -r

  echo "Entering chroot and running commands..."

  mount --bind /proc /home/${sudoer}/luckfox-pico/sysdrv/out/$(get_board_config rootfs_path)/proc
  mount --bind /sys /home/${sudoer}/luckfox-pico/sysdrv/out/$(get_board_config rootfs_path)/sys
  mount --bind /dev /home/${sudoer}/luckfox-pico/sysdrv/out/$(get_board_config rootfs_path)/dev
  mount --bind /dev/pts /home/${sudoer}/luckfox-pico/sysdrv/out/$(get_board_config rootfs_path)/dev/pts
  chroot /home/${sudoer}/luckfox-pico/sysdrv/out/$(get_board_config rootfs_path) /tmp/chroot_script.sh
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/$(get_board_config rootfs_path)/dev/pts
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/$(get_board_config rootfs_path)/proc
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/$(get_board_config rootfs_path)/sys
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/$(get_board_config rootfs_path)/dev
  rm /home/${sudoer}/luckfox-pico/sysdrv/out/$(get_board_config rootfs_path)/tmp/chroot_script.sh
  build_rootfs
  build_firmware
  create_image

}

update_image() {
  build_env
  echo "Updating repo..."
  cd /home/${sudoer}/meshfox
  git pull
  cd /home/${sudoer}/
  sync_meshfox_changes
  build_kernelconfig
  build_rootfs
  build_firmware
  create_image
}

full_rebuild() {
  build_env
  build_uboot
  sync_meshfox_changes
  build_kernelconfig
  build_rootfs
  rsync -aHAXv --progress --keep-dirlinks --itemize-changes /home/${sudoer}/meshfox/meshfox/sysdrv/out/rootfs/ /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/
  build_firmware
  install_rootfs
  build_rootfs
  build_firmware
  create_image
}

install_rootfs() {
  echo "Modifying rootfs..."
  cd /home/${sudoer}/luckfox-pico/output/image
  echo "Copying kernel modules..."
  local kernel_version=$(get_board_config kernel_version)
  local rootfs_path=$(get_board_config rootfs_path)
  mkdir -p /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/lib/modules/${kernel_version}
  cp /home/${sudoer}/luckfox-pico/sysdrv/out/kernel_drv_ko/* /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/lib/modules/${kernel_version}/
  which qemu-arm-static

  cp /home/${sudoer}/meshfox/environment-setup/distributables/radio-settings/$(get_board_config radio_settings) /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/var/lib/pymc_repeater/radio-settings-dist.json

  chroot_script=${CHROOT_SCRIPT:-$(get_board_config chroot_script)}
  if [[ ! -f $chroot_script ]]; then
    echo "Error: Chroot script $chroot_script not found."
    exit 1
  fi

  cp "$chroot_script" /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/tmp/chroot_script.sh
  chmod +x /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/tmp/chroot_script.sh

  echo "Entering chroot and running commands..."
  cp /usr/bin/qemu-arm-static /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/usr/bin/
  mount --bind /proc /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/proc
  mount --bind /sys /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/sys
  mount --bind /dev /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/dev
  mount --bind /dev/pts /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/dev/pts
  chroot /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path} /tmp/chroot_script.sh
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/dev/pts
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/proc
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/sys
  umount /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/dev

  rm /home/${sudoer}/luckfox-pico/sysdrv/out/${rootfs_path}/tmp/chroot_script.sh
}

create_image() {
  echo "Creating final sdcard img..."
  cd /home/${sudoer}/luckfox-pico/output/image

  # File to modify
  ENVFILE=".env.txt"

  # Check if the file contains '6G(rootfs)'
  if grep -q '6G(rootfs)' "$ENVFILE"; then
      # Replace '6G(rootfs)' with '100G(rootfs)'
      sed -i 's/6G(rootfs)/100G(rootfs)/' "$ENVFILE"
      echo "Updated rootfs size from stock (6G) to 100G."
  else
      echo "No changes made to rootfs size because it has already been modified."
  fi

  chmod +x /home/${sudoer}/luckfox-pico/sysdrv/tools/pc/uboot_tools/mkenvimage
  /home/${sudoer}/luckfox-pico/sysdrv/tools/pc/uboot_tools/mkenvimage -s 0x8000 -p 0x0 -o env.img .env.txt

  #todo: output image name with datestamp and device type

  chmod +x /home/${sudoer}/luckfox-pico/output/image/blkenvflash
  /home/${sudoer}/luckfox-pico/output/image/blkenvflash /home/${sudoer}/meshfox/meshfox-pico.img
  if [[ $? -eq 2 ]]; then echo "Error, sdcard img failed to build..."; exit 2; else echo "meshfox-pico.img build completed."; fi
  ls -la /home/${sudoer}/meshfox/meshfox-pico.img
  du -h /home/${sudoer}/meshfox/meshfox-pico.img
}

sdk_install() {
  echo "Installing MeshFox SDK Disk Image Builder..."
  if [ -d /home/${sudoer}/meshfox ]; then
      echo "WARNING: ~/meshfox exists, this script will DESTROY and recreate it."
      echo "Press Ctrl+C to cancel, or Enter to continue."
      read
      rm -rf /home/${sudoer}/meshfox/meshfox
  fi
  if [ -d /home/${sudoer}/luckfox-pico ]; then
      echo "WARNING: ~/luckfox-pico exists, this script will DESTROY and recreate it."
      echo "Press Ctrl+C to cancel, or Enter to continue."
      read
      rm -rf /home/${sudoer}/luckfox-pico
  fi

  start_time=$(date +%s)
  install_prerequisites

  clone_repos || {
    echo "Failed to clone repositories. Exiting SDK installation."
    return 1
  }

  build_env
  build_uboot
  sync_meshfox_changes
  build_kernelconfig
  build_rootfs
  rsync -aHAXv --progress --keep-dirlinks --itemize-changes /home/${sudoer}/meshfox/meshfox/sysdrv/out/rootfs/ /home/${sudoer}/luckfox-pico/sysdrv/out/rootfs_uclibc_rv1106/
  build_firmware
  install_rootfs
  build_rootfs
  build_firmware
  create_image
  end_time=$(date +%s)
  elapsed=$(( end_time - start_time ))
  hours=$(( elapsed / 3600 ))
  minutes=$(( (elapsed % 3600) / 60 ))
  seconds=$(( elapsed % 60 ))
  printf "Environment installation time: %02d:%02d:%02d\\n" $hours $minutes $seconds
}

usage() {
  echo "The following functions are available in this script:"
  echo "To install the development environment use the arg 'sdk_install' and is intended to be run ONCE only."
  echo "To modify the kernel and build an updated image use the arg 'modify_kernel'."
  echo ""
  echo "Options:"
  echo "  --board <board_name>                Select target board (default: pico-mini). Available: pico-mini, pico-ultra"
  echo "  --chroot-script <path>              Specify a custom chroot script"
  echo ""
  echo "Functions: full_rebuild rebuild_chroot inject_chroot build_env sync_meshfox_changes build_kernelconfig install_rootfs build_rootfs build_uboot build_firmware create_image"
  echo ""
  echo "Examples:"
  echo "  sudo $0 sdk_install"
  echo "  sudo $0 --board pico-mini full_rebuild"
  echo "  sudo $0 --chroot-script /home/user/custom.chroot full_rebuild"
  exit 0
}

################### MENU SYSTEM ###################

# Parse command line options
while [[ $# -gt 0 ]]; do
  case "${1}" in
    --board)
      TARGET_BOARD="${2}"
      echo "Target board set to: ${TARGET_BOARD}"
      shift 2
      ;;
    --chroot-script)
      CHROOT_SCRIPT="${2}"
      echo "CHROOT_SCRIPT is set to '${CHROOT_SCRIPT}'"
      shift 2
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      # If it's not an option, it's a function name or invalid argument
      break
      ;;
  esac
done

if [[ "${1}" =~ ^(-h|--help|h|help)$ ]]; then
  usage
elif [[ -z ${1} ]]; then
  if ! command -v dialog &> /dev/null; then
    echo "The 'dialog' package is required to load the menu."
    echo "Please install it using: sudo apt install dialog"
    exit 1
  fi
  while true; do
    CHOICE=$(dialog --clear --no-cancel --backtitle "MeshFox SDK Builder: $(get_board_config title)" \
      --title "Main Menu" \
      --menu "Choose an action for the $(get_board_config title):" 20 60 12 \
      1 "Full Image Rebuild" \
      2 "Get Image Updates" \
      3 "Modify Kernel Menu" \
      4 "Rebuild Chroot" \
      5 "Inject Chroot Script (CAUTION)" \
      6 "Manual Build Environment" \
      7 "Manual Build U-Boot" \
      8 "Manual Build RootFS" \
      9 "Manual Build Firmware" \
      10 "Manual Create Final Image" \
      11 "SDK Install (Run this first.)" \
      12 "Exit" \
      2>&1 >/dev/tty)

    clear

    case $CHOICE in
      1) full_rebuild ;;
      2) update_image ;;
      3) modify_kernel ;;
      4) rebuild_chroot ;;
      5) inject_chroot ;;
      6) build_env ;;
      7) build_uboot ;;
      8) build_rootfs ;;
      9) build_firmware ;;
      10) create_image ;;
      11) sdk_install ;;
      12) echo "Exiting..."; break ;;
      *) echo "Invalid option, please try again." ;;
    esac

    echo "Menu selection completed. Press any key to return to the menu."
    read -n 1 -s -r
  done
else
  if declare -f "${1}" > /dev/null; then
    "${1}"
  else
    echo "Error: Function '${1}' not found."
    usage
    exit 1
  fi
fi

exit 0
