# Kubernetes
[Github CHANGELOG](https://github.com/kubernetes/kubernetes/tree/master/CHANGELOG)

## Helpful resources
Kubernetes v1.24.0 by [Just me and OpenSource](https://github.com/justmeandopensource/kubernetes/tree/master/vagrant-provisioning)

### Steps

You'll need to know which kubernetes version supports which version containerd version. Use the [changelog](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.24.md#changed-8) to determine the dependency versions.

For this tutorial we will use:
- Kubernetes: 1.24.0
- containerd: 1.6.4
- runc: 1.1.1
- cni plugin: 1.1.1
- calico: 3.18.0

Nodes to be setup:
- server1: 192.168.0.215
- server2: 192.168.0.225
- server3: 192.168.0.226

#### On all server and agent nodes
1. **Ensure root user is created and logged in**

    To log into root:
    ```
    sudo su -
    ```
    If no root user available then create root with password:
    ```
    sudo passwd root
    sudo passwd -u root 
    ```

2. **Ensure firewall is disabled**

    Using systemctl:
    ```
    systemctl disable --now ufw
    ```
    Using ufw:
    ```
    ufw disable
    ```
    Check the status:
    ```
    ufw status
    ```

3. **Disable swap**

    To check for swaps:
    ```
    swapon -s
    ```
    To disable swaps:
    ```
    swapoff -a
    ```
    Swaps listed on fstab will re-enable on reboot:
    ```
    grep swap /etc/fstab
    ```
    To have swaps not enable after reboot:
    ```
    sed -i '/swap/d' /etc/fstab
    ```

4. **Enable and Load Kernel modules [See](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)**

    Add containerd.conf to kernel modules:
    ```
    cat >>/etc/modules-load.d/containerd.conf<<EOF
    overlay
    br_netfilter
    EOF
    ```
    Use modprobe to add the loadable kernel modules to the Linux kernel:
    ```
    modprobe overlay
    modprobe br_netfilter
    ```
    
5. **Update sysctl kernel settings for kubernetes networking [See](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)**

    Add the kubernetes conf to sysctl.d:
    Note cat > will overwrite and cat >> will append, choose wisely.
    ```
    cat >/etc/sysctl.d/kubernetes.conf<<EOF
    net.bridge.bridge-nf-call-ip6tables = 1
    net.bridge.bridge-nf-call-iptables = 1
    net.ipv4.ip_forward = 1
    EOF
    ```
    Kernel configuration changes will only take effect after reboot. To take effect immedately run:
    ```
    sysctl --system
    ```

6. **Install [containerd](https://github.com/containerd/containerd#hello-kubernetes-v124) and other dependencies**

    ```
    apt update
    apt install -y apt-transport-https
    ```
    Install correct containerd version, first check the version/s your ubuntu apt cache has available:
    ```
    apt-cache policy containerd
    ```
    If the correct version is listed then run:
    ```
    apt install -y containerd=1.6.4-0ubuntu3
    ```
    Otherwise install the correct version manually by downloading the [release](https://github.com/containerd/containerd/releases/tag/v1.6.4).
    You will need to know the architecture of your device:
    ```
    dpkg --print-architecture
    wget https://github.com/containerd/containerd/releases/download/v1.6.4/containerd-1.6.4-linux-amd64.tar.gz
    ```
    Unpack the file to /usr/local
    ```
    tar Cxzvf /usr/local containerd-1.6.4-linux-amd64.tar.gz
    ```
    Install containerd's [runc](https://github.com/opencontainers/runc/releases):
    ```
    wget https://github.com/opencontainers/runc/releases/download/v1.1.1/runc.amd64
    install -m 755 runc.amd64 /usr/local/sbin/runc
    ```
    Setup containerd's Container Network Interface (CNI) plugin
    ```
    wget https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-amd64-v1.1.1.tgz
    mkdir -p /opt/cni/bin
    tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.1.1.tgz
    ```
    Configure containerd:
    ```
    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml
    sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
    ```
    Download the systemd file
    ```
    curl -L https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o /etc/systemd/system/containerd.service
    ```
    Restart containerd:
    ```
    systemctl restart containerd
    systemctl daemon-reload
    systemctl enable --now containerd
    ```
    Verify systemd service
    ```
    systemctl status containerd
    ```

7. **Add kubernetes repository**

    ```
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
    apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
    ```

8. **Install kubernetes components**

    ```
    apt install -y kubeadm=1.24.0-00 kubelet=1.24.0-00 kubectl=1.24.0-00
    ```

9. **OPTIONAL - Enable ssh password authentication**

    If you have not setup ssh authentication with key pair then you will need to permit root login with password.
    ```
    sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
    systemctl reload sshd
    ```
    
10. **OPTIONAL - Set root password**

    Do not do this if you already have a root password!
    ```
    echo -e "kubeadmin\nkubeadmin" | passwd root
    echo "export TERM=xterm" >> /etc/bash.bashrc
    ```
    
11. **OPTIONAL? - Update /etc/hosts file**

    ```
    cat >>/etc/hosts<<EOF
    192.168.0.215   server1.local   server1
    192.168.0.225   server2.local   server2
    192.168.0.226   server3.local   server3
    EOF
    ```

#### On server nodes

1. **Pull required containers**

    ```
    kubeadm config images pull --kubernetes-version=1.24.0
    ```

2. **Initialise kubernetes cluster**

    ```
    kubeadm init --kubernetes-version=1.24.0 --apiserver-advertise-address=192.168.0.215 --pod-network-cidr=192.168.0.0/16 >> /root/kubeinit.log
    ```

3. **Deploy [calico](https://github.com/projectcalico/calico) network**

    ```
    kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f https://docs.projectcalico.org/v3.18/manifests/calico.yaml
    ```

4. **Cluster join and save the command to script file**

    ```
    kubeadm token create --print-join-command > /root/joincluster.sh
    ```

5. **Setup kube config for non root users**

    ```
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    ```

6. **Export kubeconfig env**

    ```
    export KUBECONFIG=/etc/kubernetes/admin.conf
    ```

7. **Verify cluster connection and status**

    ```
    kubectl get nodes
    kubectl get cs
    ```

#### On agent nodes

1. **Join the cluster**

    ```
    *run joincluster.sh command from output of servers kubeadm token create*
    ```

2. **Setup kube config for non root users**

    ```
    mkdir -p $HOME/.kube
    *copy server kubeconfig file to $HOME/.kube/config and ensure server parameter is ip of server
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    ```

3. **Export kubeconfig env**

    ```
    export KUBECONFIG=$HOME/.kube/config
    ```
    
4. **Verify cluster connection and status**

    ```
    kubectl get nodes
    kubectl get cs
    ```

#### Test pod deployment

1. **Check current pods**

    ```
    kubect get pods -A
    ```

2. **Create deployment**

    ```
    kubectl create deploy nginx --image nginx
    kubectl get all
    ```

3. **Expose pod with NodePort**

    ```
    kubectl expose deploy nginx --port 80 --type NodePort
    kubectl get svc
    ```

4. **Test pod access**

    On each node try access the NodePort assigned to the service.
    ```
    curl 192.168.0.225:31127
    ```

5. **Remove pod**

    ```
    kubectl delete svc/nginx
    kubectl delete deploy nginx
    ```
