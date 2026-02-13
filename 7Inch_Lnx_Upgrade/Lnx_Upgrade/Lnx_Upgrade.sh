#!/bin/sh
set -e

echo "**********************************************************"
echo "*************     LINUX UPGRADE SCRIPT     ***************"
echo "**********************************************************"

# ==========================================================
# Paths
# ==========================================================
BIN_PATH="/root/Lnx_Upgrade/Lnx_Upgrade"

UBOOT_FILE="$BIN_PATH/u-boot_org.imx"
ROOTFS_TAR="$BIN_PATH/rootfs.tar"
DTB_FILE="$BIN_PATH/imx6dl-kb-nextgen.dtb"
KERNEL_FILE="$BIN_PATH/zImage"
VTC3000_FOLDER="$BIN_PATH/../VTC3000QT"
S20PSPLASH_FILE="$BIN_PATH/S20psplash"
S20KBQtAPP_FILE="$BIN_PATH/S23KBQtApp"
SPLASH_FILE="$BIN_PATH/psplash"
CP_QT_FILES="$BIN_PATH/copy_QT_Files_1v0.sh"
SIB_UPDATE="$BIN_PATH/auto_SIB_Boot_1v0.sh"

# ==========================================================
# eMMC Devices
# ==========================================================
EMMC_DEV="/dev/mmcblk2"
EMMC_BOOT_DEV="/dev/mmcblk2boot0"
EMMC_FORCE_RO="/sys/class/block/mmcblk2boot0/force_ro"

# ==========================================================
# Partitions
# ==========================================================
P1="${EMMC_DEV}p1"   # BOOT
P2="${EMMC_DEV}p2"   # rootfs
P3="${EMMC_DEV}p3"   # bkupBOOT
P5="${EMMC_DEV}p5"   # bkuprootfs
P6="${EMMC_DEV}p6"   # appbkup

MNT="/mnt/emmc"
mkdir -p $MNT

# ==========================================================
# Sanity checks
# ==========================================================
[ -b "$EMMC_DEV" ] || { echo "INFO: eMMC not found"; }
[ -f "$ROOTFS_TAR" ] || { echo "INFO: rootfs.tar not found"; }
[ -f "$KERNEL_FILE" ] || { echo "INFO: zImage not found"; }
[ -f "$DTB_FILE" ] || { echo "INFO: DTB not found"; }
[ -f "$UBOOT_FILE" ] || { echo "INFO: u-boot_org.imx not found"; }

# ==========================================================
# Unmount everything
# ==========================================================
echo ">>> Unmounting eMMC partitions"
for p in $P1 $P3 $P5 $P6; do
    mount | grep -q "$p" && umount -f "$p"
done
sync

# ==========================================================
# Upgrade the Kernel and DTB
# ==========================================================
if [ -f "$KERNEL_FILE" ]; then
	echo ">>> Copying Kernel Image"
	mount $P3 $MNT
	cp $KERNEL_FILE $MNT/
	sync
	umount $MNT
	sync
else
    echo "$KERNEL_FILE NOT found"
fi

# ==========================================================
# Upgrade the DTB
# ==========================================================
if [ -f "$DTB_FILE" ]; then
	echo ">>> Copying Kernel Image"
	mount $P3 $MNT
	cp $DTB_FILE $MNT/
	sync
	umount $MNT
	sync
else
    echo "$DTB_FILE NOT found"
fi

# ==========================================================
# Format partitions only if we have rootfs.tar
# ==========================================================
if [ -f "$ROOTFS_TAR" ]; then
    echo "rootfs.tar exists"
	echo ">>> Formatting partitions"
	mkfs.ext4 -F -L "bkuprootfs" $P5
	sync
# ==========================================================
# Extract rootfs (New Rootfs)
# ==========================================================
	echo ">>> Extracting New rootfs"
	mount $P5 $MNT
	tar -xvf $ROOTFS_TAR -C $MNT
	chown -R root:root $MNT
	sync
	sync
	echo ">>>Copying psplash & Qt Default app"
	rm -rf "$MNT/root/VTC3000QT"
	sync
	cp -r "$VTC3000_FOLDER" "$MNT/root/VTC3000QT"
	chmod -R +x "$MNT/root/VTC3000QT"
	sync
	cp -r "$SPLASH_FILE" "$MNT/usr/bin/psplash"
	chmod + "$MNT/usr/bin/psplash"
	sync
	cp -r "$CP_QT_FILES" "$MNT/opt/copy_QT_Files_1v0.sh"
	cp -r "$SIB_UPDATE" "$MNT/opt/auto_SIB_Boot_1v0.sh"
	cp -r "$S20PSPLASH_FILE" "$MNT/etc/init.d/S20psplash"
	cp -r "$S20KBQtAPP_FILE" "$MNT/etc/init.d/S23KBQtApp"
	chmod + "$MNT/opt/copy_QT_Files_1v0.sh"
	chmod + "$MNT/opt/auto_SIB_Boot_1v0.sh"
	chmod + "$MNT/etc/init.d/S20psplash"
	chmod + "$MNT/etc/init.d/S23KBQtApp"
	sync
	umount $MNT
	sync
else
    echo "rootfs.tar NOT found"
fi

# ==========================================================
# Flash U-Boot to eMMC boot0
# ==========================================================
echo ">>> Writing U-Boot to eMMC boot0"

echo 0 > $EMMC_FORCE_RO
dd if=$UBOOT_FILE of=$EMMC_BOOT_DEV bs=512 seek=2 conv=fsync
sync
echo 1 > $EMMC_FORCE_RO

# ==========================================================
# Done
# ==========================================================
rm -rf $MNT
rm -rf $BIN_PATH
sync
echo "**********************************************************"
echo "*************** eMMC FLASH COMPLETED ********************"
echo "**********************************************************"

fdisk -l $EMMC_DEV
