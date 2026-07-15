# KB\_Scripts\_Boot\_Linux

Steps to Linux Upgrade:

1. make sure SDCARD based Linux upload is done from Factory. QTSCreen only shows up
2. Copy the content of TimeTracer\_portrait\_7inch\_0100045\_Lnx folder to USB root
3. Plug the USB to TT700
4. Power on TT700
5. Wait till Linux Upgrade Complete screen to come
6. Donot remove Pendrive
7. Power off and power on the system
8. Now Factory Firmware is installed
9. Now copy Lnx\_Upgrade folder directly to root of pendrive. Make sure inside pendrive You must see only one folder "Lnx\_Upgrade"
10. Refer Note below and make sure you copy rootfs.rar to inside Lnx\_Upgrade folder.
11. Plug the Pendrive to TT700.
12. Power off Power on TT700
13. Wait for screen to Linux Upgrade Complete screen to come.

# Note:

Since rootfs.tar is big file of >300MB is not placed in git copy this from Onedrive to Lnx\_Upgrade USB folder.



### **7INCH\_TO\_5INCH upgrade:**

1. copy the content of ModuleArm\_5inch\_default folder to root of USB and plug to any factory upgraded i.MX6DL boards
2. Two reboots are expected, after two reboots the board will be converted to 5inch ModuleArm application.

