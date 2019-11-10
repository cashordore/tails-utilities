#!/bin/bash
#
# setup runs upon boot when amnesia signs in.
#
#
# only root can run 
#
#if [ `whoami` != "root" ];then
#    zenity --title="$P: Insufficient Permission" \
#	--info --width=320 \
#	--text="Only root can run this command; aborting." \
#	--timeout=5 2>/dev/null
#    exit 1
#fi

P=`basename $0`
CODEDIR=`dirname $0`
PCONF="`echo ${CODEDIR}/${P}|sed 's/bash/conf/g'`"
PDATA=/live/persistence/TailsData_unlocked
PLOCAL=${PDATA}/local
PERSISTENT=${PDATA}/Persistent
STEPFILE=${PERSISTENT}/.setupstep
LASTV=${PERSISTENT}/.last_v

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
    #
    # might use 'git fetch' or similar service for this...
    # for now just bail.
    #
    VZ=`echo \`grep "^V " $PCONF | cut -d' ' -f2\``
    zenity --title="Incompatible version detected." \
	--info --width=320 \
	--text="$P: Tails $RUN_V is not compatible. Try $VZ. Aborting..." \
	--timeout=5 2>/dev/null 
    exit 1
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
	echo change password, please.

	echo password changed.
        echo 2 > ${STEPFILE};
	sleep 1
	STEP=2
    fi
    if [ "$STEP" -eq "2" ]; then
	echo "restore user-data, please."

	echo "user-data restored."
	echo 3 > ${STEPFILE}
	sleep 1
	STEP=3
	echo "reboot now, or the fail-safe drive will not function properly."
	exit 0
    fi
    if [ "$STEP" -eq "3" ]; then
	echo create fail-safe drive

	echo "fail-safe drive created"
	echo 4 > ${STEPFILE}
	sleep 1
	STEP=4
    fi

    if [ "$STEP" -eq "4" ]; then
	echo setup complete for Tails $RUN_V
	# echo ${RUN_V} >${LASTV}
	rm ${STEPFILE}
	sleep 1
    fi

    # echo ${CODE_V} >${LASTV}
    
fi
# LAST_V=`cat ${LASTV}`


#
# 
#

