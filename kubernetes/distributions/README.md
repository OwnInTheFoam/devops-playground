List of kubernetes tutorials, guides and exercises.

## List of completed tutorials:

- [Kubernetes v1.24.0](https://github.com/drdre-08/tutorials/tree/master/kubernetes/k8s)
- [K3d v5.4.6](https://github.com/drdre-08/tutorials/tree/master/kubernetes/k3d)

## Notes:

### On kubeadm init failure
```
kubeadm reset
kubeadm init
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

