#!/bin/bash
# chmod u+x install.sh
# git add --chmod=+x install.sh

# This script will run Install.sh on all servers;
# then InstallServer.sh on master nodes;
# then InstallAgents.sh on agent nodes.

# requirements
# - ssh with key pair access to all servers

# DEFINES - versions
kubernetesVer=1.24.0
containerdVer=1.6.4
runcVer=1.1.1
cniPluginVer=1.1.1
#calicoVer=3.18
flannelVer=0.20.2
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

echo "[TASK 1] Run Install.sh on this server"
/bin/bash ./Install.sh

echo "[TASK 2] Run Install.sh on all other servers"
for ((i = 1; i < ${#serverName[@]}; ++i)); do
  echo "          - ${serverName[$i]} Install.sh"
  ssh -p ${serverPort[$i]} ${serverUser[$i]}@${serversshIP[$i]} 'mkdir -p ~/k8s' >>${logFile} 2>&1
  scp -P ${serverPort[$i]} ${DIR}/Install.sh ${serverUser[$i]}@${serversshIP[$i]}:~/k8s/Install.sh >>${logFile} 2>&1
  ssh -p ${serverPort[$i]} ${serverUser[$i]}@${serversshIP[$i]} "sed -i 's/.*serverNumber=.*/serverNumber=$i/' ~/k8s/Install.sh" >>${logFile} 2>&1
  ssh -p ${serverPort[$i]} ${serverUser[$i]}@${serversshIP[$i]} ~/k8s/Install.sh >>${logFile} 2>&1
done

echo "[TASK 3] Run InstallServer.sh on this server"
/bin/bash ./InstallServer.sh

echo "[TASK 4] Copy joincluster script and kubeconfig to other servers"
for ((i = 1; i < ${#serverName[@]}; ++i)); do
  echo "          - ${serverName[$i]} copy joincluster.sh"
  scp -P ${serverPort[$i]} ${DIR}/joincluster.sh ${serverUser[$i]}@${serversshIP[$i]}:~/k8s/joincluster.sh >>${logFile} 2>&1
  ssh -p ${serverPort[$i]} ${serverUser[$i]}@${serversshIP[$i]} 'mkdir -p ~/.kube' >>${logFile} 2>&1
  scp -P ${serverPort[$i]} /etc/kubernetes/admin.conf ${serverUser[$i]}@${serversshIP[$i]}:~/.kube/config >>${logFile} 2>&1
done

echo "[TASK 5] Run InstallAgent.sh on all other servers"
for ((i = 1; i < ${#serverName[@]}; ++i)); do
  echo "          - ${serverName[$i]} InstallAgent.sh"
  scp -P ${serverPort[$i]} ${DIR}/InstallAgent.sh ${serverUser[$i]}@${serversshIP[$i]}:~/k8s/InstallAgent.sh >>${logFile} 2>&1
  ssh -p ${serverPort[$i]} ${serverUser[$i]}@${serversshIP[$i]} "sed -i 's/.*serverNumber=.*/serverNumber=$i/' ~/k8s/InstallAgent.sh" >>${logFile} 2>&1
  ssh -p ${serverPort[$i]} ${serverUser[$i]}@${serversshIP[$i]} ~/k8s/InstallAgent.sh >>${logFile} 2>&1
done

echo "COMPLETE"