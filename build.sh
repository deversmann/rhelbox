#!/bin/bash

RHEL_ISO="/Users/deversma/Downloads/rhel-8.4-x86_64-dvd.iso"
VM="rhelbox-$(date +%s)"
BUILD_DIR="build"
RELEASE_DIR="release"

# sanity check
[[ ! -e $RHEL_ISO ]] && { echo "Does not exist: $RHEL_ISO"; exit 9999; }
[[ ! -x "$(command -v VBoxManage)" ]] && { echo "Script requires VirtualBox CLI"; exit 9999; }
[[ ! -x "$(command -v vagrant)" ]] && { echo "Script requires Vagrant"; exit 9999; }

# clean
[[ -e $BUILD_DIR/.metadata ]] && VBoxManage unregistervm $(head -1 $BUILD_DIR/.metadata) --delete
[[ -e $BUILD_DIR ]] && rm -rf $BUILD_DIR

# setup
mkdir -p $BUILD_DIR
echo $VM > $BUILD_DIR/.metadata

# build kickstart disk image
mkdir $BUILD_DIR/oemdrv
cp ks.cfg $BUILD_DIR/oemdrv/ks.cfg
hdiutil create -format UDTO -fs MS-DOS -volname OEMDRV -srcfolder $BUILD_DIR/oemdrv $BUILD_DIR/oemdrv.cdr

# build VM
VBoxManage createvm -name $VM --ostype RedHat_64 --default --register --basefolder $BUILD_DIR
VBoxManage modifyvm $VM --cpus 2 --memory 2048
VBoxManage createhd --filename $BUILD_DIR/$VM/$VM.vdi --size 20480
VBoxManage storageattach $VM --storagectl "SATA" --port 0 --device 0 --type hdd --medium $BUILD_DIR/$VM/$VM.vdi
VBoxManage convertdd $BUILD_DIR/oemdrv.cdr $BUILD_DIR/$VM/oemdrv.vdi
VBoxManage storageattach $VM --storagectl "SATA" --port 1 --device 0 --type hdd --medium $BUILD_DIR/$VM/oemdrv.vdi
VBoxManage storageattach $VM --storagectl "IDE" --port 0 --device 0 --type dvddrive --medium $RHEL_ISO
VBoxManage storageattach $VM --storagectl "IDE" --port 0 --device 1 --type dvddrive --medium emptydrive # https://www.virtualbox.org/ticket/13040
VBoxManage storageattach $VM --storagectl "IDE" --port 0 --device 1 --type dvddrive --medium additions

# boot VM and wait for shutdown after kickstart install
VBoxManage startvm $VM --type headless
until $(VBoxManage showvminfo --machinereadable $VM | grep -q ^VMState=.poweroff.)
do
  echo -n .
  sleep 10
done
echo "Done"

# remove extra media from VM
VBoxManage storageattach $VM --storagectl "IDE" --port 0 --device 1 --medium none
VBoxManage storageattach $VM --storagectl "SATA" --port 1 --device 0 --medium none
VBoxManage closemedium disk $BUILD_DIR/$VM/oemdrv.vdi --delete

# package VM as vagrant box
[[ ! -d $RELEASE_DIR ]] && mkdir -p $RELEASE_DIR
vagrant package --base $VM --output $RELEASE_DIR/$VM.box
echo "SHA1: $( shasum $RELEASE_DIR/$VM.box )"
