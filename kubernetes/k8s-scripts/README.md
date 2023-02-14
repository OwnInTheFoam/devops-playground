# Tigase k8s-scripts
This can setup:
- FluxCD
- Sealed secrets
- Ingress nginx
- Longhorn
- Cert manager
- K8s dashboard
- Kube prometheus stack
- Loki
- Velero (Optional)
- Onedev (Optional)
- Weblate (Optional)
- Tigase (Optional)
- CoTurn (Optional)
- Mailu (Optional)
- Rancher (Optional)
- Killbill (Optional)

## Resources
- [Tigase](https://github.com/tigase/k8s-scripts)
- [just-4.fun](https://just-4.fun/blog/howto)

## Requirements

A empty kubernetes cluster

## Setup

Create working directory within the cluster content directory.
```bash
cat>>/etc/profile.d/local-envs.sh<<EOF
export TIG_CLUSTER_HOME=${HOME}/tigase
EOF
kubectl config get-contexts
mkdir -p ${HOME}/tigase/context-name
```

Ensure the k8s-scripts repository is cloned.
```bash
cd ${HOME}/tigase/context-name
git clone https://github.com/tigase/k8s-scripts .
```

By running the script to check requirements you may get your setup ready
```bash
./${HOME}/tigase/context-name/scripts/scripts-env-init.sh --check
```

### Configuration
To configure k8s-scripts edit `/envs/cluster.env` and `/envs/versions.env`.

- Set `K8S_CONTEXT`
  ```bash
  kubectl config get-contexts
  cat>>/etc/profile.d/local-envs.sh<<EOF
  export K8S_CONTEXT=context_name
  EOF
  ```
- Set `K8S_CLUSTER_CONTEXT`
  ```bash
  nano /${HOME}/tigase/${K8S_CONTEXT}/envs/cluster.env
  ```
- Set `CLUSTER_NAME`
- Set `GITHUB_USER`
- Set `GITHUB_TOKEN`
- Set `CLUSTER_REPO`
- Set `SSL_EMAIL`

### Packages
- Install kubeseal
  ```bash
  wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.19.4/kubeseal-0.19.4-linux-arm64.tar.gz
  tar -xvzf kubeseal-0.19.4-linux-arm64.tar.gz kubeseal
  sudo install -m 755 kubeseal /usr/local/bin/kubeseal
  kubeseal --version
  ```
- Install fluxcd
  ```bash
  curl -s https://fluxcd.io/install.sh | sudo bash
  flux --version
  ```
- Install kustomize
  ```bash
  curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
  chmod 755 "${TMP_BIN}"
  mv -f kustomize /usr/local/bin
  kustomize version
  ```
- Install and configure git
  ```bash
  apt update
  apt install git
  git config --global user.email "you@email.com"
  git config --global user.name "Your Name"
  ```
  Then add your ssh key to the git repository for easy access - requires ssh key pair
  ```bash
  cat /root/.ssh/id_rsa.pub
  ```

### Installation

#### FluxCD

```bash
./${HOME}/tigase/${K8S_CONTEXT}/scripts/flux-bootstrap.sh 
flux get all -A
```

#### Sealed Secrets

Identify the version you would like to install. To get the latest version search helm and then input the chart version as `SS_VER` in `/envs/versions.env`
```bash
helm search hub --max-col-width 80 sealed-secrets | grep "bitnami-labs"
nano /${HOME}/tigase/${K8S_CONTEXT}/envs/versions.env
```
You may also edit the `envs/ss_values.yaml` file if needed.
```bash
nano /${HOME}/tigase/${K8S_CONTEXT}/envs/ss_values.yaml
```
Then run the installer
```bash
./${HOME}/tigase/${K8S_CONTEXT}/scripts/cluster-sealed-secrets.sh
flux get hr -A
flux get all -A | grep sealed
find /${HOME}/tigase/${K8S_CONTEXT}/projects -name "*sealed*"
```

#### Ingress nginx

Identify the version you would like to install. To get the latest version search helm and then input the chart version as `IN_VER` in `/envs/versions.env`
```bash
helm search hub --max-col-width 80 ingress-nginx | grep "ingress-nginx/ingress-nginx"
nano /${HOME}/tigase/${K8S_CONTEXT}/envs/versions.env
```
You may also edit the `envs/nginx_values.yaml` file if needed.
```bash
nano /${HOME}/tigase/${K8S_CONTEXT}/envs/nginx_values.yaml
```
Then run the installer
```bash
./${HOME}/tigase/${K8S_CONTEXT}/scripts/cluster-ingress-nginx.sh
flux get hr -A
flux get all -A | grep ingress
find /${HOME}/tigase/${K8S_CONTEXT}/projects -name "*ingress*"
kubectl describe deployment ingress-nginx-controller -n ingress-nginx
```

#### Cert-manager

Identify the version you would like to install. To get the latest version search helm and then input the chart version as `CM_VER` in `/envs/versions.env`
```bash
helm search hub --max-col-width 80 cert-manager | grep "cert-manager/cert-manager"
nano /${HOME}/tigase/${K8S_CONTEXT}/envs/versions.env
```
Edit the `envs/cert-man_values.yaml` file.
```bash
nano /${HOME}/tigase/${K8S_CONTEXT}/envs/cert-man_values.yaml
```
Then run the installer
```bash
./${HOME}/tigase/${K8S_CONTEXT}/scripts/cluster-cert-manager.sh
flux get hr -A
flux get all -A | grep cert-manager
find /${HOME}/tigase/${K8S_CONTEXT}/projects -name "*cert-manager*"
kubectl get pods -n cert-manager
kubectl describe deployment cert-manager -n cert-manager
kubectl get clusterissuer -A
kubectl describe clusterissuer letsencrypt
```
Test certificates
```bash
TODO
```

**Uninstallation**

With script:
```bash
./scripts/cluster-cert-manager.sh --remove
```
Remove manifest files from repository
```bash
rm -r /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/cert-manager
rm -r /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/sources/cert-manager.yaml
sed -i '/cert-manager/d' /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/kustomization.yaml
sed -i '/cert-manager/d' /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/sources/kustomization.yaml
```
Update the repository
```bash
cd /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops
git add -A
git commit -am "cert-manager uninstallation"
git push
```
Reconcile the cluster
```bash
flux reconcile source git "flux-system"
```

#### Longhorn

First check [these](https://longhorn.io/docs/1.4.0/deploy/install/#installation-requirements) requirements and run the following script to confirm:
```bash
curl -sSfL https://raw.githubusercontent.com/longhorn/longhorn/v1.4.0/scripts/environment_check.sh | bash
```
Identify the version you would like to install. To get the latest version search helm and then input the chart version as `LH_VER` in `/envs/versions.env`
```bash
helm search hub --max-col-width 80 longhorn | grep "longhorn/longhorn"
nano /${HOME}/tigase/${K8S_CONTEXT}/envs/versions.env
```
If you would like backups to be created you may also edit the `envs/longhorn-values.yaml` file.
```bash
nano /${HOME}/tigase/${K8S_CONTEXT}/envs/longhorn-values.yaml
```
Then run the installer
```bash
./${HOME}/tigase/${K8S_CONTEXT}/scripts/cluster-longhorn.sh
flux get hr -A
flux get all -A | grep longhorn
find /${HOME}/tigase/${K8S_CONTEXT}/projects -name "*longhorn*"
```
Setup and configure backups
```bash
kubectl get ingress longhorn-ingress -o yaml -n longhorn-system
TODO
```

**Uninstallation**

`/${HOME}/tigase/${K8S_CONTEXT}/scripts/cluster-longhorn.sh --remove`
Remove manifest files from repository
```bash
rm -r /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/longhorn-system
rm -r /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/sources/longhorn.yaml
rm -r /${HOME}/tigase/${K8S_CONTEXT}/k8s-secrets
rm -r /${HOME}/tigase/${K8S_CONTEXT}/tmp/auth
rm -r /${HOME}/tigase/${K8S_CONTEXT}/longhorn-basic-auth.yaml
sed -i '/longhorn/d' /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/kustomization.yaml
sed -i '/longhorn/d' /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/sources/kustomization.yaml
```
Update the repository
```bash
cd /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops
git add -A
git commit -am "longhorn uninstallation"
git push
```
Reconcile the cluster
```bash
flux reconcile source git "flux-system"
```

#### Kubernetes dashboard

Identify the version you would like to install. To get the latest version search helm and then input the chart version as `DA_VER` in `/envs/versions.env`
```bash
helm search hub --max-col-width 80 kubernetes-dashboard | grep "k8s-dashboard/kubernetes-dashboard"
nano /${HOME}/tigase/${K8S_CONTEXT}/envs/versions.env
```
Edit the `envs/k8s-dashboard-values.yaml` file.
```bash
nano /${HOME}/tigase/${K8S_CONTEXT}/envs/k8s-dashboard-values.yaml
```
Then run the installer
```bash
./${HOME}/tigase/${K8S_CONTEXT}/scripts/cluster-kubernetes-dashboard.sh
flux get hr -A
flux get all -A | grep dashboard
find /${HOME}/tigase/${K8S_CONTEXT}/projects -name "*dashboard*"
kubectl get pods -n k8s
```
Test dashboard
```bash
kubectl -n k8s port-forward ${POD_NAME} 8443:8443
```

#### Kube-prometheus-stack

Identify the version you would like to install. To get the latest version search helm and then input the chart version as `PM_VER` in `/envs/versions.env`
```bash
helm search hub --max-col-width 80 prometheus-community | grep "prometheus-community/kube-prometheus-stack"
nano /${HOME}/tigase/${K8S_CONTEXT}/envs/versions.env
```
Edit the `envs/prometheus-values.yaml` file.
```bash
nano /${HOME}/tigase/${K8S_CONTEXT}/envs/prometheus-values.yaml
```
The installer does not run the `flux create source chart` command therefore do it manually,
```bash
```
Then run the installer
```bash
./${HOME}/tigase/${K8S_CONTEXT}/scripts/cluster-kube-prometheus-stack.sh
flux get hr -A
flux get all -A | grep 
find /${HOME}/tigase/${K8S_CONTEXT}/projects -name "*dashboard*"
kubectl get pods -n k8s
```
Test dashboard
```bash
kubectl -n k8s port-forward ${POD_NAME} 8443:8443
```

**Uninstallation**
Via script with
```bash
/${HOME}/tigase/${K8S_CONTEXT}/scripts/cluster-kube-prometheus-stack.sh --remove
/${HOME}/tigase/${K8S_CONTEXT}/scripts/cluster-script-preprocess.sh --remove ?!?
```
```bash
rm -r /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/monitoring/kube-prometheus-stack
sed -i '/prometheus/d' /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/monitoring/kustomization.yaml
//sed -i '/monitoring/d' /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/kustomization.yaml
//sed -i '/prometheus/d' /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/sources/kustomization.yaml
```
Apply changes to git repository
```bash
cd /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops
git add -A
git commit -am "prometheus stack uninstall"
git push
```
Reconcile cluster
```bash
flux reconcile source git "flux-system"
kubectl get all -A | grep prometheus
```

#### Loki

Identify the version you would like to install. To get the latest version search helm and then input the chart version as `DA_VER` in `/envs/versions.env`
```bash
helm search hub --max-col-width 80 kubernetes-dashboard | grep "k8s-dashboard/kubernetes-dashboard"
nano /${HOME}/tigase/${K8S_CONTEXT}/envs/versions.env
```
Edit the `envs/k8s-dashboard-values.yaml` file.
```bash
nano /${HOME}/tigase/${K8S_CONTEXT}/envs/k8s-dashboard-values.yaml
```
Then run the installer
```bash
./${HOME}/tigase/${K8S_CONTEXT}/scripts/cluster-kubernetes-dashboard.sh
flux get hr -A
flux get all -A | grep dashboard
find /${HOME}/tigase/${K8S_CONTEXT}/projects -name "*dashboard*"
kubectl get pods -n k8s
```
Test dashboard
```bash
kubectl -n k8s port-forward ${POD_NAME} 8443:8443
```

#### Mailu

Identify the version you would like to install. To get the latest version search helm and then input the chart version as `MAILU_VER` in `/envs/versions.env`
```bash
helm search hub --max-col-width 80 mailu | grep "mailu/mailu"
nano /${HOME}/tigase/${K8S_CONTEXT}/envs/versions.env
```
Update the mailu configuration file
```bash
nano /${HOME}/tigase/kubernetes-admin@kubernetes/envs/mailu.env
```
For example;
`MAILU_DOMAIN="example.com"`
`MAILU_HOSTNAMES=(mail.example.com)`
`MAILU_ADMIN_DOMAIN="postmaster"`
`MAILU_ADMIN_PASSWORD="yourPassword"`
`MAILU_SUBNET="10.244.0.0/16"`
To retrieve the cluster subnet you may get `podSubnet` from
```bash
kubectl get cm -n kube-system kubeadm-config -o yaml
```
Edit the `envs/mailu-values.yaml` file.
```bash
nano /${HOME}/tigase/${K8S_CONTEXT}/envs/mailu-values.yaml
```
To watch the installation
```bash
while k get pods -A | grep "0/1" ; do date; sleep 20; done
flux get hr -A -w
```
Then run the installer
```bash
./${HOME}/tigase/${K8S_CONTEXT}/scripts/cluster-mailu.sh
kubectl get namespaces
flux get hr -A
flux get all -A | grep mailu
kubectl get all -n mailu-prod
find /${HOME}/tigase/${K8S_CONTEXT}/projects -name "*mailu*"
kubectl describe deployment mailu-admin -n mailu-prod
kubectl describe pod/mailu-admin-696655b8bf-4vqmb -n mailu-prod
```

**Web UI and sending/recieving**
```bash
TODO
```
**Uninstalltion**
```bash
./scripts/cluster-mailu.sh --remove
```