#!/bin/bash
# chmod u+x install.sh
# git add --chmod=+x install.sh

echo "[TASK] Downloading install script"
wget --no-verbose "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"

echo "[TASK] Running install script"
sudo bash install_kustomize.sh

echo "[TASK] Moving binary to packages"
sudo mv -f kustomize /usr/local/bin

echo "COMPLETE"
