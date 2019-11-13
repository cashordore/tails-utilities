#!/bin/bash
#
# setup runs upon boot when amnesia signs in.
#

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
PDATA=/live/persistence/TailsData_unlocked
PERSISTENT=${PDATA}/Persistent
PLOCAL=${PDATA}/local
STEPFILE=${PLOCAL}/.setupstep
LAST_VFILE=${PLOCAL}/.last_v
CPFF=${PLOCAL}/.cpf
NPFF=${PLOCAL}/.npf

#
# confirm that custom local persistence has been setup
#	if super paranoid, check the i-node numbers (ls -i) for ~amnesia/.local and $PDATA/local match
#	for now, if $PLOCAL exists, we can assume the configuration was set and a reboot has occured.
#
if [ ! -d ${PLOCAL} ];then
    # $PLOCAL gets created at boot-up when the persistence.conf file is read. 
    if [ 0 -eq `grep -c 'source=local' ${PDATA}/persistence.conf` ];then
	# PLOCAL is there, but no local configuraiton
	zenity --question --title="Local Persistence"  --width=480 \
		--text="You are missing the custom setting for \"local\" persistence; Would you like to add it now?"
	if [ $? -ne 0 ];then
	    echo "done." 
	    exit 1
	fi

	# ok, need to add entry, but backup the file first.
	cp ${PDATA}/persistence.conf ${PDATA}/persistence.conf.$$.bak
	echo "/home/amnesia/.local	source=local" >>  ${PDATA}/persistence.conf 

    fi
    zenity --question --title="Reboot Needed" --width=480 \
	    --text="You must reboot to complete the setup of \"local\" persistence.\n\nClick Yes to Reboot immediately."
    if [ $? -eq 0 ];then
	reboot &
    fi
    echo "done." 
    exit 0
fi

RUN_V="`tails-version|head -1|cut -d' ' -f1`"
RUN_V=${RUN_V:-0.0}
    # in case of error

LAST_V="`cat $LAST_VFILE 2>/dev/null`"
LAST_V=${LAST_V:-0.0}

LC=`grep -c "^V ${RUN_V}" ${PCONF} 2>/dev/null`
LC=${LC:-0}
    # in case PCONF does not exist.
# 
# Get current code version 
CODE_V=`grep "^V " ${PCONF}|head -1|cut -d' ' -f2 2>/dev/null`
CODE_V=${CODE_V:-0.0}
    # in case PCONF does not exist

#
# if we are here, it means we've successfully setup "local" persistence, including the reboot
# so we can install the code!
#
if [ ! -f ${PCONF} -o 0 -eq ${LC} -o ${RUN_V} -ne ${LAST_V} ];then
    #
    # OK, if we ain't got no pconf, we can just go and get us one!
    #
    zentiy --question --title="Install?" --width="480" \
	--text="You are running version $RUN_V of Tails, but setup was last on version $LAST_V.\n\nClick Yes to download and install the latest update." 
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
		# BTW, since ~amnesia/Downloads isn't persistent,
		# everything under code-$$ will disappear at next reboot

	    # now for the fun part... let's launch the new version!!!
	    zentiy --question --title="Restart Setup" --width="480" --text="Click Yes to restart Upgraded setup." 
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

# Get last Boot Tails Version
if [ ! -f  "${LAST_VFILE}" ];then
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
#
#	zenity --question --width=480 \
#		--title="Restore User-Data?" \
#		--text="Would you like to restore data from a previous backup?"
#		--timeout=30
#	if [ $? -ne 0 ];then
#	    $CODEDIR/restore.bash
#	else
#	    zenity --info --title="No Restore" --text="No data was restored." --width=480
#	fi
#
#	
	STEP=3 echo $STEP > ${STEPFILE}
    fi
    #
    # Once persistence is fully setup, it's time to make a duplicate drive!
    #
    if [ "$STEP" -eq "3" ]; then
	echo ${RUN_V} >${LAST_VFILE}
	rm -f ${STEPFILE}
	zenity --info --text="Congratulations, setup for Tails $RUN_V is complete." --title="Setup Complete." --width=480

	zenity --question --width=480 --title="Create Fail-safe Duplicate" \
		--text="It is STRONGLY recommend you create a fail-safe backup drive NOW in case your primary drive is stolen, lost or damaged!\n\nWould you like to create your fail-safe drive now?"
	if [ $? -eq 0 ];then
	    exec ${CODEDIR}/duplicate.bash
	    # never returns from exec ... bye, bye!
	else
	   zenity --info --text="...don't put it off too long." --title="Living Dangerously?" --timeout=10 --width=480
	fi
    fi
fi

#
# add backup reminder
#

