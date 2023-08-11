#!/bin/bash
# chmod u+x install.sh

# DEFINES - versions
metallbVer=0.13.10
# VARIABLE DEFINES
startingIP="192.168.0.240"
endingIP="192.168.0.250"
logFile="${HOME}/metallb/install.log"
#logFile="/dev/null"

mkdir -p /${HOME}/metallb

echo "[TASK] Get metllb-values manifest and apply"
wget --no-verbose -O /${HOME}/metallb/metallb-values.yaml https://raw.githubusercontent.com/metallb/metallb/v${metallbVer}/config/manifests/metallb-native.yaml >>${logFile} 2>&1
kubectl apply -f /${HOME}/metallb/metallb-values.yaml >>${logFile} 2>&1

echo "[TASK] Wait for metallb deployment running"
# Wait for a metallb-system pod named controller
# kubectl get pods --selector "app.kubernetes.io/name=traefik" --output=name
while [[ $(kubectl -n metallb-system get pods -o=name | grep controller) == "" ]]; do
   sleep 1
done
# Wait for metallb-system controller pod to be running
while [[ $(kubectl -n metallb-system get $(kubectl -n metallb-system get pods -o=name | grep controller) -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
   sleep 1
done

echo "[TASK] Create IPAddressPool manifest and apply"
cat >/${HOME}/metallb/IPAddressPool.yaml<<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - ${startingIP}-${endingIP}
EOF
kubectl apply -f /${HOME}/metallb/IPAddressPool.yaml >>${logFile} 2>&1

echo "[TASK] Create L2Advertisement manifest and apply"
cat >/${HOME}/metallb/L2Advertisement.yaml<<EOF
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - first-pool
EOF
kubectl apply -f /${HOME}/metallb/L2Advertisement.yaml >>${logFile} 2>&1

echo "COMPLETE"
