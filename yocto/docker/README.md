# Building gyroidos and trusted-connector with Docker

## Setup your ws-yocto folder
```
mkdir ~/ws-yocto
cd ~/ws-yocto
repo init -u https://github.com/gyroidos/gyroidos.git -b master -m ids-x86-yocto.xml repo sync -j8
```
## Build Docker image
```
cd ~/ws-yocto/gyroidos/build/yocto/docker
docker build -t gyroidos-builder .
```
## Start Docker
```
cd ~/ws-yocto/gyroidos/build/yocto/docker
./run-docker ~/ws-yocto
```

## Follow the build instructions inside Docker
```
source init_ws.sh out-yocto
bitbake gyroidos-cml-initramfs multiconfig:container:ids
wic create -e gyroidos-cml-initramfs --no-fstab-update gyroidosimage
```
