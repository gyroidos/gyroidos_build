#!/bin/sh

INFILE=$1
OUTFILE=$2
PARTNUM=2

case "$(basename $OUTFILE)" in
	sd*	) INFIX="";;	
	hd*	) INFIX="";;
	nvm*	) INFIX="p";;
	mmc*	) INFIX="p";;
	loop*	) INFIX="p";;
	*	)
		echo "Unknown target device type. Exiting..."
		exit;;
esac


FORMAT="n"
read -p "Do you want to write $INFILE to $OUTFILE?
THIS WILL ERASE ALL DATA ON $OUTFILE [y/n]" FORMAT

if [ "$FORMAT" = "y" ]; then
	echo "overriding $OUTFILE as requested."
	dd if=$INFILE of=$OUTFILE bs=4096 &
	DDPID=$!

	while [ $(kill -USR1 $DDPID) -ne 0 ];do
		sleep 1
	done

	sync
	sgdisk --move-second-header $OUTFILE
	partprobe
else
	echo "Aborting as requested by user"
	exit
fi

for i in $(seq 1 $PARTNUM); do
	sfdisk --part-uuid $OUTFILE $i $(uuidgen)
	sync
	partprobe
done

SGDISK_FIRST_SECTOR="$(/sbin/sgdisk --info=2 "$OUTFILE$INFIX$PARTNUM" | grep 'First sector: [0-9]\+ .*' | awk -F ': ' '{print $2}' | awk -F ' ' '{print $1}')"
SGDISK_END_OF_LARGEST="$(/sbin/sgdisk --end-of-largest)"

sgdisk --delete=$PARTNUM
sync
partprobe

sgdisk "--new=$PARTNUM:${SGDISK_FIRST_SECTOR}s:${SGDISK_END_OF_LARGEST}s"
sync
partprobe

resize2fs "$OUTFILE$INFIX$PARTNUM"
sync
partprobe
