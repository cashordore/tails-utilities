#!/bin/bash
#
# setup runs upon boot when amnesia signs in.
#

#
# only root can run 
#
if [ `whoami` != "root" ];then
    zenity --title="$P: Insufficient Permission" \
	--info --width=320 \
	--text="Only root can run this command; aborting." \
	--timeout=5 2>/dev/null
    exit 1
fi

P=`basename $0`
CODEDIR=`dirname $0`
PCONF="`echo ${CODEDIR}/${P}|sed 's/bash/conf/g'`"
PDATA=/live/persistence/TailsData_unlocked
PLOCAL=${PDATA}/local
PERSISTENT=${PDATA}/Persistent
STEPFILE=${PERSISTENT}/.setupstep
LASTV=${PERSISTENT}/.last_v
CPFF=${PERSISTENT}/.cpf
NPFF=${PERSISTENT}/.npf

if [ ! -d ${PLOCAL} ];then
    zenity --title="$P: Unexpected error: missing local folder." \
	--info --width=320 \
	--text="$P: Unexpected error: ${PLOCAL} missing. Aborting..." \
	--timeout=5 2>/dev/null
    exit 1
fi

if [ ! -f ${PCONF} ];then
    zenity --title="missing $PCONF." \
	--info --width=320 \
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
	--text="Tails is running $RUN_V however, supported versions are: $VZ. Would you like to continue anyway?"
    if [ $? -ne 0 ]; then
	zenity --info --title="aborting..." --text="aborting..." --timeout=5 --info 2>/dev/null
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
		    zenity --info --title="Passphrase change Succeeded!" \
			--text="Your Encryption Passphrase has been successfully changed."
		fi
	    else
		zenity --info --text="Passphrase change Aborted! (what were you thinking!)" --title="aborting" --timeout=10
		rm -f $CPFF $NPFF
		exit 1
	    fi
	    # cleanup files..
	    rm -f $CPFF $NPFF
	    # ok we done. Phew!
	    break;
	done

	STEP=2
        echo $STEP > ${STEPFILE};
    fi


    if [ "$STEP" -eq "2" ]; then
#
# Not ready for prime-time
# basic goal of STEP 2 is to repair persistent config, and restore files if necessary
# and reboot to re-connect the persistent config to the restored data...
# below doesn't really do that... yet.
#
#	# audit the persistent configuration... 
#	MDIRS=""; SEP=""
#	for d in `awk '{if($1=="T"||$1=="X") print $2;}' $PCONF`; do
#	    if [ ! -d $d ]; then
#		MDIRS="${MDIRS}${SEP}${d}"
#		SEP=" "
#	    fi
#	done
#	if [ "$MDIRS" != "" ];then
#	    zenity --info --title="Restore Recommended." --width=480 \
#		--text="The following elements are missing from your configuration: \n${MDIRS}\nIt is strongly recommend that you restore from backup and then reboot the computer." \
#		--timeout=30
#	fi
#
#	# an upgrade might be more approp here than a data-recovery; 
#	zenity --question --width=480 \
#		--title="Restore user-data?" \
#		--text="Would you like to restore data from a previous backup?"
#		--timeout=30
#	if [ $? -ne 0 ];then
#	    $CODEDIR/restore.bash
#	    # after the restore, a reboot might be needed... 
#	else
#	    zenity --info --title="No restore." --text="No data was restored."
#	fi
#	if [ "$MDIRS" != "" ];then
#	    zenity --question --title="Reboot now?" --text="Reboot is recommended, now; reboot?"
#	    if [ $? -eq 0 ];then
#		reboot &
#		exit 0
#	    fi
#	    zenity --info --text="No Reboot" --title="Reboot skipped." --timeout=5
#	fi
#
#	
	STEP=3
	echo $STEP > ${STEPFILE}
    fi
    # Once persistence is fixed it's time to make a duplicate drive!
    if [ "$STEP" -eq "3" ]; then
	zenity --question --width=480 --title="Create Fail-safe" \
		--text="It is STRONGLY recommend you create a fail-safe drive NOW, in case your primary drive gets lost or damaged!\nWould you like to create your fail-safe drive now?"
	if [ $? -eq 0 ];then
	    ${CODEDIR}/duplicate.bash
	    STEP=4
	    echo $STEP > ${STEPFILE}
	else
	   zenity --info --text="...don't put it off too long." --title="living dangerously..." --timeout=10
	fi
    fi

    #
    # Ok, now we can log the run-time version and avoid the setup in the future...
    #
    if [ "$STEP" -eq "4" -o "$STEP" -eq "3" ]; then
	zenity --info --text="Setup is complete." --title="Setup Complete." --timeout=30
	rm ${STEPFILE}
    fi
    echo ${RUN_V} >${LASTV}
fi

#
# add backup reminder
#

