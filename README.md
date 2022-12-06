This repository contains list of public tutorials, guides and exercises.
Each shall be own it's own branch.

## List of completed tutorials:

### Tutorial One
Kubernetes v1.24.0
on Ubuntu 20.04
by Just me and OpenSource

## Notes:

### On kubeadm init failure
```
kubeadm reset
kubeadm init
```

### Uninstall kubernetes

iptables -F flushes the rules of the chain
iptables -X deletes a chain
ufw uses iptables so altering iptables may effect your ufw rules
```
kubeadm reset
sudo apt-get purge kubeadm kubectl kubelet kubernetes-cni kube*
sudo apt-get autoremove
sudo rm -rf /etc/cni /etc/kubernetes /var/lib/dockershim /var/lib/etcd /var/lib/kubelet /var/run/kubernetes ~/.kube

iptables -F && iptables -X
iptables -t nat -F && iptables -t nat -X
iptables -t raw -F && iptables -t raw -X
iptables -t mangle -F && iptables -t mangle -X
```

### Uninstall Docker
Docker was removed in kubernetes version 1.24.0. If docker needs to uninstalled and purged then the following can do so:
```
dpkg -l | grep -i docker
sudo apt-get purge -y docker-engine docker docker.io docker-ce docker-ce-cli docker-compose-plugin
sudo apt-get autoremove -y --purge docker-engine docker docker.io docker-ce docker-compose-plugin
sudo rm -rf /var/lib/docker /etc/docker
sudo rm /etc/apparmor.d/docker
sudo groupdel docker
sudo rm -rf /var/run/docker.sock
```

Alternative to install specific docker version
```
apt-cache madison docker-ce
export VERSION=19.03.10 && curl -sSL get.docker.com | sh
```

