#!/bin/bash
# chmod u+x uninstall.sh

# DEFINES - versions
metallbVer=0.13.3
# VARIABLE DEFINES
startingIP="192.1668.0.240"
endingIP="192.168.0.250"
logFile="${HOME}/metallb/uninstall.log"
#logFile="/dev/null"

echo "[TASK] Delete L2Advertisement"
kubectl delete -f /${HOME}/metallb/L2Advertisement.yaml >>${logFile} 2>&1

echo "[TASK] Delete IPAddressPool"
kubectl delete -f /${HOME}/metallb/IPAddressPool.yaml >>${logFile} 2>&1

echo "[TASK] Delete metallb values manifest"
kubectl delete -f /${HOME}/metallb/metallb-values.yaml >>${logFile} 2>&1

echo "COMPLETE"
