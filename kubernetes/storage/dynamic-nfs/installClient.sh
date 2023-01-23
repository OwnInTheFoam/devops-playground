#!/bin/bash
# chmod u+x install.sh

# NOTE: Run this install on only one master / server node on machine. All others run install

# REQUIREMENTS
# - helm (curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && chmod 700 get_helm.sh && ./get_helm.sh)
# - yq (wget https://github.com/mikefarah/yq/releases/download/v4.30.6/yq_linux_amd64.tar.gz -O - | tar xz && mv yq_linux_amd64 /usr/bin/yq)

# DEFINES - versions
nfsVer=4.0.17
# VARIABLE DEFINES
logFile="${HOME}/nfs/install.log"
#logFile="/dev/null"
networkIPAddress=192.168.0.0
hostIPAddress=192.168.0.215

mkdir -p /${HOME}/nfs

echo "[TASK] Firewall allow local IP for nfs"
ufw allow from ${networkIPAddress}/24 >>${logFile} 2>&1

echo "[TASK] Install NFS server on Client"
apt update >>${logFile} 2>&1
apt -y install nfs-common >>${logFile} 2>&1

echo "[TASK] Create mount"
mkdir -p /mnt
mount ${hostIPAddress}:/srv/nfs/kubedata /mnt
umount /mnt

echo "[TASK] Mount nfs on boot"
# test multiple on following isnt added!
cat >>/etc/fstab<<EOF
${hostIPAddress}:/srv/nfs/kubedata   /mnt   nfs  auto,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0
EOF

echo "COMPLETE"
