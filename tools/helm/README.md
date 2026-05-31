# Helm

## [Installation](https://helm.sh/docs/intro/install/)
```bash
wget --no-verbose -O get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh
./get_helm.sh
helm version
```

## Usage
Check version of repository
```bash
helm search hub --max-col-width 80 sealed-secrets | grep "bitnami-labs"
```

