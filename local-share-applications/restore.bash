#!/bin/bash

# TESTMODE, comment out the following line to disable TESTMODE
# backup and restore will NOT run when TESTMODE=TRUE
# TESTMODE=TRUE

P=`basename $0`
D="`echo ~amnesia/Persistent`"
PATTERN="-backup.tbz2.gpg"
#SRC="~amnesia"
SRC=/live/persistence/TailsData_unlocked

#
# only root can run 
#
if [ `whoami` != "root" ];then
    zenity --title="Insufficient Permission" --width=480 \
	--info \
	--text="Only root can run this command; aborting." \
	--timeout=5 2>/dev/null
    exit 1
fi

if [ "$P" = "backup.bash" ];then
    MODE=BACKUP
else
    MODE=RESTORE
fi

zenity --title="Starting $MODE" --question --width=480 --text="This utility will $MODE your Persistent data.\n\nIt is recommend you close all programs before running a $MODE. It can take up to 30 minutes to $MODE 32 GB of data. Do yo want to continue?" 2>/dev/null

if [ $? -ne 0 ];then
    zenity --title="Aborting..." --width=480 \
	--info --text="Canceled at user's request; aborting." --timeout=3 2>/dev/null
    exit 1
fi

if [ "$MODE" = "BACKUP" ];then
    TODAY=`date +%Y-%m-%d`
    BAKFILE="$D/${TODAY}${PATTERN}"
    if [ -f "$BAKFILE" ];then
	zenity --title="Overwrite Backup File?" --width=480 \
	    --question \
	    --text="WARNING: backup file already exists!\nPlease confirm you want to overwrite the file:\n`ls \"$BAKFILE\"`" 2>/dev/null 
	if [ $? -ne 0 ];then
	    zenity --title="Backup Aborted." --width=480 \
		--info \
		--text="Backup aborted, did NOT overwrite existing file." \
		--timeout=5 2>/dev/null
	    exit 1
	fi
    fi

    zenity --info --width=480 \
	--text="You are about to be prompted, twice, for a passphrase.\nRemember it because you will need it to restore from backup.\n\n ... be patient the backup takes several minutes ..." 2>/dev/null

    if [ "$TESTMODE" = "TRUE" ];then
	zenity --info --width=480 --text="TEST Mode, $MODE skipped." 2>/dev/null
    else
	echo "Enter password (twice) and then wait for the $MODE to complete."
	cd ${SRC}
	tar --exclude "*${PATTERN}" -cjf - . |
	    gpg --cipher-algo AES -c - > "$BAKFILE"
	chown amnesia.amnesia $BAKFILE

	zenity --info --width=480 --text="Backup complete.\n `ls \"$BAKFILE\"`" 2>/dev/null
    fi
    exit 0

elif [ "$MODE" = "RESTORE" ];then
   cd ${D}
   F=""
   for f in `find . -name "*${PATTERN}" -print|tr ' ' '#'`;do
	if [ "$F" = "" ];then
	    F="TRUE $f"
	else
	    # If there are more than two USB drives, create a list
	    F="$F FALSE $f"
	fi
   done

   if [ "$F" = "" ];then
	zenity --title="$MODE Aborted." --width=480 --info \
	    --text="Restore aborted, could not find any backup files." \
	    --timeout=15 2>/dev/null
	exit 1
   fi

    # select the restore file, set BAKFILE
    BAKFILE=`zenity --title="Select Backup File" \
	--list \
	--separator=" " \
	--radiolist \
	--text="Select file to restore:" \
	--column="Select" \
	--column="Device" \
	$F 2>/dev/null`

    if [ $? -ne 0 ];then
	zenity --title="Aborting..." --width=480 \
	    --info \
	    --text="Restore Aborted, no restore file selected" \
	    --timeout=15 2>/dev/null
	exit 1;
    fi

    BAKFILE="`echo "$BAKFILE"|tr '#' ' '`"
    if [ -f "$BAKFILE" ];then
	zenity --info --title="Starting Restore." --width=480 \
	    --text="Restore: you will be prompted for the passphrase you provided when you created this backup.\nPlease be patient, the restore will take several minutes.\nClick OK to continue..." 2>/dev/null

	if [ "$TESTMODE" = "TRUE" ];then
	    zenity --info --width=480 --text="TEST Mode, $MODE skipped." 2>/dev/null
	else
	    echo "Enter password and then wait for the $MODE to complete."
	    cd ${SRC}
	    gpg --cipher-algo AES -d "${D}/${BAKFILE}" | tar -xjvf - 
	    zenity --info --width=480 \
		--text="Restore Complete." 2>/dev/null
	fi
	exit 0

    else
	zenity --info --width=480 \
	    --text="Invalid file: $BAKFILE. Restore aborted." 2>/dev/null
	exit 1
    fi
fi
