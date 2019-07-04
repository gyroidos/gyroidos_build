#!/bin/sh

echo $EUID

if [ $# -ne 2 ];then
	echo "USAGE: $0 <input image> <number of MB to append>"
	exit 1
fi

if ! [ "$(id -u)"="0" ];then
	echo "ERROR: Need root priviledges to use loop devices"
	exit 1
fi

INFILE=$1
EXTENDBYTES=$2
PARTNUM=3



FORMAT="n"
read -p "Do you want to prepare $INFILE for QEMU boot, appending $EXTENDBYTES MB?
THIS IS A FILESYSTEM OPERATION AND MAY CAUSES DATA LOSS THE TARGET IMAGE $INFILE. BE SURE TO HAVE A BACKUP. CONTINUE? [y/n]" FORMAT

if [ "$FORMAT" = "y" ]; then
	echo "Changing $OUTFILE as requested."
	dd status=progress if=/dev/zero of="$INFILE" bs=1M count=$EXTENDBYTES oflag=append conv=notrunc
	partprobe
	sgdisk --move-second-header "$INFILE"
	partprobe

	BLOCKSIZE=$(cat /sys/class/block/nvme0n1/queue/physical_block_size)
	TRUSTMEPART="$OUTFILE$INFIX$PARTNUM"
	echo "trustme partition file: ${TRUSTMEPART}"
	GPTOFFSET=$(( $BLOCKSIZE*34 ))

	echo "Second GPT header offset: ${GPTOFFSET}, blaocksize: ${BLOCKSIZE}"

	echo "Resizing trustme partition "${TRUSTMEPART}"
	parted "$TRUSTMEPART" resizepart "-$GPTOFFSET" 
	btrfs filesystem resize max "${TRUSTMEPART}"

	sfdisk --part-uuid $INFILE $PARTNUM $(uuidgen)
	LOOPDEV=$(losetup --find --show --partscan "$INFILE")
	echo "Set up $LOOPDEVICE for $INFILE"
	MAKEFS="n"
	read -p "Do you want to create filesystem on loop device ${LOOPDEV}p${PARTNUM} ?
	THIS WILL ERASE ALL DATA ON ${LOOPDEV}p${PARTNUM}$. CONTINUE? [y/n]" FORMAT


	if [ "$FORMAT" = "y" ]; then
		echo "Creating filesystem on partition 4 as requested"
		mkfs.btrfs --force --label containers "${LOOPDEV}p${PARTNUM}"
	else
		echo "Skipping creation of filesystem on partition 4 as requested"
	fi

	losetup -d "$LOOPDEV"
	partprobe
else
	echo "Aborting as requested by user"
	exit
fi
