#!/bin/sh

APP_DIR='/root/VTC3000QT'
usbdev='/dev/sda1'
UPGRADE_LNX_COMPLETE='/opt/lnx_Upgrade_critical'
UPGRADE_LNX_FAIL='/opt/Upgrade_failed'
UPGRADEING_LNX='/opt/Upgrade'
EMMC_DEV="/dev/mmcblk2"
EMMC_BOOT_DEV="/dev/mmcblk2boot0"
EMMC_FORCE_RO="/sys/class/block/mmcblk2boot0/force_ro"
UBOOT_FILE="/tmp/u-boot.imx"

export QT_QPA_PLATFORM=linuxfb:fb=/dev/fb0:size=1024x600:mmSize=1024x600

if [ -b $usbdev ];then
	echo "#####################################"
	echo "      SCRIPT TO UPGRADE FileSystem   "
	echo "#####################################"
	echo "mount the pendrive"
	PenDriveMountPath='/root/PenDriveMount'
	mkdir -p $PenDriveMountPath
	mount $usbdev $PenDriveMountPath
	sleep 2
	sync

	CHECK_FILE='/root/PenDriveMount/CheckMe.txt'
	CHECK_FILE_FS='/root/PenDriveMount/copy_QT_Files_1v0.sh'
	CHECK_FILE_LNX='/root/PenDriveMount/Lnx_Upgrade/Lnx_Upgrade.txt'
	
	if [ -x $CHECK_FILE_LNX ]; then
		echo "#####################################"
		echo "##########   LINUX UPGRADE   ########"
		echo "#####################################"
		"$UPGRADEING_LNX"	&
		if [ -b /dev/mmcblk2p2 ]; then			
			echo "mmcblk2p2 mount"
			mkdir -p /root/Lnx_Upgrade
			mount /dev/mmcblk2p2 /root/Lnx_Upgrade
			sync
			# ==========================================================
			# Backup VTC3000 current application
			# ==========================================================
			echo "Backup current VTC3000 started"
			rm -rf /root/Lnx_Upgrade/root/Lnx_Upgrade
			mkdir -p /root/Lnx_Upgrade/root/Lnx_Upgrade
			cp -r /root/VTC3000QT /root/Lnx_Upgrade/root/Lnx_Upgrade/VTC3000QT
			sync
			echo "Backup current VTC3000 completed"
			
			# ==========================================================
			# Copy New Linux files
			# ==========================================================
			echo "Copy New Linux files started"
			cp -r /root/PenDriveMount/Lnx_Upgrade /root/Lnx_Upgrade/root/Lnx_Upgrade
			sync
			echo "Copy New Linux files completed"
			
			echo "copy S22Lnx_Upgrade"
			cp -r $PenDriveMountPath/Lnx_Upgrade/S22Lnx_Upgrade /root/Lnx_Upgrade/etc/init.d/
			sync			
			chmod 755 /root/Lnx_Upgrade/etc/init.d/S22Lnx_Upgrade
			sync
			
			echo "copy Lnx_Upgrade.sh"
			cp -r $PenDriveMountPath/Lnx_Upgrade/Lnx_Upgrade.sh /root/Lnx_Upgrade/root/
			sync			
			chmod 755 /root/Lnx_Upgrade/root/Lnx_Upgrade.sh
			sync
			
			umount /root/Lnx_Upgrade
			sync
			rm -rf /root/Lnx_Upgrade
			sync
			echo "Unmounting mmcblk2p2 partition"
			sync
			
			# ==========================================================
			# Flash U-Boot to eMMC boot0
			# ==========================================================
			echo ">>> Copy U-Boot to tmp"
			cp -r $PenDriveMountPath/Lnx_Upgrade/u-boot_bk.imx /tmp/u-boot.imx
			sync
						
			if [ -x /tmp/u-boot.imx ]; then
				echo ">>> Writing U-Boot to eMMC boot0"			
				echo 0 > $EMMC_FORCE_RO
				dd if=$UBOOT_FILE of=$EMMC_BOOT_DEV bs=512 seek=2 conv=fsync
				sync
				echo 1 > $EMMC_FORCE_RO
			else
				echo ">>> U-Boot not found Linux FS will fail"	
				kill -9 $(pidof Upgrade)
				"$UPGRADE_LNX_FAIL"	&
				sleep 100000000
				wait
			fi									
			rm -rf $PenDriveMountPath/Lnx_Upgrade/Lnx_Upgrade.txt
			rm -rf $PenDriveMountPath/CheckMe.txt
			sync
			umount $PenDriveMountPath
			echo "Unmounting USB"
			sync
			kill -9 $(pidof Upgrade)
			"$UPGRADE_LNX_COMPLETE"	&
			sleep 100000000
			wait			
		else
			echo "mmcblk2p6 not present do nothing"
		fi
	fi
	
	if [ -x $CHECK_FILE ]; then

		#echo 0 > /etc/rotation
		rm -rf $APP_DIR
		mkdir -p $APP_DIR

		sleep 2	
		if [ -x $CHECK_FILE_FS ]; then
			echo "#####################################"
			echo "##########CRITICAL FS UPGRADE########"
			echo "#####################################"
			cp -r $PenDriveMountPath/copy_QT_Files_1v0.sh $APP_DIR/
			cp -r $PenDriveMountPath/S21BootProgress $APP_DIR/
			cp -r $PenDriveMountPath/Upgrade_complete $APP_DIR/
			cp -r $PenDriveMountPath/Upgrade_failed $APP_DIR/
			cp -r $PenDriveMountPath/lnx_Upgrade_critical $APP_DIR/			
			chmod 777 /opt/copy_QT_Files_1v0.sh
			cp $APP_DIR/copy_QT_Files_1v0.sh /opt/
			cp $APP_DIR/S21BootProgress /etc/init.d/
			sync
			chmod 755 /etc/init.d/S21BootProgress
			rm -rf $PenDriveMountPath/copy_QT_Files_1v0.sh
			rm -rf $PenDriveMountPath/S21BootProgress
			umount $PenDriveMountPath
			umount /dev/sda*
			sync
			rm -rf $PenDriveMountPath
			echo "#####################################"
			echo "#############--REBOOT--##############"
			echo "#####################################"
			chmod 755 $APP_DIR/Upgrade_complete
			chmod 755 $APP_DIR/Upgrade_failed
			chmod 755 $APP_DIR/lnx_Upgrade_critical
			cd $APP_DIR
			export QT_QPA_PLATFORM=linuxfb:fb=/dev/fb0:size=1024x600:mmSize=1024x600
			./lnx_Upgrade_critical &
			"$UPGRADE_LNX_COMPLETE"	&
			sleep 100000000
			wait
		fi

		echo "#####################################"
		echo "##########NORMAL BOOT USB UPGARDE#####"
		echo "#####################################"
		cp -r $PenDriveMountPath/auto_SIB_Boot_1v0.sh $APP_DIR/
		cp -r $PenDriveMountPath/SIB.bin $APP_DIR/
		cp -r $PenDriveMountPath/SIB_FW_Upgrade.o $APP_DIR/
		cp -r $PenDriveMountPath/Upgrade $APP_DIR/
		cp -r $PenDriveMountPath/Upgrade_complete $APP_DIR/
		cp -r $PenDriveMountPath/Upgrade_failed $APP_DIR/
		cp -r $PenDriveMountPath/lnx_Upgrade_critical $APP_DIR/
		cp $PenDriveMountPath/VTC3000QT_update.sh $APP_DIR/
	
		rm -rf $PenDriveMountPath/CheckMe.txt
		sync
		cp -r $PenDriveMountPath/VTC3000QT $APP_DIR/	
		sleep 1
		sync
		cp $APP_DIR/SIB.bin /opt/
		cp $APP_DIR/SIB_FW_Upgrade.o /opt/
		cp $APP_DIR/auto_SIB_Boot_1v0.sh /opt/
		cp $APP_DIR/VTC3000QT_update.sh /opt/	
		cp $APP_DIR/Upgrade /opt/
		cp $APP_DIR/Upgrade_complete /opt/
		cp $APP_DIR/Upgrade_failed /opt/
		cp $APP_DIR/lnx_Upgrade_critical /opt/
		sync

		chmod 777 $APP_DIR/VTC3000QT
		chmod 777 $APP_DIR/*
		chmod 777 $APP_DIR/VTC3000QT_update.sh

		umount $PenDriveMountPath
		umount /dev/sda*
		rm -rf $PenDriveMountPath

		cp $APP_DIR/VTC3000QT_update.sh /opt/
		chmod 777 /opt/VTC3000QT_update.sh
		chmod 777 /opt/SIB_FW_Upgrade.o
		chmod 777 /opt/auto_SIB_Boot_1v0.sh
		chmod 777 /opt/Upgrade
		chmod 777 /opt/Upgrade_complete
		chmod 777 /opt/Upgrade_failed
		chmod 777 /opt/lnx_Upgrade_critical
	else
		umount $PenDriveMountPath
		rm -rf $PenDriveMountPath
		sync
		echo "#####################################"               
        	echo "######FOUND USB but NO UPGARDE#######" 
        	echo "#####################################"	
	fi
else
	echo "#####################################"                                    
        echo "##########NORMAL BOOT NO UPGARDE#####"                                    
        echo "#####################################"
fi
