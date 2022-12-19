#!/bin/bash

# VERSION DEFINES
kubernetesVer=1.24.0
containerdVer=1.6.4
runcVer=1.1.1
cniPluginVer=1.1.1
calicoVer=3.18

echo "[TASK 1] Pull required containers"
kubeadm config images pull --kubernetes-version=${kubernetesVer} >/dev/null 2>&1

echo "[TASK 2] Initialize Kubernetes Cluster"
kubeadm init --kubernetes-version=${kubernetesVer} --apiserver-advertise-address=192.168.0.215 --pod-network-cidr=192.168.0.0/16 >> /root/kubeinit.log 2>/dev/null

echo "[TASK 3] Deploy Calico network"
kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f https://docs.projectcalico.org/v${calicoVer}/manifests/calico.yaml >/dev/null 2>&1

echo "[TASK 4] Generate and save cluster join command to /joincluster.sh"
kubeadm token create --print-join-command > /joincluster.sh 2>/dev/null

echo "[TASK 5] Setup kubeconfig"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "[TASK 6] Export kubeconfig env"
export KUBECONFIG=/etc/kubernetes/admin.conf
