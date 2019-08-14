#!/bin/sh

OUTFILE=$1
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

echo "INFIX: $INFIX"

FORMAT="n"
read -p "Do you want to write $INFILE to $OUTFILE?
THIS WILL ERASE ALL DATA ON $OUTFILE [y/n]" FORMAT
	echo "overriding $OUTFILE as requested."

if [ "$FORMAT" = "y" ]; then
	echo "Overriding $OUTFILE as requested"
	bootsize="$(du -s -k /data/trustme_boot/ | awk '{print $1}')"
	bootsize="$(expr "${bootsize}" + 20000)"
	echo "Boot partition size: $bootsize"

	parted "$OUTFILE" -s --align optimal mklabel gpt
	sync
	sleep 2
	partprobe

	# Create boot partition
	sgdisk --new=1:+0K:+${bootsize}K --change-name=1:boot $OUTFILE
	echo "Created boot partition"
	sync
	partprobe

	mkfs.fat -F 16 -n BOOT ${OUTFILE}${INFIX}1
	sync
	sleep 2
	partprobe

	parted -s ${OUTFILE} set 1 legacy_boot on
	parted -s ${OUTFILE} set 1 msftdata  on
	parted -s ${OUTFILE} set 1 boot off
	parted -s ${OUTFILE} set 1 esp off
	sync
	partprobe

	echo "Created boot partition"


	# Create data partition
	sgdisk --set-alignment=4096 --largest-new=2 --change-name=2:trustme $OUTFILE
	sync
	sleep 2
	partprobe

	mkfs.ext4 -L trustme ${OUTFILE}${INFIX}2
	sync
	partprobe

	parted -s ${OUTFILE} set 2 legacy_boot off
	parted -s ${OUTFILE} set 2 msftdata  off
	parted -s ${OUTFILE} set 2 boot off
	parted -s ${OUTFILE} set 2 esp off
	
	echo "Created datapartition"



	mkdir -p /bootpart
	mkdir -p /datapart

	mount "${OUTFILE}${INFIX}1" /bootpart
	cp -r /data/trustme_boot/* /bootpart/
	umount /bootpart

	mount "${OUTFILE}${INFIX}2" /datapart
	cp -r /data/trustme_data/* /datapart
	umount /datapart
else
	echo "Aborting as requested by user"
	exit
fi

for i in $(seq 1 $PARTNUM); do
	sfdisk --part-uuid $OUTFILE $i $(uuidgen)
	sync
	partprobe
done

echo "trustme successfully installed to $OUTFILE"
