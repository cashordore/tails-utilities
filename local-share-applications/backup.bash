#!/bin/bash

# TESTMODE, comment out the following line to disable TESTMODE
# backup and restore will NOT run when TESTMODE=TRUE
#TESTMODE=TRUE

P=`basename $0`
D="`echo ~amnesia/Persistent`"
PATTERN="-backup.tbz2.gpg"
#SRC="~amnesia"
SRC=/live/persistence/TailsData_unlocked

#
# only root can run 
#
if [ `whoami` != "root" ];then
    zenity --title="Insufficient Permission" \
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

zenity --title="Close all programs" \
	--info \
	--text="It is strongly recommended you close all programs before running a ${MODE}.\nIt can take up to 30 minutes or more to complete.\n\nPlease close any running programs now and Click OK to continue." 2>/dev/null


if [ "$MODE" = "BACKUP" ];then
    TODAY=`date +%Y-%m-%d`
    BAKFILE="$D/${TODAY}${PATTERN}"
    if [ -f "$BAKFILE" ];then
	zenity --title="Overwrite Backup File?" \
	    --question \
	    --text="WARNING: backup file already exists!\nPlease confirm you want to overwrite the file:\n`ls \"$BAKFILE\"`" 2>/dev/null 
	if [ $? -ne 0 ];then
	    zenity --title="Backup Aborted." \
		--info \
		--text="Backup aborted, did NOT overwrite existing file." \
		--timeout=5 2>/dev/null
	    exit 1
	fi
    fi

    zenity --info \
	--text="You are about to be prompted, twice, for a passphrase.\nRemember it because you will need it to restore from backup.\n\n ... be patient the backup takes several minutes ..." 2>/dev/null

    if [ "$TESTMODE" = "TRUE" ];then
	zenity --info --text="TEST Mode, $MODE skipped." 2>/dev/null
    else
	echo "Enter password (twice) and then wait for the $MODE to complete."
	cd ${SRC}
	tar --exclude "*${PATTERN}" -cjf - . |
	    gpg --cipher-algo AES -c - > "$BAKFILE"
	chown amnesia.amnesia $BAKFILE

	zenity --info \
		--text="Backup complete.\n `ls \"$BAKFILE\"`" 2>/dev/null
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
	zenity --title="Restore Aborted." \
	    --info \
	    --text="Restore aborted, could not find any backup files." \
	    --timeout=5 2>/dev/null
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
	zenity --title="Aborting..." \
	    --info \
	    --text="Restore Aborted, no restore file selected" \
	    --timeout=5 2>/dev/null
	exit 1;
    fi

    BAKFILE="`echo "$BAKFILE"|tr '#' ' '`"
    if [ -f "$BAKFILE" ];then
	zenity --info --title="Starting Restore." \
	    --text="Restore: you will be prompted for the passphrase you provided when you created this backup.\nPlease be patient, the restore will take several minutes.\nClick OK to continue..." 2>/dev/null

	if [ "$TESTMODE" = "TRUE" ];then
	    zenity --info --text="TEST Mode, $MODE skipped." 2>/dev/null
	else
	    echo "Enter password and then wait for the $MODE to complete."
	    cd ${SRC}
	    gpg --cipher-algo AES -d "$D/$BAKFILE" | tar -xjvf - 
	    zenity --info \
		--text="Restore Complete." 2>/dev/null
	fi
	exit 0

    else
	zenity --info \
	    --text="Invalid file: $BAKFILE. Restore aborted." 2>/dev/null
	exit 1
    fi
fi
