#!/bin/bash
# chmod u+x installHost.sh

# Run on storage host/server nodes before installing a storage solution.

logFile="${HOME}/storage/installHost.log"
#logFile="/dev/null"
networkIPAddress=192.168.0.0

mkdir -p /${HOME}/storage

echo "[TASK] Firewall allow local IP for storage services"
ufw allow from ${networkIPAddress}/24 >>${logFile} 2>&1

echo "[TASK] Install generic storage host dependencies"
apt update >>${logFile} 2>&1
apt -y install nfs-kernel-server nfs-common open-iscsi cryptsetup dmsetup >>${logFile} 2>&1

echo "[TASK] Enable storage services"
systemctl enable --now iscsid >>${logFile} 2>&1
systemctl enable --now nfs-kernel-server >>${logFile} 2>&1

echo "[TASK] Load storage kernel modules"
modprobe nfs >>${logFile} 2>&1
modprobe dm_crypt >>${logFile} 2>&1

echo "COMPLETE"
