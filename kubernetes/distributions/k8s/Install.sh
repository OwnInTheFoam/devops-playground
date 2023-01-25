#!/bin/bash
# chmod u+x uninstall.sh

# DEFINES - versions
kubernetesVer=1.24.0
containerdVer=1.6.4
runcVer=1.1.1
cniPluginVer=1.1.1
calicoVer=3.18
# VARIABLE DEFINES
sshPort=22
DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
logFile="${DIR}/install.log"
#logFile="/dev/null"

# commands ending in >>${logFile} 2>&1
# >>${logFile} redirects standard output to /dev/null, which discards it
# 2>&1 redirects standard error (2) to standard output (1), which discards it due to above

echo "[TASK 1] Disable and turn off SWAP"
sed -i '/swap/d' /etc/fstab
swapoff -a

echo "[TASK 2] Enabled firewall and allow lan network and ssh"
ufw allow from 192.168.0.0/24 >>${logFile} 2>&1
ufw allow ${sshPort} >>${logFile} 2>&1
ufw --force enable >>${logFile} 2>&1
systemctl enable --now ufw >>${logFile} 2>&1

# modprobe adds or removes a loadable kernel module to the Linux kernel
echo "[TASK 3] Enable and Load Kernel modules"
cat >>/etc/modules-load.d/containerd.conf<<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

echo "[TASK 4] Add Kernel settings"
cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system >>${logFile} 2>&1

echo "[TASK 5] Install containerd runtime"
apt update -qq >>${logFile} 2>&1
apt install -qq -y apt-transport-https >>${logFile} 2>&1
wget --no-verbose https://github.com/containerd/containerd/releases/download/v${containerdVer}/containerd-${containerdVer}-linux-$(dpkg --print-architecture).tar.gz >>${logFile} 2>&1
tar Cxzvf /usr/local containerd-${containerdVer}-linux-$(dpkg --print-architecture).tar.gz >>${logFile} 2>&1
wget --no-verbose https://github.com/opencontainers/runc/releases/download/v${runcVer}/runc.$(dpkg --print-architecture) >>${logFile} 2>&1
install -m 755 runc.$(dpkg --print-architecture) /usr/local/sbin/runc >>${logFile} 2>&1
wget --no-verbose https://github.com/containernetworking/plugins/releases/download/v${cniPluginVer}/cni-plugins-linux-$(dpkg --print-architecture)-v${cniPluginVer}.tgz >>${logFile} 2>&1
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin cni-plugins-linux-$(dpkg --print-architecture)-v${cniPluginVer}.tgz >>${logFile} 2>&1
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
curl -L https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o /etc/systemd/system/containerd.service >>${logFile} 2>&1
systemctl restart containerd
systemctl daemon-reload
systemctl enable containerd >>${logFile} 2>&1

echo "[TASK 6] Add apt repo for kubernetes"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - >>${logFile} 2>&1
apt-add-repository -y "deb http://apt.kubernetes.io/ kubernetes-xenial main" >>${logFile} 2>&1

echo "[TASK 7] Install Kubernetes components (kubeadm, kubelet and kubectl)"
apt install -qq -y kubeadm=${kubernetesVer}-00 kubelet=${kubernetesVer}-00 kubectl=${kubernetesVer}-00 >>${logFile} 2>&1

#echo "[TASK 8] Enable ssh password authentication"
#sed -i 's/^.*PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
#sed -i 's/^.*PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
#systemctl reload sshd

#echo "[TASK 9 - DISABLED] Set root password"
#echo -e "kubeadmin\nkubeadmin" | passwd root >>${logFile} 2>&1
#echo "export TERM=xterm" >> /etc/bash.bashrc

echo "[TASK 10] Update /etc/hosts file"
cat >>/etc/hosts<<EOF
192.168.0.215   server-1.local   server-1
192.168.0.225   agent-1.local    agent-1
192.168.0.226   agent-2.local    agent-2
EOF

echo "COMPLETE!"
