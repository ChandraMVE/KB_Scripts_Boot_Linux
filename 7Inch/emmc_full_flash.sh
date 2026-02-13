#!/bin/sh
set -e

echo "**********************************************************"
echo "************* eMMC FULL LINUX FLASH SCRIPT ***************"
echo "**********************************************************"

# ==========================================================
# Paths
# ==========================================================
BIN_PATH="/root/KB_7Inch"

UBOOT_FILE="$BIN_PATH/u-boot.imx"
ROOTFS_TAR="$BIN_PATH/rootfs.tar"
DTB_FILE="$BIN_PATH/imx6dl-kb-nextgen.dtb"
KERNEL_FILE="$BIN_PATH/zImage"
SPLASH_FILE="$BIN_PATH/psplash"
VTC3000_FOLDER="$BIN_PATH/VTC3000QT"
S20PSPLASH_FILE="$BIN_PATH/S20psplash"
S20KBQtAPP_FILE="$BIN_PATH/S23KBQtApp"

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
[ -b "$EMMC_DEV" ] || { echo "ERROR: eMMC not found"; exit 1; }
[ -f "$ROOTFS_TAR" ] || { echo "ERROR: rootfs.tar missing"; exit 1; }
[ -f "$KERNEL_FILE" ] || { echo "ERROR: zImage missing"; exit 1; }
[ -f "$DTB_FILE" ] || { echo "ERROR: DTB missing"; exit 1; }
[ -f "$UBOOT_FILE" ] || { echo "ERROR: u-boot.imx missing"; exit 1; }

# ==========================================================
# Unmount everything
# ==========================================================
echo ">>> Unmounting eMMC partitions"
for p in $P1 $P2 $P3 $P5 $P6; do
    mount | grep -q "$p" && umount -f "$p"
done
sync

# ==========================================================
# Wipe old partition table
# ==========================================================
echo ">>> Wiping old partition table"
dd if=/dev/zero of=$EMMC_DEV bs=1M count=10 conv=fsync
sync

# ==========================================================
# Create partitions (BusyBox-safe fdisk)
# ==========================================================
echo ">>> Creating new partition layout"

(
echo o

echo n; echo p; echo 1; echo; echo +256M
echo n; echo p; echo 2; echo; echo +4G
echo n; echo p; echo 3; echo; echo +256M

echo n; echo e; echo 4; echo; echo

echo n; echo l; echo; echo +4G
echo n; echo l; echo; echo

echo w
) | fdisk $EMMC_DEV > /dev/null

sync
sleep 2

# ==========================================================
# Format partitions
# ==========================================================
echo ">>> Formatting partitions"

mkfs.fat -F32 -v -n "BOOT" $P1
mkfs.ext4 -F -L "rootfs" $P2
mkfs.fat -F32 -v -n "bkupBOOT" $P3
mkfs.ext4 -F -L "bkuprootfs" $P5
mkfs.ext4 -F -L "appbkup" $P6
sync

# ==========================================================
# Copy BOOT (primary)
# ==========================================================
echo ">>> Copying BOOT files"
mount $P1 $MNT
cp $KERNEL_FILE $DTB_FILE $MNT/
sync
umount $MNT
sync

# ==========================================================
# Extract rootfs (primary)
# ==========================================================
echo ">>> Extracting rootfs"
mount $P2 $MNT
tar -xvf $ROOTFS_TAR -C $MNT
chown -R root:root $MNT
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
cp -r "$S20PSPLASH_FILE" "$MNT/etc/init.d/S20psplash"
cp -r "$S20KBQtAPP_FILE" "$MNT/etc/init.d/S23KBQtApp"
chmod + "$MNT/etc/init.d/S20psplash"
chmod + "$MNT/etc/init.d/S23KBQtApp"
sync
umount $MNT
sync

# ==========================================================
# Copy BOOT (backup)
# ==========================================================
echo ">>> Copying backup BOOT"
mount $P3 $MNT
cp $KERNEL_FILE $DTB_FILE $MNT/
sync
umount $MNT
sync

# ==========================================================
# Extract rootfs (backup)
# ==========================================================
echo ">>> Extracting backup rootfs"
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
cp -r "$S20PSPLASH_FILE" "$MNT/etc/init.d/S20psplash"
cp -r "$S20KBQtAPP_FILE" "$MNT/etc/init.d/S23KBQtApp"
chmod + "$MNT/etc/init.d/S20psplash"
chmod + "$MNT/etc/init.d/S23KBQtApp"
umount $MNT
sync

# ==========================================================
# Prepare app backup partition
# ==========================================================
echo ">>> Preparing app backup partition"
mount $P6 $MNT
sync
umount $MNT
sync

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
echo "**********************************************************"
echo "*************** eMMC FLASH COMPLETED ********************"
echo "**********************************************************"

fdisk -l $EMMC_DEV
