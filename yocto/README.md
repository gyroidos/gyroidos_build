# Quickstart

### setup host
```
   apt-get install sbsigntool python-protobuf python3-protobuf
```

### build
```
   mkdir ws-yocto
   cd ws-yocto
   repo init -u https://github.com/trustm3/trustme_main.git -b master -m ids-x86-yocto.xml
   repo sync -j8
   source init_ws.sh out-yocto
   bitbake trustx-cml-initramfs
   bitbake trustx-core
   bitbake trustx-cml-userdata

```

### Build trustme image
```
   wic create -e trustx-cml-initramfs --no-fstab-update trustmeimage
```

### Run trustme image in QEMU/KVM
   Before booting the trustme image in QEMU/KVM an partitioned image
   for the cmld containers has to be created.

```
   apt-get install ovmf
   dd if=/dev/zero of=containers.btrfs bs=1M count=<space to be available for containers>
   /sbin/sgdisk --new=1:+0:-0 containers.btrfs
   /sbin/sgdisk --change-name 1:containers containers.btrfs
   sudo kpartx -a containers.btrfs
   sude mkfs.btrfs /dev/mapper/<containers partition device>
   sudo kpartx -d containers.btrfs
```

   Now the trustme image can be booted as follows:   

```
kvm -m 4096 -bios OVMF.fd  -device virtio-scsi-pci,id=scsi -device scsi-hd,drive=hd -drive if=none,id=hd,file=<trustme image>,format=raw  -device scsi-hd,drive=hdc -drive if=none,id=hdc,file=containers.btrfs,format=raw
```
   
### Create bootable medium
```
   apt-get install util-linux btrfs-progs gdisk parted
```

   **WARNING: This operation will wipe all data from target medium**
```
   sudo trustme/build/yocto/copy_image_to_disk.sh <trustme-image> </path/to/target/device>
```

### Launch cmld
   A shell is available on tty12. In order to access it, press Ctrl+Alt+2 inside the QEMU window to switch to the QEMU monitor. Now write 'sendkey ctrl-alt-f12' and confirm with Enter to switch to tty12 and interact with the shell.

```
   scd # initial provisioning (do only on first run, will terminate)
   scd &
   cmld
```

### Rebuild recipe (e.g. trustx-cml-initramfs)
```
    bitbake -f -c compile <recipe>
    bitbake -f -c do_sign_guestos <recipe> 
```

### Change kernel config

Temporarily
```
     bitbake -f -c menuconfig virtual/kernel
     bitbake -f virtual/kernel
     bitbake -f trustx-cml-initramfs
```

    Persistently
```
    Add file to meta-trustx/recipes-kernel/linux/files
    Register new file in .bbappend files inside meta-trustx/recipes-kernel/linux/
 
```

# Description

### create a workspace directory
```
   mkdir ws-yocto
   cd ws-yocto
```

### fetch yocto meta repos and trustme/build repo
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
   bitbake trustx-cml-initramfs
```

   - Distro config: meta-trustx/conf/distro/cml-tiny.conf
   - Image-BB: meta-trustx/image/trustx-cml-initramfs.bb
   - this generates a test PKI if none is present inside the out-yocto directory


## Replace Platform keys with generated ones
   Create bootable device for replacing EFI keys:

```
   bitbake trustx-cml-initramfs
   wic create -e trustx-cml-initramfs keytoolimage
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
   bash ../trustme/build/device_provisioning/gen_dev_certs.sh
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
   wic create -e trustx-keytool keytoolimage
