# Helm

## Installation
```bash
wget --no-verbose https://get.helm.sh/helm-v3.12.2-linux-amd64.tar.gz
tar -zxvf helm-v3.12.2-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin/helm
helm version
```

## Usage
Check version of repository
```bash
helm search hub --max-col-width 80 sealed-secrets | grep "bitnami-labs"
```

