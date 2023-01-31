#!/bin/bash
# chmod u+x uninstall.sh
# git add --chmod=+x install.sh

# DEFINES - versions
kubernetesVer=1.24.0
containerdVer=1.6.4
runcVer=1.1.1
cniPluginVer=1.1.1
#calicoVer=3.18
flannelVer=0.20.2
# SERVERS
serverNumber=0
serverName=("server1" "server2" "server3")
serverUser=("root" "root" "root")
serversshIP=("123.456.78.910" "123.456.78.910" "123.456.78.910")
serverlocalIP=("192.168.0.215" "192.168.0.225" "192.168.0.226")
servernetworkIP="192.168.0.0/24"
servercniIP="10.244.0.0/16"
serverPort=("22" "22001" "22002")
# VARIABLE DEFINES
DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
logFile="${DIR}/install.log"
#logFile="/dev/null"

#echo "Input root user password of server machine"
#read userPassword

echo "[TASK 1] Join node to Kubernetes Cluster"
#apt install -qq -y sshpass >>${logFile} 2>&1
#sshpass -p "${userPassword}" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -P ${sshPort} root@server-1.local:/${HOME}/k8s/joincluster.sh /${HOME}/k8s/joincluster.sh >>${logFile}
#scp -P ${sshPort} root@${publicIP}:/${DIR}/joincluster.sh ${DIR}/joincluster.sh
/bin/bash /${DIR}/joincluster.sh >>${logFile} 2>&1

echo "[TASK 2] Setup kubeconfig"
#mkdir -p ${HOME}/.kube
#sshpass -p "${userPassword}" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -P ${sshPort} root@server-1.local:/etc/kubernetes/admin.conf /${HOME}/.kube/config 2>>${logFile}
# todo update incase server is 127.0.0.1 with server ip
#sed -i 's/^.*server: .*/server:/' /etc/ssh/sshd_config
sudo chown $(id -u):$(id -g) ${HOME}/.kube/config

echo "[TASK 3] Add kubeconfig env"
#export KUBECONFIG=${HOME}/.kube/config
cat >>/etc/environment<<EOF
KUBECONFIG=${HOME}/.kube/config
EOF

echo "COMPLETE!"
