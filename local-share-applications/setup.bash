#!/bin/bash

#
# might want to not requre root for the autostart execution
# give the backup reminder, and check status, re-launch under sudo if necessary
#
PDATA=/live/persistence/TailsData_unlocked
PLOCAL=${PDATA}/local
LAST_VFILE=${PLOCAL}/.last_v
if [ "$1" != "skip" ];then
   if [ -f  "${LAST_VFILE}" ];then
	# you can only get here if previous setup was completed... 
	# ok, so now check backup logs for last backup
	#
	DZ="NEVER"
	if [ -f ${PLOCAL}/.dup.log ];then
	    NOW=`date '+%y%m%d'`
	    THEN=`tail -1 ${PLOCAL}/.dup.log|cut -d: -f3`
	    BSTATUS=`tail -1 ${PLOCAL}/.dup.log|cut -d: -f4`
	    DZ="`echo $(( ($(date --date="$NOW" +%s) - $(date --date="$THEN" +%s) )/(60*60*24) ))` days"
	fi
	zenity --question --title="Backup Reminder" --width=480 \
	    --text="It has been $DZ since your last backup $BSTATUS.\n\nClick:\n\tYes - to continue (requires Administration password)\n\tNo - to exit"
	if [ $? -ne 0 ];then
	    exit 0
	fi
        sudo $0 skip
        exit 0
   else
      sudo $0 skip
      exit 0
   fi
fi

#
# only root can run 
#
if [ `whoami` != "root" ];then
    zenity --title="Insufficient Permission" \
	--info --width=480 \
	--text="Only root can run this command; Aborting." \
	--timeout=5 2>/dev/null
    exit 1
fi

P=`basename $0`
CODEDIR=`dirname $0`
PCONF="`echo ${CODEDIR}/${P}|sed 's/bash/conf/g'`"
PERSISTENT=${PDATA}/Persistent
DOTFILES=${PDATA}/dotfiles
STEPFILE=${PLOCAL}/.setupstep
CPFF=${PLOCAL}/.cpf
NPFF=${PLOCAL}/.npf
STEP=0
if [ "$1" == "skip" ];then
    STEP=3
    echo $STEP > ${STEPFILE};
fi

RUN_V="`tails-version|head -1|cut -d' ' -f1`"
RUN_V=${RUN_V:-0.0}
LAST_V="`cat $LAST_VFILE 2>/dev/null`"
LAST_V=${LAST_V:-0.0}
LC=`grep -c "^V ${RUN_V}" ${PCONF} 2>/dev/null`
LC=${LC:-0}

# 
# Welcome message 
#
#zenity --width=480 --question  \
#    --title="Setup Wizard" \
#    --text="Welcome to the setup wizard.\n\nClick OK, and we'll check your Persistence and software settings."
#

# check to see if we are up-to-date
# check backup log, issue warning

#
# confirm that persistence has been setup
#	if super paranoid, check the i-node numbers (ls -i) for ~amnesia/.local and $PDATA/local match
#
LP=`grep -c 'source=local' ${PDATA}/persistence.conf`
LP=${LP:-0}
DP=`grep -c 'source=dotfiles' ${PDATA}/persistence.conf`
DP=${DP:-0}
PP=`grep -c 'source=Persistent' ${PDATA}/persistence.conf`
PP=${PP:-0}

if [ $LP -eq 0 -o $DP -eq 0 -o $PP -eq 0 ];then
    # one of the Persistent dirs is missing
    zenity --question --width=480 --title="Persistence Update Needed" \
	--text="Welcome to the Setup Wizard.\n\nYour Persistence settings need to be updated. Click Yes to update your required settings or No to exit."
    if [ $? -ne 0 ];then
	echo "Cannot continue without Persistence." 
	exit 1
    fi

    # ok, backup the original file first.
    cp ${PDATA}/persistence.conf ${PDATA}/persistence.conf.$$.bak
    [ 0 -eq $PP ] && echo "/home/amnesia/Persistent	source=Persistent" >> ${PDATA}/persistence.conf 
    [ 0 -eq $LP ] && echo "/home/amnesia/.local	source=local" >> ${PDATA}/persistence.conf 
    [ 0 -eq $DP ] && echo "/home/amnesia/	source=dotfiles,link" >> ${PDATA}/persistence.conf 

    zenity --question --title="Reboot Needed" --width=480 \
	    --text="Persistence setup complete, you must reboot to activate the changes.\n\nPlease exit any running programs and click Yes to Reboot immediately, or click No to reboot later.\n\nNote: you must re-run \"Setup\" again after reboot."
    if [ $? -eq 0 ];then
	reboot &
    fi
    echo "done." 
    exit 0
fi

# 
# Get current code version 
#
CODE_V=`grep "^V " ${PCONF}|head -1|cut -d' ' -f2 2>/dev/null`
CODE_V=${CODE_V:-0.0}
    # in case PCONF does not exist

#
# if we are here, it means we've successfully setup persistence, including the reboot
# so we can install the code!
#
zenity --question --title="Software Update" --width="480" \
    --text="Would you like to download and apply the latest software update?\n\nClick Yes to perform an update." 

if [ $? -eq 0 -o ! -f ${PCONF} -o 0 -eq ${LC} -o ${RUN_V} != ${LAST_V} ];then
    #
    # OK, if we ain't got no pconf, we can just go and get us one!
    #
    zenity --question --title="Confirm Software Update" --width="480" \
	--text="Click Yes to Confirm and apply updated software.\n\nNOTE: a network connection is required to download the software. Please connect to the Internet and then click Yes to download and update the software. Click No to skip." 
    if [ $? -ne 0 ];then
	echo "Ok, maybe next time."
	# exit 0
    else
	cd ~amnesia/Downloads
	mkdir code-$$
	chmod 777 code-$$
	cd ./code-$$
	su amnesia -c "git clone https://github.com/cashordore/tails-utilities"
	if [ $? -eq 0 ];then
	    cd ./tails-utilities/local-share-applications
	    su amnesia -c "cp *.bash *.desktop *.conf ~amnesia/.local/share/applications"
	    [ ! -d $PDATA/dotfiles/.config/autostart ] && su amnesia -c "mkdir -p $PDATA/dotfiles/.config/autostart"
	    su amnesia -c "cp Setup.desktop $PDATA/dotfiles/.config/autostart"

	    # now for the fun part... let's launch the new version!!!
	    zenity --question --title="Restart Setup" --width="480" --text="Click Yes to restart Upgraded setup." 
	    if [ $? -eq 0 ];then
		exec ~amnesia/.local/share/applications/setup.bash
	    fi
	    echo "Warning: did not choose to run upgraded setup."
	else
	    # network ok? other errors?
	    zenity --info --title="Error Detected" --width=480 \
		--text="Check for errors and try running $P again.\n\nFYI: a network connection is required to install the software."
	    exit 1
	fi
    fi
fi

#
# At this point: a) persistence is setup and b) software has been updated! 
# hurray!! great job... now we can complete the first-time setup
#
# Get last Boot Tails Version
# 
if [ ! -f  "${LAST_VFILE}" -o "$STEP" -ne 0 ];then
    #
    # First time setup!
    #
    STEP=`cat ${STEPFILE} 2>/dev/null||echo 1`
    if [ "$STEP" -eq "1" ]; then

	# 
	# Welcome message 
	#
	zenity --width=480 --question --title="First-time Setup" \
		--text="Welcome to the First-time setup wizard.\n\nImportant note: You are about to set the passphrase for your encrypted storage. Once the passpharse is changed it cannot be recovered; so please be careful. Write it down and lock it in a safe.\n\nYou will also have the opportunity to create a fail-safe, duplicate copy of this USB drive in case this device is stolen, lost or damaged; and if stolen, I hope your passpharse was 20+ characters!\n\nGood luck and let's go!"
	
if [ $? -eq 0 ]; then
	# 
	# identify LUKS partitions
	#
	for d in `readlink -e /dev/disk/by-id/usb*|sort`; do
	    # cryptsetup can identify LUKS partitions, magic!
	    #
	    cryptsetup isLuks $d 
	    if [ $? -eq 0 ]; then

		if [ "$L_DEV" = "" ];then
		    L_DEV="TRUE $d"
		else
		    # If there are more than two USB drives, create a list
		    L_DEV="$L_DEV FALSE $d"
		fi

	    fi
	done
	if [ "$L_DEV" = "" ];then
	    zenity --info --text="$P: Could not find the LUKS partition, aborting." --title="Abort" --timeout=30
	    exit 1
	fi
	#
	# select the input device, set IUSB
	#
	LUSB=`zenity --title="Select Source Device" \
		--list \
		--radiolist \
		--text="Select Encrypted Partition" \
		--column="Select" \
		--column="Device" \
		$L_DEV 2>/dev/null`

	if [ $? -ne 0 ];then
	    zenity --title="Abort" \
		--info --text="Change Password Aborted." --timeout=15 2>/dev/null
	    exit 1
	fi

	FDATA=""
	while true; do
	    # prompt for Old passphrase, and new passphrase twice.
	    FDATA=`zenity --forms --title="Change Persistent Storage Passphrase!" \
		--width=480 \
		--add-password="Current Passphrase" \
		--add-password="New Passphrase" \
		--add-password="Repeat New Passphrase" `
	    if [ $? -ne 0 ];then
		zenity --title="Abort" \
		    --info --text="Change Password Aborted." --timeout=15 2>/dev/null
		exit 1
	    fi

	    # check for a '|' character in the passwords
	    PC=`echo "${FDATA}" | awk -F"\|" '{print NF-1}'`
	    if [ "$PC" -ne 2 -a "$PC" -ne 0 ];then
		zenity --question --width=480 \
			--title="Invalid character" \
			--text="The '|' character is not allowed, Click Yes to Try again." 
		if [ $? -ne 0 ];then
		    zenity --title="Abort" \
			--info --text="Change Password Aborted." --timeout=15 2>/dev/null
		    exit 1
		fi
		continue
	    fi

	    if [ "$FDATA" = "" ];then
		echo "empty form... (i think)"
		continue
	    fi

	    # divvy up the spoils 
	    CPF=`echo  "$FDATA"|cut -d\| -f1`
	    NPF1=`echo "$FDATA"|cut -d\| -f2`
	    NPF2=`echo "$FDATA"|cut -d\| -f3`

	    # ensure new passphrases match...
	    if [ "$NPF1" != "$NPF2" -o "$CPF" == "" -o "$NPF1" == "" -o "$NPF2" == "" ]; then
		zenity --question --width=480 \
			--title="Passphrase Errors" \
			--text="The new Passphrases did not match or a field was blank; do you want to try again?" 
		if [ $? -ne 0 ];then
		    zenity --title="Abort" \
			--info --text="Change Password Aborted." --timeout=15 2>/dev/null
		    exit 1
		fi
		# loop back and try again
		continue
	    fi

	    printf "$CPF" > $CPFF
	    cryptsetup --test-passphrase open --key-file=$CPFF $LUSB 
	    if [ $? -ne 0 ];then
		zenity --question --width=480 \
			--title="Incorrect Current Passphrase" \
			--text="The Current Passphrase was not correct, do you want to try again?"
		if [ $? -ne 0 ];then
		    rm -f $CPFF
		    zenity --title="Abort" \
			--info --text="Change Password Aborted." --timeout=15 2>/dev/null
		    exit 1
		fi
		continue
	    fi

	    printf "$NPF1" > $NPFF
	    zenity --question --width=480 \
		--title="WARNING!! Confirm Disk Encryption Passphrase Change." \
		--text="WARNING!! You are about to perminently change the passphrase for your encrypted Disk $LUSB to \"`cat ${NPFF}`\". The password cannot be recovered. Do not lose or forget it. \n\nPlease Confirm by clicking Yes."

	    if [ $? -eq 0 ]; then
		# echo cryptsetup luksAddKey --key-file=$CPFF $LUSB $NPFF 2>/tmp/${P}.err
		cryptsetup luksChangeKey --key-file=$CPFF $LUSB $NPFF
		if [ $? -ne 0 ];then
		    rm -f $CPFF $NPFF
		    zenity --question --width=480 \
			--title="Passphrase Change Failed!" \
			--text="Error: failed passphrase change on $LUSB, `cat /tmp/${P}.err`\nDo you want to try again?"
		    if [ $? -ne 0 ];then
			zenity --title="Abort" \
			    --info --text="Change Password Aborted." --timeout=15 2>/dev/null
			exit 1
		    fi
		    continue
		else
		    zenity --info --title="Passphrase Change Succeeded!" --width=480 \
			--text="Your Encryption Passphrase has been successfully changed."
		fi
	    else
		zenity --info --text="Passphrase change Aborted! (what were you thinking!)" --title="Abort" --timeout=10 --width=480
		rm -f $CPFF $NPFF
		#exit 1
	    fi
	    # cleanup files..
	    rm -f $CPFF $NPFF
	    # ok we done. Phew!
	    break;
	done

fi

	STEP=2
	echo $STEP > ${STEPFILE};
    fi


    if [ "$STEP" -eq "2" ]; then
#
#	zenity --question --width=480 \
#		--title="Restore User-Data" \
#		--text="Would you like to restore data from a previous backup?"
#	if [ $? -ne 0 ];then
#	    $CODEDIR/restore.bash
#	else
#	    zenity --info --title="No Restore" --text="No data was restored." --width=480
#	fi
#
#	
	STEP=3
	echo $STEP > ${STEPFILE}
    fi
    #
    # Once persistence is fully setup, it's time to make a duplicate drive!
    #
    if [ "$STEP" -eq "3" ]; then
	echo ${RUN_V} >${LAST_VFILE}
	chmod 644 ${LAST_VFILE}
	rm -f ${STEPFILE}
	zenity --info --text="Congratulations, setup for Tails $RUN_V is complete." --title="Setup Complete." --width=480

	zenity --question --width=480 --title="Create Fail-safe Duplicate" \
		--text="It is STRONGLY recommend you create a fail-safe backup drive NOW in case your primary drive is stolen, lost or damaged!\n\nWould you like to create your fail-safe drive now?"
	if [ $? -eq 0 ];then
	    exec ${CODEDIR}/duplicate.bash
	    # never returns from exec ... bye, bye!
	else
	   zenity --info --title="Living Dangerously?" --width=480 \
		--text="Please use \"Applications->Accessories->Duplicate Tails USB Drive\" regularly to backup all your valuable data!"
	fi
    fi
fi


