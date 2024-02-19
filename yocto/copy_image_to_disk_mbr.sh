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

if [ ! -b "$OUTFILE" ];then
	echo "$OUTFILE is not a block special device. Please specify valid disk."
	exit 1
fi

USEBMAPTOOL="y"
if [ -z $(which bmaptool) ]; then
	echo "bmaptool not found. Fallback to dd."
	USEBMAPTOOL="n"
fi
if [ ! -f "$INFILE.bmap" ]; then
	echo "bitmap file $INFILE.bmap not found. Fallback to dd."
	USEBMAPTOOL="n"
fi

FORMAT="n"
read -p "Do you want to write $INFILE to $OUTFILE?
THIS WILL ERASE ALL DATA ON $OUTFILE [y/n]" FORMAT

if [ "$FORMAT" = "y" ]; then
	echo "overriding $OUTFILE as requested."
	if [ "$USEBMAPTOOL" = "y" ]; then
		bmaptool copy $INFILE $OUTFILE
	else
		if [ -n $(which pv) ]; then
			size=$(ls -l $INFILE | awk '{print $5}')
			dd if=$INFILE bs=4096 status=none | pv -s ${size} | dd of=$OUTFILE bs=4096
		else
			dd if=$INFILE of=$OUTFILE bs=4096
		fi
		echo "Sucessfully dd'ed image to $OUTFILE\n" 1>&2
		echo "Syncing disks. This may take a while...\n" 1>&2
		sync
	fi

	sleep 2
	partprobe

	PARTED_PARTITION_START="$(parted $OUTFILE unit b print | grep ' 2.*[0-9]\+' | awk '{print $2}' | tr -d 'B')"
	PARTED_DISK_SIZE="$(parted $OUTFILE unit b print | grep 'Disk .*: [0-9]\+B' | awk -F ': ' '{print $2}' | tr -d 'B')"
	PARTED_PARTITION_END="$(expr $PARTED_DISK_SIZE - 1)"

	echo "Expanding partition $PARTNUM to use all available space ($PARTED_PARTITION_START, $PARTED_PARTITION_END, $PARTED_DISK_SIZE)"

	parted -s "$OUTFILE" rm 2
	sync
	sleep 2
	partprobe

	parted "$OUTFILE" print
	echo "Creating resized partition"

	parted -s "$OUTFILE" mkpart primary ext4 ${PARTED_PARTITION_START}B ${PARTED_PARTITION_END}B
	sync
	sleep 2
	partprobe

	echo "Resizing filesystem on $OUTFILE$INFIX$PARTNUM"

	e2fsck -f -y "$OUTFILE$INFIX$PARTNUM"

	resize2fs "$OUTFILE$INFIX$PARTNUM"
	sync
	sleep 2
	partprobe


	for i in $(seq 1 $PARTNUM); do
		uuid=$(cat /proc/sys/kernel/random/uuid)
		sfdisk --part-uuid $OUTFILE $i $uuid
		sync
		sleep 2
		echo "Running partprobe"
		partprobe
	done

else
	echo "Aborting as requested by user"
	exit 1
fi
