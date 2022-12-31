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
logFile="${HOME}/k8s/install.log"
#logFile=">${logFile}"

echo "[TASK 1] Pull required containers"
kubeadm config images pull --kubernetes-version=${kubernetesVer} >>${logFile} 2>&1

echo "[TASK 2] Initialize Kubernetes Cluster"
kubeadm init --kubernetes-version=${kubernetesVer} --apiserver-advertise-address=192.168.0.215 --pod-network-cidr=192.168.0.0/16 >> /${HOME}/k8s/kubeinit.log 2>>${logFile}

echo "[TASK 3] Deploy Calico network"
kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f https://docs.projectcalico.org/v${calicoVer}/manifests/calico.yaml >>${logFile} 2>&1

echo "[TASK 4] Generate and save cluster join command to /joincluster.sh"
kubeadm token create --print-join-command > /${HOME}/k8s/joincluster.sh 2>>${logFile}

echo "[TASK 5] Setup kubeconfig"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "[TASK 6] Export kubeconfig env"
export KUBECONFIG=/etc/kubernetes/admin.conf

echo "COMPLETE!"
