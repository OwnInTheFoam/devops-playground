kubectl delete -f https://raw.githubusercontent.com/metallb/metallb/v0.13.3/config/manifests/metallb-native.yaml

kubectl delete -f IPAddressPool.yaml

kubectl delete -f L2Advertisement.yaml

