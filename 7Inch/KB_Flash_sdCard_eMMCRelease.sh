#!/bin/bash
set -e

# ================= Colors =================
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
NC="\e[0m"

STARTTIME=$(date +%s)

BOOT_MNT="/mnt/boot_sd"
ROOTFS_MNT="/mnt/rootfs_sd"

# ================= Helper =================
stage() {
    echo
    echo -e "${YELLOW}========== $1 ==========${NC}"
}

# ================= Spinner =================
spinner() {
    local pid=$1
    local msg="$2"
    local spin='|/-\'
    local i=0

    tput civis
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r%s %c" "$msg" "${spin:$i:1}"
        sleep 0.1
    done
    printf "\r%s ✔\n" "$msg"
    tput cnorm
}

# Function to show sync progress with spinner
show_sync_progress() {
    local message="$1"
    local pid
    local spin='-\|/'
    local i=0
    
    echo -n "$message "
    
    # Start sync in background
    sync &
    pid=$!
    
    # Show spinner while sync is running
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r$message %s" "${spin:$i:1}"
        sleep 0.1
    done
    
    printf "\r$message ✓\n"
    wait $pid
}

# ================= Argument Check =================
if [[ $# -lt 1 ]]; then
    echo -e "${RED}Error: SD device not provided!${NC}"
    echo "Usage: $0 <SD_DEVICE>"
    echo "Example: $0 /dev/sdb"
    exit 1
fi

SD_DEVICE="$1"

# Partition naming (handles sdX and mmcblkX)
if [[ "$SD_DEVICE" =~ mmcblk ]]; then
    BOOT_PART="${SD_DEVICE}p1"
    ROOTFS_PART="${SD_DEVICE}p2"
else
    BOOT_PART="${SD_DEVICE}1"
    ROOTFS_PART="${SD_DEVICE}2"
fi

# ================= Image Path Selection =================
DEFAULT_PATH="$(pwd)"

echo
echo -e "${YELLOW}Image directory selection${NC}"
echo "Press ENTER to use current directory:"
echo "  ${DEFAULT_PATH}"
read -p "Or type full image path: " IMAGE_DRIVE_PATH

[[ -z "$IMAGE_DRIVE_PATH" ]] && IMAGE_DRIVE_PATH="$DEFAULT_PATH"

if [[ ! -d "$IMAGE_DRIVE_PATH" ]]; then
    echo -e "${RED}Error: Image directory does not exist!${NC}"
    exit 1
fi

echo -e "${GREEN}Using image path: $IMAGE_DRIVE_PATH${NC}"

# ================= Device Validation & Auto-Unmount =================
stage "Device Validation & Auto-Unmount "
if [[ ! -b "$SD_DEVICE" ]]; then
    echo -e "${RED}Error: Device $SD_DEVICE not found!${NC}"
    exit 1
fi

MOUNTED_PARTS=$(lsblk -ln -o NAME,MOUNTPOINT "$SD_DEVICE" | awk '$2 != "" {print $1}')

if [[ -n "$MOUNTED_PARTS" ]]; then
    stage "Unmounting Mounted Partitions"

    for part in $MOUNTED_PARTS; do
        echo -e "${YELLOW}Unmounting /dev/$part${NC}"
        sudo umount "/dev/$part" || {
            echo -e "${RED}Failed to unmount /dev/$part${NC}"
            exit 1
        }
    done
    
    if [ -d "$BOOT_MNT" ]; then
        stage "Delete mount folders $BOOT_MNT"
        sudo rm -rf "$BOOT_MNT"
    else
        stage "No Folder found $BOOT_MNT"
    fi

    if [ -d "$ROOTFS_MNT" ]; then
        stage "Delete mount folders $ROOTFS_MNT"
        sudo rm -rf "$ROOTFS_MNT"
    else
        stage "No Folder found $ROOTFS_MNT"	
    fi
else
    echo -e "${GREEN}No mounted partitions detected${NC}"
fi

sync

# ================= Package Check =================
REQUIRED_PKGS=(
    parted
    dosfstools
    e2fsprogs
    util-linux
    tar
    pv
    rsync
)

MISSING_PKGS=()

stage "Checking Required Packages"

for pkg in "${REQUIRED_PKGS[@]}"; do
    dpkg -s "$pkg" >/dev/null 2>&1 || MISSING_PKGS+=("$pkg")
done

if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Missing packages:${NC} ${MISSING_PKGS[*]}"

    stage "Checking Internet Connectivity"
    if ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${RED}Error: Internet required to install packages.${NC}"
        exit 1
    fi

    stage "Installing Missing Packages"

    echo -e "${YELLOW}Running apt-get update (non-fatal)...${NC}"
    if ! sudo apt-get update; then
       echo -e "${YELLOW}Warning: apt-get update failed.${NC}"
       echo -e "${YELLOW}Attempting installation using existing package cache...${NC}"
   fi

   if ! sudo apt-get install "${MISSING_PKGS[@]}"; then
  -l    echo -e "${RED}Error: Failed to install required packages:${NC} ${MISSING_PKGS[*]}"
      echo -e "${RED}Please fix APT repositories and retry.${NC}"
      exit 1
   fi
	
else
    echo -e "${GREEN}All required packages are installed.${NC}"
fi

# ================= SD Card Size =================
stage "Detecting SD Card Size"

SIZE_BYTES=$(lsblk -b -dn -o SIZE "$SD_DEVICE")
SIZE_GB=$((SIZE_BYTES / 1024 / 1024 / 1024))
echo -e "${GREEN}Detected size: ${SIZE_GB}GB${NC}"

# ================= Wipe =================
stage "Wiping Initial Sectors"

if [[ "$SIZE_GB" -lt 3 ]]; then
    sudo dd if=/dev/zero bs=1M count=10 2>/dev/null | \
    sudo pv -s 10M | \
    sudo dd of="$SD_DEVICE" conv=fsync
else
    sudo wipefs -a "$SD_DEVICE"
fi
sync

# ================= Partition =================
stage "Creating Partitions"
(
    sudo parted -s "$SD_DEVICE" mklabel msdos
    sudo parted -s "$SD_DEVICE" mkpart primary fat32 1MiB 251MiB
    sudo parted -s "$SD_DEVICE" mkpart primary ext4 251MiB 100%
    sudo partprobe "$SD_DEVICE"
) &
spinner $! "Partitioning SD card"
sleep 2

# ================= Format =================
stage "Formatting Partitions"

(sudo mkfs.vfat -F 32 -n BOOT "$BOOT_PART") &
spinner $! "Formatting BOOT partition"
(sudo mkfs.ext4 -F -L rootfs "$ROOTFS_PART") &
spinner $! "Formatting ROOTFS partition"

# ================= Flash U-Boot =================
stage "Flashing U-Boot"

UBOOT_IMG="${IMAGE_DRIVE_PATH}/u-boot.imx"
[[ -f "$UBOOT_IMG" ]] || { echo -e "${RED}u-boot.imx not found${NC}"; exit 1; }

UBOOT_SIZE=$(stat -c%s "$UBOOT_IMG")

sudo pv -s "$UBOOT_SIZE" "$UBOOT_IMG" | \
sudo dd of="$SD_DEVICE" bs=512 seek=2 conv=fsync
sync

# ================= Mount =================
stage "Mounting $SD_DEVICE"

sudo mkdir -p "$BOOT_MNT" "$ROOTFS_MNT"
sudo mount "$BOOT_PART" "$BOOT_MNT"
sudo mount "$ROOTFS_PART" "$ROOTFS_MNT"

# ================= Display Selection =================
stage "Select Display Type"

echo "1) 5 Inch"
echo "2) 7 Inch"
echo "3) 8 Inch"
echo "4) 10 Inch"
read -p "Enter choice [1-4]: " CHOICE

case "$CHOICE" in
    1) DISP="5Inch" ;;
    2) DISP="7Inch" ;;
    3) DISP="8Inch" ;;
    4) DISP="10Inch" ;;
    *) echo -e "${RED}Invalid selection${NC}"; exit 1 ;;
esac

DTB_SRC="${IMAGE_DRIVE_PATH}/imx6dl-kb-nextgen-${DISP}.dtb"
ROOTFS_TAR="${IMAGE_DRIVE_PATH}/buildroot_sdboot/rootfs.tar"

[[ -f "$DTB_SRC" ]] || { echo -e "${RED}DTB missing${NC}"; exit 1; }
[[ -f "$ROOTFS_TAR" ]] || { echo -e "${RED}rootfs.tar missing${NC}"; exit 1; }

# ================= Copy Boot Files =================
stage "Copying Boot Files"

sudo rsync -rltD --no-owner --no-group --progress \
    "$IMAGE_DRIVE_PATH/zImage" "$BOOT_MNT/"

sudo rsync -rltD --no-owner --no-group --progress \
    "$DTB_SRC" "$BOOT_MNT/imx6dl-kb-nextgen.dtb"

sudo rsync -rltD --no-owner --no-group --progress \
    "$UBOOT_IMG" "$BOOT_MNT/"

# Data sync after copy with progress
show_sync_progress "Copying Boot Files"

# ================= Extract RootFS =================
stage "Extracting Root Filesystem"

ROOTFS_SIZE=$(stat -c%s "$ROOTFS_TAR")

sudo pv -s "$ROOTFS_SIZE" "$ROOTFS_TAR" | \
	sudo tar -xpf - -C "$ROOTFS_MNT"

# Data sync after copy with progress
show_sync_progress "Syncing data to storage"

# ================= Copy Display Folder =================
stage "Copying Display Folder to /root"

sudo mkdir -p "$ROOTFS_MNT/root"
sudo rsync -ah --progress \
    "$IMAGE_DRIVE_PATH/KB_${DISP}/" \
    "$ROOTFS_MNT/root/KB_${DISP}/"

stage "Copying psplash & Qt Default app"
rm -rf "$ROOTFS_MNT/root/VTC3000QT"
sync
sudo cp -r "$IMAGE_DRIVE_PATH/KB_${DISP}/VTC3000QT" "$ROOTFS_MNT/root/VTC3000QT"
chmod -R +x "$ROOTFS_MNT/root/VTC3000QT"
sync
sudo cp -r "$IMAGE_DRIVE_PATH/KB_${DISP}/psplash" "$ROOTFS_MNT/usr/bin/psplash"
chmod + "$ROOTFS_MNT/usr/bin/psplash"
sync
sudo cp -r "$IMAGE_DRIVE_PATH/KB_${DISP}/S20psplash" "$ROOTFS_MNT/etc/init.d/S20psplash"
chmod + "$ROOTFS_MNT/etc/init.d/S20psplash"
sync
sudo cp -r "$IMAGE_DRIVE_PATH/KB_${DISP}/emmc_full_flash.sh" "$ROOTFS_MNT/root/emmc_full_flash.sh"
chmod + "$ROOTFS_MNT/root/emmc_full_flash.sh"
sync
sudo cp -r "$IMAGE_DRIVE_PATH/Debug_Leds.sh" "$ROOTFS_MNT/root/Debug_Leds.sh"
chmod + "$ROOTFS_MNT/root/Debug_Leds.sh"
sync
sudo cp -r "$IMAGE_DRIVE_PATH/S99flash_emmc" "$ROOTFS_MNT/etc/init.d/S99flash_emmc"
chmod 755 "$ROOTFS_MNT/etc/init.d/S99flash_emmc"
sync

# Data sync after copy with progress
show_sync_progress "Copying Display Folder to /root"

# ================= Cleanup =================
stage "Finalizing"

sudo umount "$BOOT_MNT"
sudo umount "$ROOTFS_MNT"
sudo rm -rf "$BOOT_MNT" "$ROOTFS_MNT"

ENDTIME=$(date +%s)
DURATION=$((ENDTIME - STARTTIME))

echo
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN} SD Card Flashing Completed Successfully ${NC}"
echo -e "${GREEN} Time Taken: ${DURATION} seconds ${NC}"
echo -e "${GREEN}=====================================${NC}"
