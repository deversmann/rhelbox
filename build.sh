#!/bin/bash

VM="rhelbox-$(date +%s)"
VBoxManage createvm -name $VM --ostype RedHat_64 --default --register --basefolder "$(realpath $(dirname ${BASH_SOURCE:-0}))"
VBoxManage modifyvm $VM --cpus 2 --memory 2048
VBoxManage createhd --filename $VM/$VM.vdi --size 20480
VBoxManage storageattach $VM --storagectl "SATA" --port 0 --device 0 --type hdd --medium $VM/$VM.vdi
VBoxManage clonemedium disk rhelbox_ks.vdi $VM/rhelbox_ks.vdi
VBoxManage storageattach $VM --storagectl "SATA" --port 1 --device 0 --type hdd --medium $VM/rhelbox_ks.vdi
VBoxManage storageattach $VM --storagectl "IDE" --port 0 --device 0 --type dvddrive --medium /Users/deversma/Downloads/isos/rhel-8.3-x86_64-dvd.iso
VBoxManage storageattach $VM --storagectl "IDE" --port 0 --device 1 --type dvddrive --medium /Applications/VirtualBox.app/Contents/MacOS/VBoxGuestAdditions.iso
VBoxManage startvm $VM --type headless
until $(VBoxManage showvminfo --machinereadable $VM | grep -q ^VMState=.poweroff.)
do
  echo -n .
  sleep 10
done
echo "Done"
VBoxManage storageattach $VM --storagectl "IDE" --port 0 --device 1 --medium none
VBoxManage storageattach $VM --storagectl "SATA" --port 1 --device 0 --medium none
VBoxManage closemedium disk $VM/rhelbox_ks.vdi --delete
