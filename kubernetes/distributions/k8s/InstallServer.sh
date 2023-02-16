#!/bin/bash
# chmod u+x uninstall.sh
# git add --chmod=+x install.sh

# DEFINES - versions
kubernetesVer=1.26.1
containerdVer=1.6.18
runcVer=1.1.4
cniPluginVer=1.2.0
#calicoVer=3.18
flannelVer=0.21.2
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

echo "[TASK 1] Pull required containers"
kubeadm config images pull --kubernetes-version=${kubernetesVer} >>${logFile} 2>&1

echo "[TASK 2] Initialize Kubernetes Cluster"
kubeadm init --kubernetes-version=${kubernetesVer} --apiserver-advertise-address=${serverlocalIP[0]} --pod-network-cidr=${servercniIP} >> /${DIR}/kubeinit.log 2>>${logFile}

echo "[TASK 3] Deploy CNI plugin (flannel/calico) network"
#kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f https://docs.projectcalico.org/v${calicoVer}/manifests/calico.yaml >>${logFile} 2>&1
wget --no-verbose https://raw.githubusercontent.com/flannel-io/flannel/v${flannelVer}/Documentation/kube-flannel.yml >>${logFile} 2>&1
#sed -i 's/"Network":.*/"Network": "${servercniIP}"/' kube-flannel.yml
kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f kube-flannel.yml >>${logFile} 2>&1

echo "[TASK 4] Generate and save cluster join command to /joincluster.sh"
kubeadm token create --print-join-command > /${DIR}/joincluster.sh 2>>${logFile}

echo "[TASK 5] Setup kubeconfig"
mkdir -p ${HOME}/.kube
sudo cp -i /etc/kubernetes/admin.conf ${HOME}/.kube/config
sudo chown $(id -u):$(id -g) ${HOME}/.kube/config

echo "[TASK 6] Export kubeconfig env"
#export KUBECONFIG=/etc/kubernetes/admin.conf
cat >>/etc/environment<<EOF
KUBECONFIG=/etc/kubernetes/admin.conf
EOF

echo "COMPLETE!"

