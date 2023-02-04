#!/bin/bash
# chmod u+x install.sh
# git add --chmod=+x install.sh

# This script will run uninstall.sh on all servers;

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
logFile="${DIR}/uninstall.log"
#logFile="/dev/null"

echo "[TASK 1] Run uninstall.sh on all other servers"
for ((i = 1; i < ${#serverName[@]}; ++i)); do
  echo "          - ${serverName[$i]} uninstall.sh"
  ssh -p ${serverPort[$i]} ${serverUser[$i]}@${serversshIP[$i]} 'mkdir -p ~/k8s' >>${logFile} 2>&1
  scp -P ${serverPort[$i]} ${DIR}/uninstall.sh ${serverUser[$i]}@${serversshIP[$i]}:~/k8s/uninstall.sh >>${logFile} 2>&1
  ssh -p ${serverPort[$i]} ${serverUser[$i]}@${serversshIP[$i]} "sed -i 's/.*serverNumber=.*/serverNumber=$i/' ~/k8s/uninstall.sh" >>${logFile} 2>&1
  ssh -p ${serverPort[$i]} ${serverUser[$i]}@${serversshIP[$i]} ~/k8s/uninstall.sh >>${logFile} 2>&1
done

echo "[TASK 2] Run uninstall.sh on this server"
/bin/bash ./uninstall.sh

echo "COMPLETE"