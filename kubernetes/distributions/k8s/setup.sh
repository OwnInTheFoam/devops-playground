#!/bin/bash
# chmod u+x install.sh
# git add --chmod=+x install.sh

# This script will run Install.sh on all servers;
# then InstallServer.sh on master nodes;
# then InstallAgents.sh on agent nodes.

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
logFile="${DIR}/setup.log"
touch ${logFile}
#logFile="/dev/null"

echo "[TASK 1] Run Install.sh on this server"
/bin/bash ./Install.sh

echo "[TASK 2] Run Install.sh on all other servers"
for ((i = 1; i < ${#serverName[@]}; ++i)); do
  echo "          - ${serverName[$i]} Install.sh"
  ssh -p ${serverPort[$i]} ${serverUser[$i]}@${serverlocalIP[$i]} 'mkdir -p ~/k8s' >>${logFile} 2>&1
  scp -P ${serverPort[$i]} ${DIR}/Install.sh ${serverUser[$i]}@${serverlocalIP[$i]}:~/k8s/Install.sh >>${logFile} 2>&1
  ssh -p ${serverPort[$i]} ${serverUser[$i]}@${serverlocalIP[$i]} "sed -i 's/.*serverNumber=.*/serverNumber=$i/' ~/k8s/Install.sh" >>${logFile} 2>&1
  ssh -t -p ${serverPort[$i]} ${serverUser[$i]}@${serverlocalIP[$i]} "~/k8s/Install.sh"
done

echo "[TASK 3] Run InstallServer.sh on this server"
/bin/bash ./InstallServer.sh

echo "[TASK 4] Copy joincluster script and kubeconfig to other servers"
for ((i = 1; i < ${#serverName[@]}; ++i)); do
  echo "          - ${serverName[$i]} copy joincluster.sh"
  scp -P ${serverPort[$i]} ${DIR}/joincluster.sh ${serverUser[$i]}@${serverlocalIP[$i]}:~/k8s/joincluster.sh >>${logFile} 2>&1
  ssh -p ${serverPort[$i]} ${serverUser[$i]}@${serverlocalIP[$i]} 'mkdir -p ~/.kube' >>${logFile} 2>&1
  #scp -P ${serverPort[$i]} /etc/kubernetes/admin.conf ${serverUser[$i]}@${serverlocalIP[$i]}:~/.kube/config >>${logFile} 2>&1
  scp -P ${serverPort[$i]} ~/.kube/config ${serverUser[$i]}@${serverlocalIP[$i]}:~/.kube/config >>${logFile} 2>&1
done

echo "[TASK 5] Run InstallAgent.sh on all other servers"
for ((i = 1; i < ${#serverName[@]}; ++i)); do
  echo "          - ${serverName[$i]} InstallAgent.sh"
  scp -P ${serverPort[$i]} ${DIR}/InstallAgent.sh ${serverUser[$i]}@${serverlocalIP[$i]}:~/k8s/InstallAgent.sh >>${logFile} 2>&1
  ssh -p ${serverPort[$i]} ${serverUser[$i]}@${serverlocalIP[$i]} "sed -i 's/.*serverNumber=.*/serverNumber=$i/' ~/k8s/InstallAgent.sh" >>${logFile} 2>&1
  ssh -t -p ${serverPort[$i]} ${serverUser[$i]}@${serverlocalIP[$i]} "~/k8s/InstallAgent.sh"
done

echo "COMPLETE"
