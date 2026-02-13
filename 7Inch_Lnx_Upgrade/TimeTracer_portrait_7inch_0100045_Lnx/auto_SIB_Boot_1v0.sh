#!/bin/sh

CHECK_FILE='/opt/SIB.bin'

cd /opt/

#if [ -x $CHECK_FILE ]; then
#
#	export QT_QPA_PLATFORM=linuxfb:fb=/dev/fb0:size=1024x600:mmSize=1024x600
#	./Upgrade &
#fi

#./SIB_FW_Upgrade.o $bytes $snr $modulation $channel $alamouti
#value=$?

#sleep 1

#if [ $value == 1 ]
#then
#	echo "#####################################"
#	echo "########## Upgrade Failed ###########"
#	echo "#####################################"
#	if [ -x $CHECK_FILE ]; then
#		kill -9 $(pidof Upgrade)
#	fi
#	sleep 1
#	export QT_QPA_PLATFORM=linuxfb:fb=/dev/fb0:size=1024x600:mmSize=1024x600
#	./Upgrade_failed &
#	sleep 100000000
#else
#	if [ -x $CHECK_FILE ]; then
#		echo "#####################################"
#		echo "########## Upgrade Completed ## #####"
#		echo "#####################################"
#		rm -rf /opt/SIB.bin
#		sync
#		kill -9 $(pidof Upgrade)
#		sleep 5
#		export QT_QPA_PLATFORM=linuxfb:fb=/dev/fb0:size=1024x600:mmSize=1024x600
#		./Upgrade_complete &
#		sleep 100000000
#		wait
#	fi
#fi
