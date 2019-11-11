#!/bin/bash

I_DEV=""
O_DEV=""
OUSB=""
IUSB=""

#
# only root can run 
#
if [ `whoami` != "root" ];then
    zenity --title="Insufficient Permission" \
	--info --text="Only root can run this command; aborting." --timeout=5 2>/dev/null
    exit 1
fi

zenity --title="Create Fail-safe (Duplicate Copy) of your USB Drive" \
	--question --width=480 \
	--text="This utility will duplicate your entire USB drive to another identical (or larger) USB drive.\n\n This utility does a bit-by-bit copy from boot Drive to an identical or larger target USB drive. It is strongly recommended you close any running programs (except Setup) before starting the duplication process.\nIt typically takes about 30 minutes to duplicate a 32 GB drive.\n\nPlease click Yes to continue." 2>/dev/null

if [ $? -ne 0 ];then
    zenity --title="Aborting..." \
	--info --text="Canceled at user's request; aborting." --timeout=3 2>/dev/null
    exit 1
fi

#
# Find USB drives.  
# default first one is the INPUT and the SECOND is backup
#
for d in `readlink -e /dev/disk/by-id/usb*0:0|sort`; do
    if [ "$I_DEV" = "" ];then
	I_DEV="TRUE $d"
    else
	# If there are more than two USB drives, create a list
	I_DEV="$I_DEV FALSE $d"
    fi
done

#
# select the input device, set IUSB
IUSB=`zenity --title="Select Source Device" \
	--list \
	--radiolist \
	--text="Select Source USB Device" \
	--column="Select" \
	--column="Device" \
	$I_DEV 2>/dev/null`

if [ $? -ne 0 ];then
    zenity --title="Aborting..." --width=480 --info \
	--text="Duplication Aborted, no source device selected." --timeout=15 2>/dev/null
    exit 1;
fi

# 
# Confirm IUSB is the boot device!
#
udevadm info $IUSB |grep -q "^S: TailsBootDev"
if [ $? -ne 0 ];then
    zenity --title="Invalid Source" --width=480 --question \
	--text="WARNING: Source Device, $IUSB, is not bootable.\nPlease confirm you want to duplicate another USB drive." 2>/dev/null 
    if [ $? -ne 0 ];then
	zenity --title="Aborting..." --info --width=480 \
	    --text="Aborted, did not confirm source device: $IUSB" --timeout=15 2>/dev/null
	exit 1
    fi
fi

## Now, get the Output device list
## excluding the selected one from the target
for d in `readlink -e /dev/disk/by-id/usb*0:0|sort`; do
    if [ "$d" = "$IUSB" ];then
	: ;
    elif [ "$O_DEV" = "" ];then
	O_DEV="TRUE $d"
    else
	# If there are more than two USB drives, create a list
	O_DEV="$O_DEV FALSE $d"
    fi
done
if [ "$O_DEV" = "" ];then
    zenity --title="Aborting..." --info --width=480 \
	--text="Aborted, no valid target device found." \
	--timeout=10 2>/dev/null
    exit 1
fi


OUSB=`zenity --title="Select Target Device" \
	--list \
	--radiolist \
	--text="Select Target USB Device" \
	--column="Select" \
	--column="Device" \
	$O_DEV 2>/dev/null`

if [ $? -ne 0 ];then
    zenity --title="Aborting..." --info --width=480 \
	--text="Duplication Aborted, no target device selected." \
	--timeout=15 2>/dev/null
    exit 1;
fi

##
## Check the SOURCE drive size, boot and data partition
##
ISIZ=`lsblk -dnb -o size ${IUSB}`
ISIZboot=`lsblk -dnb -osize ${IUSB}1 2>/dev/null`
ISIZdata=`lsblk -dnb -osize ${IUSB}2 2>/dev/null`
if [ "${ISIZboot}" = "" -o "${ISIZdata}" = "" ];then
    zenity --title="Aborting... invalid Source." --info --width=480 \
	   --text="Aborted, Missing boot or data partition on $IUSB" \
	   --timeout=15 2>/dev/null
    exit 1;
fi

##
## Check the TARGET drive size, boot and data partitions
##
OSIZ=`lsblk -dnb -o size ${OUSB}`
OSIZboot=`lsblk -dnb -osize ${OUSB}1 2>/dev/null`
OSIZdata=`lsblk -dnb -osize ${OUSB}2 2>/dev/null`
if [ "${OSIZ}" = "" ];then
    zenity --title="Aborting... invalid Target." --info --width=480 \
	   --text="Aborted, Cannot determine size of Target: $IUSB" \
	   --timeout=15 2>/dev/null
    exit 1
fi

udevadm info $OUSB |grep -q "^S: TailsBootDev"
if [ $? -eq 0 ];then
    zenity --title="WARNING: Invalid Target" --question --width=480 \
	--text="WARNING: Target Device, $OUSB, is the current boot device.\nPlease confirm you want to clobber your current boot device!!!\n\nWARNING: NOT RECOMMENDED! Abort Recommended (click No)." 2>/dev/null 
    if [ $? -ne 0 ];then
	zenity --title="Aborting..." --info --width=480 \
	    --text="Aborted, did not confirm Target: $OUSB" \
	    --timeout=15 2>/dev/null
	exit 1
    fi
fi

## OK here we go
## First, USB Drives vary in exact size.
##
if [ 0${ISIZ} -ne 0${OSIZ} ];then
    if [ 0${ISIZboot} -ne 0${OSIZboot} -o \
         0${ISIZdata} -ne 0${OSIZdata} ];then

	zenity --title="WARNING: Target Partitions" --question --width=480 \
	    --text="WARNING! WARNING!! WARNING!!!\nBoot and data partitions do not match.\n\nClick 'Yes' to Create new boot and data Partitions on the ${OUSB}. All contents on ${OUSB} will be lost." 2>/dev/null 
	if [ $? -ne 0 ];then
	    zenity --title="Aborting..." --info --width=480 \
		--text="Aborted, did not confirm partitions." \
		--timeout=15 2>/dev/null
	    exit 1
	fi
	##
	## dump SOURCE partitions, apply to TARGET
	##
	PTAB=`sfdisk --dump ${IUSB} 2>/dev/null |
		grep "^${IUSB}" |
		sed "s;${IUSB};${OUSB};g"`
	echo -e "label: gpt\n${PTAB}" | sfdisk ${OUSB}
	if [ $? -ne 0 ];then
	    zenity --title="Aborting... partition error." --info --width=480 \
	       --text="Aborted, failed to create boot and data partitions on ${OUSB}" \
	       --timeout=30 2>/dev/null
	    exit 1
	fi
    fi
    CMD="dd status=progress if=${IUSB}1 of=${OUSB}1 bs=8M;dd status=progress if=${IUSB}2 of=${OUSB}2 bs=8M"
else
    CMD="dd status=progress if=${IUSB} of=${OUSB} bs=8M"
fi
#
# Confirm , are you sure you want to proceed?  really?
#
zenity	--title="WARNING: Please confirm" --width=480 \
	--question \
	--default-cancel \
	--text="WARNING! WARNING!! WARNING!!! \n\nAll contents on $OUSB will be lost!\n\nClick 'Yes' to start duplication of $IUSB to $OUSB!\n" 2>/dev/null

if [ $? -ne 0 ];then
    zenity --info --width=480 \
	--text="Duplication Aborted, no changes were made." \
	--timeout=10 2>/dev/null
    exit 1
fi

###
### Well, well, well. OK, HERE WE GO! Let the backup begin!!!
###
### Log the start
###
sync;
s=`date`
(sleep 3;eval ${CMD}) |
    zenity --progress --width=480 \
    --title="Duplicating $IUSB to $OUSB in progress..." \
    --pulsate \
    --text="Please be patient.\nThe Duplication can take 30 minutes or more.\nStarted at: ${s}" \
    --auto-kill --auto-close 2>/dev/null
DDRESULT=$?
e=`date`

###
### all done!
###
if [ ${DDRESULT} -eq 0 ];then
    result="Succeeded."
else
    result="Aborted, $OUSB very likely corrupted."
fi
# report the resulrts...
###
### Log the Results 
###

# let the user know, too
zenity --title="Duplication Complete" --info --width=480 \
    --text="Duplication ${result}\nStarted: ${s}\nEnded: ${e}"  2>/dev/null

exit 0

