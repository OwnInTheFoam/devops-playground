#!/bin/bash
# chmod u+x install.sh
# git add --chmod=+x install.sh

# requirements
# - ssh with key pair access to all servers

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

# commands ending in >>${logFile} 2>&1
# >>${logFile} redirects standard output to /dev/null, which discards it
# 2>&1 redirects standard error (2) to standard output (1), which discards it due to above

REQUIRED_PKG=("curl" "sed" "wget" "tar")
for ((i = 0; i < ${#REQUIRED_PKG[@]}; ++i)); do
  PKG_OK=$(dpkg-query -W --showformat='${Status}\n' ${REQUIRED_PKG[$i]}|grep "install ok installed")
  echo "Checking for ${REQUIRED_PKG[$i]}: $PKG_OK"
  if [ "" = "$PKG_OK" ]; then
    echo "No ${REQUIRED_PKG[$i]}. Setting up ${REQUIRED_PKG[$i]}."
    sudo apt update
    sudo apt -qq -y install ${REQUIRED_PKG[$i]}
  fi
done

echo "[TASK 1] Disable and turn off SWAP"
sed -i '/swap/d' /etc/fstab
swapoff -a

echo "[TASK 2] Enabled firewall and allow lan network and ssh"
ufw allow from ${servernetworkIP} >>${logFile} 2>&1
ufw allow from ${servercniIP} >>${logFile} 2>&1
ufw allow ${serverPort[serverNumber]} >>${logFile} 2>&1
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

echo "[TASK] Enable kubectl completion bash"
cat>>${HOME}/.bashrc<<EOF
source <(kubectl completion bash)
EOF

#echo "[TASK 8] Enable ssh password authentication"
#sed -i 's/^.*PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
#sed -i 's/^.*PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
#systemctl reload sshd

#echo "[TASK 9 - DISABLED] Set root password"
#echo -e "kubeadmin\nkubeadmin" | passwd root >>${logFile} 2>&1
#echo "export TERM=xterm" >> /etc/bash.bashrc

echo "[TASK 10] Update /etc/hosts file"
for i in ${!serverName[@]}; do
cat >>/etc/hosts<<EOF
${serverlocalIP[$i]}   ${serverName[$i]}.local   ${serverName[$i]}
EOF
done

echo "complete install.sh" >>${logFile} 2>&1
echo "COMPLETE!"
