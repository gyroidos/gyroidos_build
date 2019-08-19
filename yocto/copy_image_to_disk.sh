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
	dd if=$INFILE of=$OUTFILE bs=4096

	echo "Sucessfully dd'ed image to $OUTFILE\n" 1>&2
	echo "Syncing disks. This may take a while...\n" 1>&2
	sync
	sleep 2
	partprobe

	sgdisk --move-second-header $OUTFILE
	sync
	sleep 2
	echo "Done syncing, running partprobe"
	partprobe

	echo "Moved second GPT header to end of disk"

	SGDISK_FIRST_SECTOR="$(sgdisk --info=2 $OUTFILE | grep 'First sector: [0-9]\+ .*' | awk -F ': ' '{print $2}' | awk -F ' ' '{print $1}')"
	SGDISK_END_OF_LARGEST="$(sgdisk --end-of-largest $OUTFILE)"

	echo "Expanding partition $PARTNUM to use all available space"
	echo "New start sector: $SGDISK_FIRST_SECTOR"
	echo "New end sector: $SGDISK_END_OF_LARGEST"



	sgdisk --delete=$PARTNUM "$OUTFILE"
	sync
	sleep 2
	partprobe

	echo "Creating resized partition"

	origname2="$(parted "$INFILE" print | grep -E '^[ ]+2' | awk '{print $6}')"

	sgdisk --set-alignment=1 --new=$PARTNUM:${SGDISK_FIRST_SECTOR}s:${SGDISK_END_OF_LARGEST}s --change-name=2:$origname2 "$OUTFILE"
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
		sfdisk --part-uuid $OUTFILE $i $(uuidgen)
		sync
		sleep 2
		echo "Running partprobe"
		partprobe
	done

else
	echo "Aborting as requested by user"
	exit 1
fi
