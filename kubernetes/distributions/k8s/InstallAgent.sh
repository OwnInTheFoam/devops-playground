#!/bin/bash
# chmod u+x uninstall.sh
# git add --chmod=+x install.sh

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
logFile="${DIR}/InstallAgent.log"
touch ${logFile}
#logFile="/dev/null"

#echo "Input root user password of server machine"
#read userPassword

echo "[TASK 1] Join node to Kubernetes Cluster"
#apt install -qq -y sshpass >>${logFile} 2>&1
#sshpass -p "${userPassword}" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -P ${sshPort} root@server-1.local:/${HOME}/k8s/joincluster.sh /${HOME}/k8s/joincluster.sh >>${logFile}
#scp -P ${sshPort} root@${publicIP}:/${DIR}/joincluster.sh ${DIR}/joincluster.sh
sudo /bin/bash /${DIR}/joincluster.sh >>${logFile} 2>&1

echo "[TASK 2] Setup kubeconfig"
#mkdir -p ${HOME}/.kube
#sshpass -p "${userPassword}" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -P ${sshPort} root@server-1.local:/etc/kubernetes/admin.conf /${HOME}/.kube/config 2>>${logFile}
# todo update incase server is 127.0.0.1 with server ip
#sed -i 's/^.*server: .*/server:/' /etc/ssh/sshd_config
chown $(id -u):$(id -g) ${HOME}/.kube/config

echo "[TASK 3] Add kubeconfig env"
#export KUBECONFIG=${HOME}/.kube/config
echo "KUBECONFIG=${HOME}/.kube/config" | sudo tee -a /etc/environment >>${logFile} 2>&1

echo "[TASK 4] Setup bash aliases"
cat>>${HOME}/.bash_aliases<<EOF
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias ke='kubectl exec'
alias kp='kubectl proxy'
alias f='flux'
alias fg='flux get'
EOF

echo "COMPLETE!"
