#!/bin/bash
# chmod u+x uninstall.sh

# DEFINES - versions
kubernetesVer=1.26.7
containerdVer=1.6.21
runcVer=1.1.7
cniPluginVer=1.3.0
#calicoVer=3.18
flannelVer=0.21.5
# SERVERS
serverNumber=0
serverName=("server4" "server1" "server2" "server3")
serverUser=("server4" "server1" "server2" "server3")
serversshIP=("123.456.78.910" "123.456.78.910" "123.456.78.910" "123.456.78.910")
serverlocalIP=("192.168.0.227" "192.168.0.215" "192.168.0.225" "192.168.0.226")
servernetworkIP="192.168.0.0/24"
servercniIP="10.244.0.0/16"
serverPort=("22004" "22001" "22002" "22003")
# VARIABLE DEFINES
DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${DIR}
logFile="${DIR}/uninstall.log"
touch ${logFile}
#logFile="/dev/null"

echo "[TASK] Remove from /etc/hosts file"
sudo sed -i '/192.168.0.215/d' /etc/hosts
sudo sed -i '/192.168.0.225/d' /etc/hosts
sudo sed -i '/192.168.0.226/d' /etc/hosts
sudo sed -i '/192.168.0.227/d' /etc/hosts

echo "[TASK] Uninstall Kubernetes components (kubeadm, kubelet and kubectl)"
sudo kubeadm reset --force >>${logFile} 2>&1
sudo apt -qq -y purge kubeadm kubectl kubelet kubernetes-cni kube* >>${logFile} 2>&1
sudo apt -qq -y autoremove >>${logFile} 2>&1
sudo rm -rf /etc/cni /etc/kubernetes /var/lib/dockershim /var/lib/etcd /var/lib/kubelet /var/run/kubernetes /usr/local/bin/kube*
sudo rm -rf ~/.kube /root/.kube /bin/kubeadm /bin/kubectl /bin/kubelet
#iptables -F && iptables -X
#iptables -t nat -F && iptables -t nat -X
#iptables -t raw -F && iptables -t raw -X
#iptables -t mangle -F && iptables -t mangle -X

echo "[TASK] Uninstall containerd runtime"
sudo systemctl stop containerd >>${logFile} 2>&1
sudo systemctl disable containerd >>${logFile} 2>&1
sudo rm -rf /etc/systemd/system/containerd.service /usr/lib/systemd/system/containerd.service
sudo systemctl daemon-reload
sudo apt purge -qq -y --auto-remove apt-transport-https >>${logFile} 2>&1
sudo apt purge -qq -y --auto-remove containerd >>${logFile} 2>&1
sudo rm -rf /usr/local/bin/containerd* /usr/local/bin/ctr /bin/containerd* /bin/ctr /opt/containerd /opt/cni /usr/local/sbin/runc /etc/containerd

echo "[TASK] Remove cni network link"
sudo ip link delete flannel.1 >>${logFile} 2>&1

echo "[TASK] Remove Kernel settings"
sudo sed -i '/net.bridge.bridge-nf-call-ip6tables/d' /etc/sysctl.d/kubernetes.conf
sudo sed -i '/net.bridge.bridge-nf-call-iptables/d' /etc/sysctl.d/kubernetes.conf
sudo sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.d/kubernetes.conf
sudo sysctl --system >>${logFile} 2>&1

echo "[TASK] Remove container.d config and kernel modules"
sudo sed -i '/overlay/d' /etc/modules-load.d/containerd.conf
sudo sed -i '/br_netfilter/d' /etc/modules-load.d/containerd.conf
sudo modprobe -r overlay
sudo modprobe -r br_netfilter

echo "[TASK] Delete alias"
sed -i '/kubectl/d' ~/.bash_aliases
sed -i '/flux/d' ~/.bash_aliases

echo "[TASK] Delete bash completion and env"
sed -i '/kubectl/d' ~/.bashrc
sudo sed -i '/KUBE/d' /etc/environment

echo "[TASK] Delete temporary files from ${DIR}"
rm -rf ${DIR}/containerd-${containerdVer}-linux-$(dpkg --print-architecture).tar.gz
rm -rf ${DIR}/runc.$(dpkg --print-architecture)
rm -rf ${DIR}/cni-plugins-linux-$(dpkg --print-architecture)-v${cniPluginVer}.tgz
rm -rf ${DIR}/kubeinit.log
rm -rf ${DIR}/kube-flannel.yml
rm -rf ${DIR}/joincluster.sh
rm -rf ${DIR}/setup.log
rm -rf ${DIR}/Install.log
rm -rf ${DIR}/InstallServer.log
rm -rf ${DIR}/InstallAgent.log
rm -rf ${HOME}/k8s
rm -rf ${HOME}/.kube

echo "COMPLETE!"
