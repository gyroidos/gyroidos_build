# Building trustx and trusted-connector with Docker

## Setup your ws-yocto folder
```
mkdir ~/ws-yocto
cd ~/ws-yocto
repo init -u https://github.com/trustm3/trustme_main.git -b master -m ids-x86-yocto.xml repo sync -j8
```
## Build Docker image
```
cd ~/ws-yocto/trustme/build/yocto/docker
docker build -t trustx-builder .
```
## Start Docker
```
cd ~/ws-yocto/trustme/build/yocto/docker
./run-docker ~/ws-yocto
```

## Follow the build instructions inside Docker
```
source init_ws.sh out-yocto
bitbake trustx-cml-initramfs multiconfig:container:ids
wic create -e trustx-cml-initramfs --no-fstab-update trustmeimage
```
