# Build and flash trust|me
> **Note**: This code repository currently supports the Google Nexus 5 (hammerhead) device only!

> **Note**: For IDS Platform (x86) howto see [doc/ids-README.md](doc/ids-README.md) 

## Prepare your build machine
In the following, we briefly describe the setup on the example of debian 8 (jessie).
For ubuntu have a look at [AOSP Initialize Build Environment](https://source.android.com/source/initializing.html)

### Install standard packages
For debian 8 (stable) this would be:

    apt-get install build-essential libc6-dev git-core gnupg flex bison gperf libsdl1.2-dev \
        libesd0-dev libwxgtk2.8-dev squashfs-tools zip curl libncurses5-dev zlib1g-dev \
        pngcrush schedtool libxml2 libxml2-utils xsltproc g++-multilib lib32z1-dev \
        lib32ncurses5-dev lib32readline-gplv2-dev gcc-multilib ccache abootimg \
        qemu-user-static parted qemu-user texlive-latex-base re2c python-protobuf \
        protobuf-compiler protobuf-c-compiler bc lzip
        
If you followed the AOSP instructions at 
[AOSP Initialize Build Environment](https://source.android.com/source/initializing.html), you need the
following addtional packages for trust|me

    apt-get install qemu-user-static parted qemu-user texlive-latex-base re2c python-protobuf \
        protobuf-compiler protobuf-c-compiler bc lzip

### Install java
For lollipop (5.1)

    apt-get install openjdk-7-jdk # for lollipop (5.1)
  
For nougat (7.0) temporarily add the backports to
    vi /etc/apt/sources.list
    
>   # used for openjdk-8  
    deb http://ftp.debian.org/debian jessie-backports main

    apt-get update
    apt-get install -t jessie-backports openjdk-8-jdk-headless openjdk-8-jre-headless # for nougat (7.0)

### Install "repo" tool
For more information on repo see [AOSP Download Source](https://source.android.com/source/downloading.html)

    mkdir ~/bin
    cd ~/bin
    wget https://storage.googleapis.com/git-repo-downloads/repo
    chmod a+x repo
    export PATH=$PATH:~/bin
    
### Install fastboot
    apt-get install android-tools-fastboot

### Configure "git"
    git config --global user.email "you@example.com"
    git config --global user.name "Your Name"
    
    
## Checkout and prepare build of trust|me
The trustme branches are named after the corresponding aosp tag on which it is based. Currently
there are two branches for Android version 5.1.1 and 7.0.0:
*trustme-5.1.1_r38-github* and *trustme-7.0.0_r6-github*

    mkdir -p workspace
    cd workspace
    repo init -u https://github.com/trustm3/trustme_main -m trustme-hammerhead.xml -b trustme-5.1.1_r38-github
    repo sync
    
### Prepare PKI
To later be able to sign your build (also replace the test keys inside android with release keys)
a test PKI will be setup during first build. This will include a user token which can be used for
container encryption.  
**Change the default passwords** in:

    trustme/build/device_provisioning/test_certificates/test_passwd_env.bash
    
The generated user token is not used by default as the device generates its one token during first boot.
However there exits provisioning scripts which will replace the usertoken or you can replace it manually
as described below.

### Enable GApps as feature
If you want to be able to use gapps inside of your containers
you have to download the corresponding gapps package to your workspace.
See [gapps for 5.1.1](https://github.com/trustm3/trustme_build/tree/trustme-5.1.1_r38-github/gapps)
or [gapps for 7.0.0](https://github.com/trustm3/trustme_build/tree/trustme-7.0.0_r6-github/gapps)

### Build it
Just run
    
        make
        # or for signed release builds
        make dist-all dist-sign
    
### adb key for deployment of containers
The trust|me adb access to the root namespace (ramdisk) is only allowed to one host adbkey.
This adb key is automatically generated during first build in
/trustme/build/device_provisioning/test_certificates/dev.user.adbkey[.pub]
You have to copy this key to your local adb configuration to be able to deploy containers later on.
    
Before you overwrite your adbkey make a backup:

    cp ~/.android/adbkey ~/.android/adbkey.bak
    
Then copy the adbkey of the workspace to your configuration and restart adb
    
    cd workspace
    cp trustme/build/device_provisioning/test_certificates/dev.user.adbkey ~/.android/adbkey
    adb kill-server
    
Alternatively you can copy your current host adb pub key to the test_certificats folder
and rebuild the userdata image

    cp ~/.android/adbkey.pub trustme/build/device_provisioning/test_certificates/dev.user.adbkey.pub
    cp ~/.android/adbkey trustme/build/device_provisioning/test_certificates/dev.user.adbkey
    make userdata_image
    
### Flash device
#### Unlock hammerhead

To be able to flash trustme on the hammerhead device the bootloader has to be unlocked:

get device into fastboot mode: "Press and hold both Volume Up and Volume Down, then press and hold Power"

    fastboot oem unlock

#### Flash hammerhead
The adb version needed for make deploy_images is 1.0.32! (usually we build this as part of the overall
trust|me build)  
press "Volume Down" hold it and then additionally press "Power"  
Plugin mobile phone to USB port on PC  

    fastboot flash boot out-trustme/target/hammerhead/boot.img \
        flash recovery out-trustme/target/hammerhead/recovery.img \
        flash userdata out-trustme/target/hammerhead/userdata.img

    fastboot reboot
    make deploy_images
    
#### Change default usertoken password
Now you have deployed a development release to your device. The device generates a user token which
is used to encrypt the containers data with the default password **trustme**.
If you want to use the phone for real user data, you are strongly advised to change the password of this
token before you start any container for the fist time!

```{r, engine='bash', count_lines}
# get token from device
adb pull /data/cml/tokens/testuser.p12 .
# unwrap token
openssl pkcs12 -in testuser.p12 -out tmpmycert.pem -nodes
# rewrap token
openssl pkcs12 -export -out newtestuser.p12 -in tmpmycert.pem
# remove temp file
rm tmpmycert.pem
# push new token and remove temp tokens
adb push newtestuser.p12 /data/cml/tokens/testuser.p12
rm testuser.p12 newtestuser.p12
```

or just replace the token with the generated test token in
trustme/build/device_provisioning/test_certificates/dev.user.p12
    
    adb push trustme/build/device_provisioning/test_certificates/dev.user.p12 /data/cml/tokens/testuser.p12
