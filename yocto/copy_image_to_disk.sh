#!/bin/sh

INFILE=$1
OUTFILE=$2
PARTNUM=4

case "$(basename $OUTFILE)" in
	sd*	) INFIX="";;	
	hd*	) INFIX="";;
	nvm*	) INFIX="p";;
	mmc*	) INFIX="p";;
	*	)
		echo "Unknown target device type. Exiting..."
		exit;;
esac


FORMAT="n"
read -p "Do you want to write $INFILE to $OUTFILE?
THIS WILL ERASE ALL DATA ON $OUTFILE [y/n]" FORMAT

if [ "$FORMAT" = "y" ]; then
	echo "overriding $OUTFILE as requested."
	dd status=progress if=$INFILE of=$OUTFILE bs=4096
	sgdisk --move-second-header $OUTFILE
	partprobe
else
	echo "Aborting as requested by user"
	exit
fi

sgdisk --largest-new=4 $OUTFILE

sfdisk --part-label $OUTFILE $PARTNUM "containers"

partprobe

for i in $(seq 1 $PARTNUM); do
	sfdisk --part-uuid $OUTFILE $i $(uuidgen)
	partprobe
done



PARTFILE="$OUTFILE$INFIX$PARTNUM"

mkfs.btrfs --force $PARTFILE
