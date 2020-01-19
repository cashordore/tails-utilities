#!/bin/bash

I_DEV=""
O_DEV=""
OUSB=""
IUSB=""
DUPLOG="~amnesia/.local/.dup.log"
LP=/live/persistence;export LP
LPPF=${LP}/.pf;export LPPF
SLOG=${LP}/.sync.log;export SLOG

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
for d in `readlink -e /dev/TailsBootDev|sort`; do
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
# not needed anymore because it only works from the boot drive!
#
#
#udevadm info $IUSB |grep -q "^S: TailsBootDev"
#if [ $? -ne 0 ];then
#    zenity --title="Invalid Source" --width=480 --question \
#	--text="WARNING: Source Device, $IUSB, is not bootable.\nPlease confirm you want to duplicate another USB drive." 2>/dev/null 
#    if [ $? -ne 0 ];then
#	zenity --title="Aborting..." --info --width=480 \
#	    --text="Aborted, did not confirm source device: $IUSB" --timeout=15 2>/dev/null
#	exit 1
#    fi
#fi
#
## Now, get the Output device list
## excluding the selected one from the target
for d in `readlink -e /dev/disk/by-path/*usb*0:0|grep -v "$IUSB"|sort`; do
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


if [ 0${OSIZdata} -gt 0 ];then 

zenity --question --title="Quick Backup" --width=480 \
	--text="Quick Backup: would you like to unlock your backup drive and perform a quick backup instead of the full bit-by-bit copy of the entire drive?\nHint: This method is much, much faster than the alternative."
if [ $? -eq 0 ];then

    ##
    ## identify TailsData partition on second drive, use LUKS to mount it
    ##
    cryptsetup isLuks "${OUSB}2"
    if [ $? -ne 0 ];then
	zenity --title="missing encrypted partition" --width=480 \
		--text="Error: There was no encrypted partition on $OUSB." \
		--info --timeout=30 2>/dev/null

    else
    while true; do
	# prompt for password, save into $LPPF
	FDATA=`zenity --forms --title="Enter Persistent Storage Passphrase!" \
	    --width=480 \
	    --add-password="Persistent Passphrase"`
	if [ $? -ne 0 ];then
	    zenity --title="Abort" \
		--info --text="Enter Password Aborted." --timeout=15 2>/dev/null
	    exit 1
	fi
	PF=`echo  "$FDATA"|cut -d\| -f1`
	printf "$PF" > $LPPF

	echo "start: `date`" > $SLOG
	cryptsetup --test-passphrase open --key-file=$LPPF ${OUSB}2 
	if [ $? -ne 0 ];then
	    rm -f $LPPF
	    zenity --info --title="Invalid Passphrase" --width=480 \
		--text="Invalid passphrase, try again."
	    continue;
	fi

	zenity --question --title="Confirm Backup" --width=480 \
		--text="WARNING: all data on your target drive will be lost. Click on Yes to copy all persistent data on the boot drive to the target drive.\n(restore option, coming soon)" 2>/dev/null
	if [ $? -ne 0 ];then
	    zenity --info --width=480 --title="abort" --text="Aborting" --timeout=10
	    exit 1
	fi
	#echo "open: `date`" >> $SLOG

	cryptsetup open --key-file=$LPPF ${OUSB}2 TailsBackup_unlocked  >>$SLOG 2>&1
	R1=$?
	rm -f $LPPF
	R2=0

	if [ $R1 -eq 0 ];then
	    s=`date`; export s
	    mkdir -p ${LP}/TailsBackup_unlocked
	    # echo "mkdir: `date`" >> $SLOG
	    mount /dev/mapper/TailsBackup_unlocked ${LP}/TailsBackup_unlocked >>$SLOG 2>&1
	    if [ $? -ne 0 ];then
		zenity --info --width=480 --title="Failed to mount encrypted drive" \
			--text="Error: failed to mount encrypted USB drive." 
	    else
		cd $LP
		(
	###
	rsync -qPaSHAX --delete --ignore-errors TailsData_unlocked/ TailsBackup_unlocked/ >>$SLOG 2>&1
	R2=$?;export R2
	echo "DUP:$R2:`date '+%y%m%d'`:$R2" >> ~amnesia/.local/.dup.log
	# echo "\n\nrsync $R2: `date`" >> $SLOG
	sync -f TailsBackup_unlocked
	sleep 2
	umount TailsBackup_unlocked >>$SLOG 2>&1
	# echo "umount $?: `date`" >> $SLOG
	sleep 2
	cryptsetup close TailsBackup_unlocked >>$SLOG 2>&1
	###
		) | zenity --progress --width=480 \
			--title="Backup $IUSB to $OUSB in progress..." \
			--pulsate \
			--text="Backup $IUSB to $OUSB in progress, started at: ${s}" \
			--auto-kill --auto-close 2>/dev/null
		
		echo "\n\nBackup done at: `date`" >>$SLOG
		zenity --title="Backup complete" --info --width=800 \
		       --text="Backup completed at `date`.\nR2=${R2}\n\n`cat $SLOG`" 2>/dev/null
		exit 1;
	    fi
	fi
    done
    fi

fi

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
if [ 0${ISIZ} -eq 0${OSIZ} ];then
    CMD="dd status=progress if=${IUSB} of=${OUSB} bs=8M"
    if [ 0${ISIZdata} -eq 0${OSIZdata} ];then
	zenity --title="Backup Data Partition" --question --width=480 \
		--text="Would you like to backup just the persistent data partition?\n(faster)" 
	if [ $? -eq 0 ];then
	    CMD="dd status=progress if=${IUSB}2 of=${OUSB}2 bs=8M"
	else 
	    if [ 0${ISIZboot} -eq 0${OSIZboot} ];then
		zenity --question --width=480 --title="Backup by Partitions" \
		    --text="Would you like to backup your two partitions separately?\n(a little faster)"
		if [ $? -eq 0 ];then
		    CMD="dd status=progress if=${IUSB}1 of=${OUSB}1 bs=8M;dd status=progress if=${IUSB}2 of=${OUSB}2 bs=8M"
		fi
	    fi
	fi
    fi
else
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
	echo -e "label: gpt\n${PTAB}" | sfdisk ${OUSB} 2>$SLOG
	if [ $? -ne 0 ];then
	    zenity --title="Fatal: Failed to create partitions" --info --width=480 \
	       --text="Error: failedto create boot and data partitions on ${OUSB}.\nPlease use the Disks Utility to create a partition of size $ISIZboot and a data partition of size $ISIZdata on $OUSB; then rerun this utility.\n\n`cat $SLOG`" \ 2>/dev/null
	    exit 1
	fi
    fi
    CMD="dd status=progress if=${IUSB}1 of=${OUSB}1 bs=8M;dd status=progress if=${IUSB}2 of=${OUSB}2 bs=8M"
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

###
### Log the Results 
###
echo "DUP:$DDRESULT:`date '+%y%m%d'`:$result" >> ~amnesia/.local/.dup.log

# let the user know, too
zenity --title="Duplication Complete" --info --width=480 \
    --text="Duplication ${result}\nStarted: ${s}\nEnded: ${e}"  2>/dev/null

exit 0

