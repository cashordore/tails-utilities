#!/bin/bash
#
# setup runs upon boot when amnesia signs in.
#

#
# only root can run 
#
if [ `whoami` != "root" ];then
    zenity --title="$P: Insufficient Permission" \
	--info --width=480 \
	--text="Only root can run this command; aborting." \
	--timeout=5 2>/dev/null
    exit 1
fi

P=`basename $0`
CODEDIR=`dirname $0`
PCONF="`echo ${CODEDIR}/${P}|sed 's/bash/conf/g'`"
PDATA=/live/persistence/TailsData_unlocked
PERSISTENT=${PDATA}/Persistent
PLOCAL=${PDATA}/local
STEPFILE=${PLOCAL}/.setupstep
LASTV=${PLOCAL}/.last_v
CPFF=${PLOCAL}/.cpf
NPFF=${PLOCAL}/.npf

if [ ! -d ${PLOCAL} ];then
    zenity --title="$P: Unexpected error: missing local folder." \
	--text="$P: Unexpected error: ${PLOCAL} missing. You may need to reboot, Aborting..." \
	--info --width=480 2>/dev/null
    exit 1
fi

if [ ! -f ${PCONF} ];then
    zenity --title="missing $PCONF." \
	--info --width=480 \
	--text="$P: missing ${PCONF} file. Aborting..." \
	--timeout=5 2>/dev/null 
    exit 1
fi

# check compatibility..
#
RUN_V="`tails-version|head -1|cut -d' ' -f1`"
if [ 0 -eq `grep -c "^V ${RUN_V}" ${PCONF}` ];then
    #
    # This would likely happen after user does a Tails in-place upgrade.
    # or a "code restore" of older (aka wrong) version (yes, it's possible)
    # either way might want to check for a compatible version of the code...
	# no need to keep this, just need it for install...
	# at some point add a branch for based on $RUN_V
	# for now, just the latest version... 
	# cd /tmp
	# git clone https://github.com/cashordore/tails-utilities
	# cd /tmp/tails-utilities/local-share-applications
	# [ -f ./upgrade.bash ] && ./upgrade.bash
	# basically upgrade.bash should copy files from current folder into correct place
    #
    VZ=`echo \`grep "^V " $PCONF | cut -d' ' -f2\``
    zenity --question --title="Unsupported version detected." --width=480 \
	--text="Tails $RUN_V is currently running; however, the supported versions are: $VZ. Would you like to continue anyway?"
    if [ $? -ne 0 ]; then
	zenity --width=480 --info --title="aborting..." --text="aborting..." --timeout=5 --info 2>/dev/null
	exit 1
    fi
fi

# 
# Get current code version 
CODE_V=`grep "^V " ${PCONF}|head -1|cut -d' ' -f2`

# Get last Boot Tails Version
if [ ! -f  "${LASTV}" ];then
    #
    # First time setup!
    #
    STEP=`cat ${STEPFILE} 2>/dev/null||echo 1`
    if [ "$STEP" -eq "1" ]; then

	# 
	# Welcome message 
	#
	zenity --width=480 --info --title="First-time Setup" \
		--text="Welcome to the First-time setup wizard.\n\nImportant note: You are about to set the passphrase for your encrypted storage. Once the passpharse is changed it cannot be recovered; so please be careful. Write it down and lock it in a safe.\n\nYou will also have the opportunity to create a fail-safe, duplicate copy of this USB drive in case this device is stolen, lost or damaged; and if stolen, I hope your passpharse was 20+ characters!\n\nGood luck and let's go!"

	
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
	    zenity --info --text="$P: Could not find the LUKS partition, aborting." --title="aborting.." --timeout=30
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
	    zenity --title="Aborting..." \
		--info --text="Change Password Aborted." --timeout=5 2>/dev/null
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
		echo "aborting..."
		exit 1
	    fi

	    # check for a '|' character in the passwords
	    PC=`echo "${FDATA}" | awk -F"\|" '{print NF-1}'`
	    if [ "$PC" -ne 2 -a "$PC" -ne 0 ];then
		zenity --question --width=480 \
			--title="Invalid character" \
			--text="The '|' character is not allowed, Click Yes to Try again." 
		if [ $? -ne 0 ];then
		    echo "aborting..."
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
			--title="Passphrase errors" \
			--text="The new Passphrases did not match or a field was blank; do you want to try again?" 
		if [ $? -ne 0 ];then
		    echo "aborting..."
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
		    echo "aborting..."
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
			--title="Passphrase change failed!" \
			--text="Error: failed passphrase change on $LUSB, `cat /tmp/${P}.err`\nDo you want to try again?"
		    if [ $? -ne 0 ];then
			echo "aborting..."
			exit 1
		    fi
		    continue
		else
		    zenity --info --title="Passphrase change Succeeded!" --width=480 \
			--text="Your Encryption Passphrase has been successfully changed."
		fi
	    else
		zenity --info --text="Passphrase change Aborted! (what were you thinking!)" --title="aborting" --timeout=10 --width=480
		rm -f $CPFF $NPFF
		exit 1
	    fi
	    # cleanup files..
	    rm -f $CPFF $NPFF
	    # ok we done. Phew!
	    break;
	done

	STEP=2 echo $STEP > ${STEPFILE};
    fi


    if [ "$STEP" -eq "2" ]; then
	# ask if user "wants" to setup "persistence" 
	# remember timestamp of $PDATA/persistence.conf
	# tails-persistence-setup
	# if timestamp of $PDATA/persistence.conf has changed you need to reboot!
#	    zenity --question --title="Reboot now?" --width=480 \
#		--text="Reboot is recommended. The setup will continue from this point after the reboot. Would you like to reboot now?"
#	    if [ $? -eq 0 ];then
#		reboot &
#		exit 0
#	    fi
#	    zenity --question --width=480 --title="Final Answer?" \
#		--text="Warning: Skippipng Reboot is not recommended! Reboot NOW? click "No" to proceed at your own risk." 
#	    if [ $? -eq 0 ];then
#		reboot &
#		exit 0
#	    fi
	# 
	# After reboot: user will not want to set persistence 
	# OR won't change anything they can continue

	# now that persistence is setup and locked it; user can attempt a restore.
	# doing a restore before persistence is setup is useless. 
	# 
#
#	zenity --question --width=480 \
#		--title="Restore user-data?" \
#		--text="Would you like to restore data from a previous backup?"
#		--timeout=30
#	if [ $? -ne 0 ];then
#	    $CODEDIR/restore.bash
#	else
#	    zenity --info --title="No restore." --text="No data was restored." --width=480
#	fi
#
#	
	STEP=3 echo $STEP > ${STEPFILE}
    fi
    #
    # Once persistence is fully setup, it's time to make a duplicate drive!
    #
    if [ "$STEP" -eq "3" ]; then
	zenity --question --width=480 --title="Create Fail-safe Duplicate" \
		--text="It is STRONGLY recommend you create a fail-safe drive NOW, in case your primary drive gets stolen, lost or damaged!\nWould you like to create your fail-safe drive now?"
	if [ $? -eq 0 ];then
	    # optimisticly set STEP to 4, so from the duplicated drive it We do not attempt to duplicate again!!
	    STEP=4 echo $STEP > ${STEPFILE}
	    ${CODEDIR}/duplicate.bash
	else
	   zenity --info --text="...don't put it off too long." --title="living dangerously?" --timeout=10 --width=480
	fi
    fi

    #
    # Ok, now we can log the run-time version and avoid the setup in the future...
    #
    if [ "$STEP" -eq "4" ]; then
	zenity --info --text="Setup is complete." --title="Setup Complete." --timeout=30 --width=480
	rm -f ${STEPFILE}
	echo ${RUN_V} >${LASTV}
    fi
fi

#
# add backup reminder
#

