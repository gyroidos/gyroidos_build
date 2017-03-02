# Howto Build the IDS Core Platform

This will include some pre-built demo container images

## Setup Build Machine
Follow the steps of trust|me build howto under point [Prepare your build machine](../README.md#prepare-your-build-machine)

## Checkout IDS core platform code
Currently there is only the branch *trustme-5.1.1_r38-github* which holds the
x86 specific code for the IDS core platform

    mkdir -p workspace
    cd workspace
    repo init -u https://github.com/trustm3/trustme_main -m ids-x86.xml -b trustme-5.1.1_r38-github
    repo sync
    
## Prepare PKI and adbkey
Prepare the PKI and Host-adbkey as described in trust|me build howto under points

1. [Prepare PKI](../README.md#prepare-pki)
2. [adb key for deployment of containers](../README.md#adb-key-for-deployment-of-containers)

## Build and run it

    make ids-all
    {qemu-system-x86_64 | kvm} -kernel out-trustme/kernel/x86/obj/arch/x86/boot/bzImage \
        -initrd out-cml/target/product/trustme_x86_cml/ramdisk.img -append "console=ttyS0 \
        console_loglevel=7 debug selinux=0" -serial stdio -redir tcp:55550::55550 \
        -redir tcp:8080::8080 -drive file=out-trustme/target/x86/userdata.img,format=raw,media=disk.
    
### Connect via adb

    adb connect 127.0.0.1:55550
    adb root
    adb connect 127.0.0.1:55550
    adb shell
  
### Deploy IDS containers

    make deploy_ids
    adb shell reboot -f
