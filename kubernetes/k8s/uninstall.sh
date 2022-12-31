#!/bin/bash
# chmod u+x uninstall.sh

# DEFINES
logFile="${HOME}/k8s/uninstall.log"
#logFile="/dev/null"

echo "[TASK] Remove from /etc/hosts file"
sed -i '/192.168.0.215/d' /etc/hosts
sed -i '/192.168.0.225/d' /etc/hosts
sed -i '/192.168.0.226/d' /etc/hosts

echo "[TASK] Uninstall Kubernetes components (kubeadm, kubelet and kubectl)"
kubeadm reset --force >>${logFile} 2>&1
apt-get purge kubeadm kubectl kubelet kubernetes-cni kube* >>${logFile} 2>&1
apt-get autoremove >>${logFile} 2>&1
rm -rf /etc/cni /etc/kubernetes /var/lib/dockershim /var/lib/etcd /var/lib/kubelet /var/run/kubernetes /usr/local/bin/kube* ~/.kube
iptables -F && iptables -X
iptables -t nat -F && iptables -t nat -X
iptables -t raw -F && iptables -t raw -X
iptables -t mangle -F && iptables -t mangle -X

echo "[TASK] Uninstall containerd runtime"
systemctl stop containerd >>${logFile} 2>&1
systemctl disable containerd >>${logFile} 2>&1
rm -rf /etc/systemd/system/containerd.service /usr/lib/systemd/system/containerd.service
systemctl daemon-reload
apt purge -qq -y --auto-remove apt-transport-https >>${logFile} 2>&1
apt purge -qq -y --auto-remove containerd >>${logFile} 2>&1
rm -rf /usr/local/bin/containerd* /usr/local/bin/ctr /bin/containerd* /bin/ctr /opt/containerd /opt/cni /usr/local/sbin/runc /etc/containerd

echo "[TASK] Remove Kernel settings"
sed -i '/net.bridge.bridge-nf-call-ip6tables/d' /etc/sysctl.d/kubernetes.conf
sed -i '/net.bridge.bridge-nf-call-iptables/d' /etc/sysctl.d/kubernetes.conf
sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.d/kubernetes.conf
sysctl --system >>${logFile} 2>&1

echo "[TASK] Remove container.d config and kernel modules"
sed -i '/overlay/d' /etc/modules-load.d/containerd.conf
sed -i '/br_netfilter/d' /etc/modules-load.d/containerd.conf
modprobe -r overlay
modprobe -r br_netfilter

echo "COMPLETE!"
