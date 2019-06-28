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
	echo "overriding $OUTFILE as requested."

if [ "$FORMAT" = "y" ]; then
	echo "Overriding $OUTFILE as requested"
	bootsize="$(du --block-size=1 /mnt/trustme_boot/)"
	bootsize="$(expr $bootsize + 20000000)"

	parted -s --align optimal mklabel gpt device "$OUTFILE"
	sync
	partprobe

	# Create boot partition
	sgdisk --set-alignment=4096 "--new=1:+0B:+${bootsize}B"
	sync
	partprobe

	mkfs.fat -F 16 i -n boot ${OUTFILE}${INFIX}1
	sync
	partprobe

	sgdisk --change-name=1:boot
	parted -s ${OUTFILE}${INFIX}1 set 1 legacy_boot on
	parted -s ${OUTFILE}${INFIX}1 set 1 msftdata  on
	parted -s ${OUTFILE}${INFIX}1 set 1 boot off
	parted -s ${OUTFILE}${INFIX}1 set 1 esp off
	sync
	partprobe

	echo "Created boot partition"
	parted -s ${OUTFILE}${INFIX}1 unit B --align none print


	# Create data partition
	sgdisk --set-alignment=4096 --largest-new=2
	sync
	partprobe

	mkfs.ext4 -L installerdata ${OUTFILE}${INFIX}2
	sync
	partprobe

	sgdisk --change-name=2:installerdata
	parted -s ${OUTFILE}${INFIX}2 set 2 legacy_boot off
	parted -s ${OUTFILE}${INFIX}2 set 2 msftdata  off
	parted -s ${OUTFILE}${INFIX}2 set 2 boot off
	parted -s ${OUTFILE}${INFIX}2 set 2 esp off
	
	echo "Created datapartition"
	parted -s ${OUTFILE}${INFIX}2 unit B --align none print



	mkdir /bootpart
	mkdir /datapart

	mount "${OUTFILE}${INFIX}1" /bootpart

	cp /mnt/cml-BOOTX64.EFI

	mkdir -p /bootpart/EFI/BOOT
	 cp -r /mnt/trustme_boot/* /bootpart/

	umount /bootpart

	mount "${OUTFILE}${INFIX}2" /datapart
	cp -r /mnt/userdata /datapart
	cp -r /mnt/userdata/modules /datapart

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
