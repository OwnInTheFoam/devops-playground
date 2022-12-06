#!/bin/bash

echo "Input root user password of server machine"

read userPassword

echo "[TASK 1] Join node to Kubernetes Cluster"
apt install -qq -y sshpass >/dev/null 2>&1
sshpass -p "${userPassword}" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no server-1.local:/joincluster.sh /joincluster.sh 2>/dev/null
bash /joincluster.sh >/dev/null 2>&1

echo "[TASK 2] Setup kubeconfig"
mkdir -p $HOME/.kube
sshpass -p "${userPassword}" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no server-1.local:/etc/kubernetes/admin.conf /root/.kube/config 2>/dev/null
# todo update incase server is 127.0.0.1 with server ip
#sed -i 's/^.*server: .*/server:/' /etc/ssh/sshd_config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "[TASK 3] Export kubeconfig env"
export KUBECONFIG=$HOME/.kube/config
