#!/bin/bash
# Please run with sudo permissions sudo /bin/bash/ Install.sh
# chmod u+x install.sh
# git add --chmod=+x install.sh

# requirements
# - ssh with key pair access to all servers

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
logFile="${DIR}/Install.log"
touch ${logFile}
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
sudo sed -i '/swap/d' /etc/fstab
sudo swapoff -a

echo "[TASK 2] Enabled firewall and allow lan network and ssh"
sudo ufw allow from ${servernetworkIP} >>${logFile} 2>&1
sudo ufw allow from ${servercniIP} >>${logFile} 2>&1
sudo ufw allow ${serverPort[serverNumber]} >>${logFile} 2>&1
sudo ufw --force enable >>${logFile} 2>&1
sudo systemctl enable --now ufw >>${logFile} 2>&1

# modprobe adds or removes a loadable kernel module to the Linux kernel
echo "[TASK 3] Enable and Load Kernel modules"
echo 'overlay' | sudo tee -a /etc/modules-load.d/containerd.conf >>${logFile} 2>&1
echo 'br_netfilter' | sudo tee -a /etc/modules-load.d/containerd.conf >>${logFile} 2>&1
sudo modprobe overlay
sudo modprobe br_netfilter

echo "[TASK 4] Add Kernel settings"
echo 'net.bridge.bridge-nf-call-ip6tables = 1' | sudo tee -a /etc/sysctl.d/kubernetes.conf >>${logFile} 2>&1
echo 'net.bridge.bridge-nf-call-iptables  = 1' | sudo tee -a /etc/sysctl.d/kubernetes.conf >>${logFile} 2>&1
echo 'net.ipv4.ip_forward                 = 1' | sudo tee -a /etc/sysctl.d/kubernetes.conf >>${logFile} 2>&1
sudo sysctl --system >>${logFile} 2>&1

echo "[TASK 5] Install containerd runtime"
sudo apt update -qq >>${logFile} 2>&1
sudo apt install -qq -y apt-transport-https >>${logFile} 2>&1
wget --no-verbose https://github.com/containerd/containerd/releases/download/v${containerdVer}/containerd-${containerdVer}-linux-$(dpkg --print-architecture).tar.gz >>${logFile} 2>&1
sudo tar Cxzvf /usr/local containerd-${containerdVer}-linux-$(dpkg --print-architecture).tar.gz >>${logFile} 2>&1
wget --no-verbose https://github.com/opencontainers/runc/releases/download/v${runcVer}/runc.$(dpkg --print-architecture) >>${logFile} 2>&1
sudo install -m 755 runc.$(dpkg --print-architecture) /usr/local/sbin/runc >>${logFile} 2>&1
wget --no-verbose https://github.com/containernetworking/plugins/releases/download/v${cniPluginVer}/cni-plugins-linux-$(dpkg --print-architecture)-v${cniPluginVer}.tgz >>${logFile} 2>&1
sudo mkdir -p /opt/cni/bin
sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-$(dpkg --print-architecture)-v${cniPluginVer}.tgz >>${logFile} 2>&1
sudo mkdir -p /etc/containerd
sudo touch /etc/containerd/config.toml
echo "Changing config.toml ownership from: " >>${logFile} 2>&1
ls -l /etc/containerd/config.toml >>${logFile} 2>&1
sudo chown ${serverName[serverNumber]} /etc/containerd/config.toml >>${logFile} 2>&1
echo "Changed config.toml ownership to: " >>${logFile} 2>&1
ls -l /etc/containerd/config.toml >>${logFile} 2>&1
sudo containerd config default > /etc/containerd/config.toml >>${logFile} 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
echo "Changed config.toml ownership back to: " >>${logFile} 2>&1
sudo chown root /etc/containerd/config.toml >>${logFile} 2>&1
ls -l /etc/containerd/config.toml >>${logFile} 2>&1
sudo curl -L https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o /etc/systemd/system/containerd.service >>${logFile} 2>&1
sudo systemctl restart containerd
sudo systemctl daemon-reload
sudo systemctl enable containerd >>${logFile} 2>&1

echo "[TASK 6] Add apt repo for kubernetes"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - >>${logFile} 2>&1
sudo apt-add-repository -y "deb http://apt.kubernetes.io/ kubernetes-xenial main" >>${logFile} 2>&1

echo "[TASK 7] Install Kubernetes components (kubeadm, kubelet and kubectl)"
sudo apt install -qq -y kubeadm=${kubernetesVer}-00 kubelet=${kubernetesVer}-00 kubectl=${kubernetesVer}-00 >>${logFile} 2>&1

echo "[TASK 8] Enable kubectl completion bash"
cat>>${HOME}/.bashrc<<EOF
source <(kubectl completion bash)
export EDITOR="nano"
export KUBE_EDITOR="nano"
EOF

#echo "[TASK - DISABLED] Enable ssh password authentication"
#sed -i 's/^.*PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
#sed -i 's/^.*PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
#systemctl reload sshd

#echo "[TASK - DISABLED] Set root password"
#echo -e "kubeadmin\nkubeadmin" | passwd root >>${logFile} 2>&1
#echo "export TERM=xterm" >> /etc/bash.bashrc

echo "[TASK 9] Update /etc/hosts file"
echo "${serverlocalIP[0]}   ${serverName[0]}.local   ${serverName[0]}   cluster-endpoint" | sudo tee -a /etc/hosts >>${logFile} 2>&1
for ((i = 1; i < ${#serverName[@]}; ++i)); do
  echo "${serverlocalIP[$i]}   ${serverName[$i]}.local   ${serverName[$i]}" | sudo tee -a /etc/hosts >>${logFile} 2>&1
done

echo "complete install.sh" >>${logFile} 2>&1
echo "COMPLETE!"
