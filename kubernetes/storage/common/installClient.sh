#!/bin/bash
# chmod u+x installClient.sh

# Run on worker/client nodes before installing a storage solution.

logFile="${HOME}/storage/installClient.log"
#logFile="/dev/null"
networkIPAddress=192.168.0.0

mkdir -p /${HOME}/storage

echo "[TASK] Firewall allow local IP for storage services"
ufw allow from ${networkIPAddress}/24 >>${logFile} 2>&1

echo "[TASK] Install generic storage client dependencies"
apt update >>${logFile} 2>&1
apt -y install nfs-common open-iscsi cryptsetup dmsetup >>${logFile} 2>&1

echo "[TASK] Enable storage services"
systemctl enable --now iscsid >>${logFile} 2>&1

echo "[TASK] Load storage kernel modules"
modprobe nfs >>${logFile} 2>&1
modprobe dm_crypt >>${logFile} 2>&1

echo "COMPLETE"
