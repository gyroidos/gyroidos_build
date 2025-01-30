# Quickstart

### Setup host
> Following instructions where tested on Debian stable (Strech 9.6) (x86-64)

Install Yocto/Poky dependencies ([Build Host Packages](https://www.yoctoproject.org/docs/2.5.1/brief-yoctoprojectqs/brief-yoctoprojectqs.html#brief-build-system-packages))
```
   apt-get install gawk wget git-core diffstat unzip texinfo gcc-multilib \
	build-essential chrpath socat cpio python python3 python3-pip \
	python3-pexpect xz-utils debianutils iputils-ping libsdl1.2-dev xterm
```

Install additional protobuf dependencies for image signing
```
   apt-get install python-protobuf python3-protobuf
```

### Build
```
   mkdir ws-yocto
   cd ws-yocto
   repo init -u https://github.com/gyroidos/gyroidos.git -b master -m ids-x86-yocto.xml
   repo sync -j8
   source init_ws.sh out-yocto
   bitbake gyroidos-cml-initramfs multiconfig:container:gyroidos-core
```

#### Build gyroidos image
```
   wic create -e gyroidos-cml-initramfs --no-fstab-update gyroidosimage
```
This will create an disk image file with the current timestamp in the
filename, e.g., gyroidosimage-201812131539-sda.direct

### Run gyroidos image in QEMU/KVM (x86-64)
```
   apt-get install qemu-kvm ovmf
```
   Before booting the gyroidos image in QEMU/KVM an partitioned image
   for the cmld containers has to be created.

```
   dd if=/dev/zero of=containers.btrfs bs=1M count=<space to be available for containers>
   mkfs.btrfs -L containers containers.btrfs
```

   Now the gyroidos image can be booted as follows:

```
   kvm -m 4096 -bios OVMF.fd -serial mon:stdio \
	-device virtio-scsi-pci,id=scsi \
	-device scsi-hd,drive=hd0 -drive if=none,id=hd0,file=$(ls gyroidos-* | tail -n1),format=raw \
	-device scsi-hd,drive=hd1 -drive if=none,id=hd1,file=containers.btrfs,format=raw
```

### Run gyroidos image on pyhsical Machine (x86-64)
#### Create bootable medium
```
   apt-get install util-linux btrfs-progs gdisk parted
```

   **WARNING: This operation will wipe all data from target medium**
```
   sudo gyroidos/build/yocto/copy_image_to_disk.sh <gyroidos-image> </path/to/target/device>
```

### Launch cmld
   A shell is available on tty12. In order to access it, press Ctrl+Alt+2 inside the QEMU window to switch to the QEMU monitor. Now write 'sendkey ctrl-alt-f12' and confirm with Enter to switch to tty12 and interact with the shell. Or you can toggle between ttys by pressing Alt+right and Alt+left in the QEMU window.

```
   scd # initial provisioning (do only on first run, will terminate)
   scd &
   cmld
```

### Rebuild recipe (e.g. gyroidos-cml-initramfs)
```
    bitbake -f -c compile <recipe>
    bitbake -f -c do_sign_guestos <recipe>
```

### Change kernel config

Temporarily
```
     bitbake -f -c menuconfig virtual/kernel
     bitbake -f virtual/kernel
     bitbake -f gyroidos-cml-initramfs
```

Persistently
* Add file to meta-trustx/recipes-kernel/linux/files
* Register new file in .bbappend files inside meta-trustx/recipes-kernel/linux/

# Description

### create a workspace directory
```
   mkdir ws-yocto
   cd ws-yocto
```

### fetch yocto meta repos and gyroidos/build repo
```
   repo init -u ...
   repo sync -j8
```

### setup yocto environment (poky)
```
   export DEVICE=x86 # (is set by default)
   source init_ws.sh out-yocto
```

   This automatically switches to out-yocto
   and extends out-yocto/conf/local.conf to configure merged kernel+initramfs binary

### build own poky-tiny distro
```
   bitbake gyroidos-cml-initramfs
```

   - Distro config: meta-trustx/conf/distro/cml-tiny.conf
   - Image-BB: meta-trustx/image/gyroidos-cml-initramfs.bb
   - this generates a test PKI if none is present inside the out-yocto directory


## Replace Platform keys with generated ones
   Create bootable device for replacing EFI keys:

```
   bitbake gyroidos-keytool
   wic create -e gyroidos-keytool keytoolimage
```
   **WARNING: This will wipe all data on the target device**
```
   dd if=<keytoolimage.img> of=</path/to/target/device>
```

   Optionally, Boot still in User Mode and Bakup current Platform keys (KeyTool -> Save Keys)

   Boot in Setup Mode (BIOS -> Secure Boot -> Erase platform key / Setup mode)

```
   KeyTool -> Edit Keys
   Replace db with keys/DB.esl
   Replace KEK with keys/KEK.esl
   Peplace PK with keys/PK.auth
```

   The PK replacement will switch to User Mode

   see https://www.rodsbooks.com/efi-bootloaders/controlling-sb.html for more information


# Manual operations, automatically performed during build

## Build test PKI manually
```
   remove test PKI link/directory at out-yocto/test_certificates
   bash ../gyroidos/build/device_provisioning/gen_dev_certs.sh
```

### Signing kernel+initramfs binary manually
```
   sbsign --key test_certificates/ssig_subca.key \
      --cert test_certificates/ssig_subca.cert \
      --output linux.sigend.efi \
      tmp/deploy/images/intel-corei7-64/bzImage-initramfs-intel-corei7-64.bin
```

   This should be placed as /EFI/BOOT/BOOTX64.efi
   on an EFI system partition on an USB Stick, e.g. by
   wic create -e gyroidos-keytool keytoolimage
