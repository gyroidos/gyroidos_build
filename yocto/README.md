# Quickstart

### setup host tools
```
   apt-get install sbsigntool python-protobuf python3-protobuf
```

### build
```
   mkdir ws-yocto
   cd ws-yocto
   repo init -u https://github.com/trustm3/trustme_main -b master -m ids-x86-yocto.xml
   repo sync -j8
   source init_ws.sh out-yocto
   bitbake trustx-cml-initramfs
   bitbake trustx-core
   bitbake trustx-cml-userdata
```

### run in kvm/qemu-system with efi
```
   kvm -bios OVMF.fd -kernel tmp/deploy/images/intel-corei7-64/bzImage-initramfs-intel-corei7-64.bin \
      -device virtio-scsi-pci,id=scsi -device scsi-hd,drive=hd \
      -drive if=none,id=hd,file=tmp/deploy/images/intel-corei7-64/trustx-cml-userdata-intel-corei7-64.ext4,format=raw
   
   A shell is available on tty12. In order to access it, press Ctrl+Alt+2 inside the QEMU window to switch to the QEMU monitor. Now write 'sendkey ctrl-alt-f12' and confirm with Enter to switch to tty12 and interact with the shell.
```

### test CML binaries
```
   mount /dev/sda /data
   scd # initial provisioning (will terminate)
   scd &
   cmld
```

### Rebuild trustx-core

    bitbake -f -c compile trustx-core
    bitbake -f -c do_sign_guestos trustx-core 

### Change kernel config
Temporarily
     bitbake -f -c menuconfig virtual/kernel
     bitbake -f virtual/kernel
     bitbake -f trustx-cml-initramfs

    Persistently
    Add file to meta-trustx/recipes-kernel/linux/files
    Register new file in .bbappend files inside meta-trustx/recipes-kernel/linux/
 

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
   export DEVICE=x86
   source init_ws.sh out-yocto
```

   This automatically switches to out-yocto
   and extends out-yocto/conf/local.conf to configure merged kernel+ramfs binary

### build own cml-tiny distro
```
   bitbake trustx-cml-initramfs
```

   - Distro config: meta-trustx/conf/distro/cml-tiny.conf
   - Image-BB: meta-trustx/image/trustx-cml-initramfs.bb

### install efitools and sbsigntool
```
   apt-get install sbsigntool efitools
```

   efitools is only in testing but efitools can also be built from sourece
   !! There is a recipe in meta-trustx/receips-kernel/efitools now !! 

```
   apt-get install libssl-dev gnu-efi
   wget https://git.kernel.org/pub/scm/linux/kernel/git/jejb/efitools.git/snapshot/efitools-1.8.1.tar.gz
   tar xvzf efitools-1.8.1.tar.gz
   cd efitools-1.8.1
   make
```

## Build userdata image containing some certificates
```
   bitbake trustx-cml-userdata
```

   - Image-BB: meta-trustx/image/trustx-cml-initramfs.bb

   - trustx-cml-userdate should generate test_certifictes
   by running this in do_install of userdata package in 
   meta-trustx/recipes-trustx

```
   bash ../trustme/build/device_provisioning/gen_dev_certs.sh
```

### Signing kernel+initramfs binary
```
   sbsign --key test_certificates/ssig_subca.key \
      --cert test_certificates/ssig_subca.cert \
      --output linux.sigend.efi \
      tmp/deploy/images/intel-corei7-64/bzImage-initramfs-intel-corei7-64.bin
```

   This should be placed as /EFI/BOOT/bootx64.efi
   on an EFI system partition on an USB Stick

## Replace Platform keys with generated ones
   format usbdisk part1 EFI system partition

```
   mkdir <usb-disk>/keys
   cp test_certificates/*.esl <usb-disk>/keys
   cp efitools-1.8.1/KeyTool-signed.efi <usb-disk>/EFI/BOOT/bootx64.efi
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
