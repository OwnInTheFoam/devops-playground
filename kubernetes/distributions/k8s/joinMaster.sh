# TODO This script is incomplete and untested.
# https://facsiaginsa.com/kubernetes/join-existing-kubernetes-cluster

# Run from existing master node

sudo kubectl get cm kubeadm-config -n kube-system -o yaml > kubeadm-config.yaml

# todo Get the ClusterConfiguration
yq ClusterConfiguration kubeadm-config.yaml

kubeadm init phase upload-certs --upload-certs --config kubeadm-config.yaml

kubeadm token create --print-join-command > joincluster.sh

cat >>joincluster.sh<<
--control-plane --certificate-key <ceritifcate-key>
EOF

# Run on new master node

cat>>/etc/hosts<<EOF
192.168.0.227 cluster-endpoint
EOF

echo "[TASK] Run join "
ssh -p ${serverPort[$i]} ${serverUser[$i]}@${serverlocalIP[$i]} 'mkdir -p ~/k8s' >>${logFile} 2>&1
scp -P ${serverPort[$i]} ${DIR}/uninstall.sh ${serverUser[$i]}@${serverlocalIP[$i]}:~/k8s/uninstall.sh >>${logFile} 2>&1
ssh -p ${serverPort[$i]} ${serverUser[$i]}@${serverlocalIP[$i]} "sed -i 's/.*serverNumber=.*/serverNumber=$i/' ~/k8s/uninstall.sh" >>${logFile} 2>&1
ssh -t -p ${serverPort[$i]} ${serverUser[$i]}@${serverlocalIP[$i]} " sudo -S ~/k8s/uninstall.sh"

./joincluster.sh

