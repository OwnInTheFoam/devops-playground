#!/bin/bash
# chmod u+x uninstall.sh

# VERSION DEFINES
kubernetesVer=1.24.0
containerdVer=1.6.4
runcVer=1.1.1
cniPluginVer=1.1.1
calicoVer=3.18
# VARIABLE DEFINES
sshPort=22
publicIP=123.456.78.90
DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
logFile="${DIR}/install.log"
#logFile=">${logFile}"

echo "Input root user password of server machine"

read userPassword

echo "[TASK 1] Join node to Kubernetes Cluster"
apt install -qq -y sshpass >>${logFile} 2>&1
#sshpass -p "${userPassword}" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -P ${sshPort} root@server-1.local:/${HOME}/k8s/joincluster.sh /${HOME}/k8s/joincluster.sh >>${logFile}
scp -P ${sshPort} root@${publicIP}:/${DIR}/joincluster.sh ${DIR}/joincluster.sh
bash /${DIR}/joincluster.sh >>${logFile} 2>&1

echo "[TASK 2] Setup kubeconfig"
mkdir -p ${HOME}/.kube
sshpass -p "${userPassword}" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -P ${sshPort} root@server-1.local:/etc/kubernetes/admin.conf /${HOME}/.kube/config 2>>${logFile}
# todo update incase server is 127.0.0.1 with server ip
#sed -i 's/^.*server: .*/server:/' /etc/ssh/sshd_config
sudo chown $(id -u):$(id -g) ${HOME}/.kube/config

echo "[TASK 3] Export kubeconfig env"
export KUBECONFIG=${HOME}/.kube/config

echo "COMPLETE!"
