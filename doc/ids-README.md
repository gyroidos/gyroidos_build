# Howto Build the IDS Core Platform

This will include some pre-built demo container images

## Setup Build Machine
Follow the steps of trust|me build howto under point [Prepare your build machine](../README.md#prepare-your-build-machine)

## Checkout IDS core platform code

    mkdir -p workspace
    cd workspace
    repo init -u https://github.com/trustm3/trustme_main -m ids-x86.xml -b trustme-7.1.2_r33-github
    repo sync
    
## Prepare PKI and adbkey
Prepare the PKI and Host-adbkey as described in trust|me build howto under points

1. [Prepare PKI](../README.md#prepare-pki)
2. [adb key for deployment of containers](../README.md#adb-key-for-deployment-of-containers)

## Build and run it

    make ids-all
    {qemu-system-x86_64 | kvm} -m 1G -kernel out-trustme/target/x86/bzImage \
        -initrd out-trustme/target/x86/ramdisk.img -append "console=ttyS0 \
        console_loglevel=7 debug selinux=0" -serial stdio -redir tcp:55550::55550 \
        -redir tcp:8181::8181 -drive file=out-trustme/target/x86/userdata_ids.img,format=raw,media=disk.

### Connect via adb

    adb connect 127.0.0.1:55550
    adb shell
  
### Deploy IDS containers
This step is optional, since the idsos core container is
already included in the userdata_ids.img. However if you
want to update the core container during runtime you can
use the following make target to deploy the images.

    make deploy_ids
    adb shell reboot -f

## Build demo images
    make debian_full_image
    adb push out-trustme/target/x86/debos-* /data/cml/operatingsystems

## create some container configs
    adb shell
    UUID=`cat /proc/sys/kernel/random/uuid`
    echo ${UUID}
    vim /data/cml/containers/${UUID}.conf

A sample container config looks like this

    name: "Container name"
    guest_os: "debos"
    color: 0

The name can be any string as you like to name your container.
guest_os needs to be the name of a valid guest_os, in the
demo use case the only valid names are idsos or debos.

You have to reboot the system to bring up the new containers.

## check available containers

    cml-control list
