#!/bin/bash
# chmod u+x uninstall.sh

# REQUIREMENTS
# - helm (curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && chmod 700 get_helm.sh && ./get_helm.sh)
# - yq (wget https://github.com/mikefarah/yq/releases/download/v4.30.6/yq_linux_amd64.tar.gz -O - | tar xz && mv yq_linux_amd64 /usr/bin/yq)

# DEFINES - versions
nfsVer=4.0.17
# VARIABLE DEFINES
logFile="${HOME}/nfs/uninstall.log"
#logFile="/dev/null"
networkIPAddress=192.168.0.0
hostIPAddress=192.168.0.215

echo "[TASK] Remove fstab mount directory"
sed -i '/\/srv\/nfs\/kubedata/d' /etc/fstab >>${logFile} 2>&1

echo "[TASK] Unmount directory"
umount /mnt >>${logFile} 2>&1
rm -r /mnt >>${logFile} 2>&1

echo "[TASK] Uninstall nfs-common"
apt purge -qq -y --auto-remove nfs-common >>${logFile} 2>&1

echo "[TASK] Delete firewall allow all from local ip addresses"
ufw delete allow from ${networkIPAddress}/24 >>${logFile} 2>&1

echo "COMPLETE"
