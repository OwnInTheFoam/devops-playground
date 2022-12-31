#!/bin/bash
# chmod u+x install.sh

# REQUIREMENTS
# - traefik
# - helm (curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && chmod 700 get_helm.sh && ./get_helm.sh)
# - yq (wget https://github.com/mikefarah/yq/releases/download/v4.30.6/yq_linux_amd64.tar.gz -O - | tar xz && mv yq_linux_amd64 /usr/bin/yq)

# DEFINES - versions
certmanagerVer=1.10.1
certmanagerChartVer=1.10.1
# VARIABLE DEFINES
logFile="${HOME}/cert-manager/install.log"
#logFile="/dev/null"

mkdir -p /${HOME}/cert-manager

echo "[TASK] Modify traefik"
cp /${HOME}/traefik/traefik-values.yaml /${HOME}/cert-manager/ >>${logFile} 2>&1
#yq -i '.providers.kubernetesIngress.ingressClass="traefik-ingress"' /${HOME}/cert-manager/traefik-values.yaml
yq -i '.providers.kubernetesCRD.ingressClass="traefik-external"' /${HOME}/traefik/traefik-values.yaml
helm upgrade -n traefik -f /${HOME}/cert-manager/traefik-values.yaml traefik traefik/traefik >>${logFile} 2>&1

echo "[TASK] Add cert-manager helm repo"
helm repo add jetstack https://charts.jetstack.io >>${logFile} 2>&1
helm repo update >>${logFile} 2>&1

echo "[TASK] Install cert-manager CRD"
wget --no-verbose -O /${HOME}/cert-manager/cert-manager-crds.yaml https://github.com/cert-manager/cert-manager/releases/download/v${certmanagerVer}/cert-manager.crds.yaml >>${logFile} 2>&1
kubectl apply -f /${HOME}/cert-manager/cert-manager-crds.yaml >>${logFile} 2>&1

echo "[TASK] Get cert-manager values and alter"
#helm search repo jetstack/cert-manager --versions
helm show values jetstack/cert-manager --version ${certmanagerChartVer} > /${HOME}/cert-manager/cert-manager-values.yaml
#yq -i '.installCRDs=true' /${HOME}/cert-manager/certmanager-values.yaml
yq -i '.extraArgs += "--dns01-recursive-nameservers=1.1.1.1:53,9.9.9.9:53"' /${HOME}/cert-manager/cert-manager-values.yaml
yq -i '.extraArgs += "--dns01-recursive-nameservers-only"' /${HOME}/cert-manager/cert-manager-values.yaml
yq -i '.podDnsPolicy="None"' /${HOME}/cert-manager/cert-manager-values.yaml
yq -i '.podDnsConfig.nameservers.[0]="1.1.1.1" | .podDnsConfig.nameservers.[] style="double"' /${HOME}/cert-manager/cert-manager-values.yaml
yq -i '.podDnsConfig.nameservers.[1]="9.9.9.9" | .podDnsConfig.nameservers.[] style="double"' /${HOME}/cert-manager/cert-manager-values.yaml

echo "[TASK] Install cert-manager with helm"
helm install cert-manager jetstack/cert-manager --version ${certmanagerChartVer} --values /${HOME}/cert-manager/cert-manager-values.yaml -n cert-manager --create-namespace >>${logFile} 2>&1

echo "[TASK] Setup cloudflare token secret"
echo "[INPUT] Please enter a cloudflare API token..."
read userToken
cat >/${HOME}/cert-manager/cloudflare-token-secret.yaml<<EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-token-secret
  namespace: cert-manager
type: Opaque
stringData:
  # Generate an API token and NOT a global API key https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/#api-tokens
  cloudflare-token: ${userToken}
EOF
kubectl apply -f /${HOME}/cert-manager/cloudflare-token-secret.yaml >>${logFile} 2>&1

echo "[TASK] Setup cluster issuer staging"
echo "[INPUT] Please enter a email for cloudflare & letsencrypt..."
read userEmail
echo "[INPUT] Please enter a domain for certificates..."
read userDomain
cat >/${HOME}/cert-manager/clusterissuer-staging.yaml<<EOF
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
  namespace: default
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ${userEmail}
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
#    - http01:
#        ingress:
#          class: traefik-ingress
    - dns01:
        cloudflare:
          email: ${userEmail}
          apiTokenSecretRef:
            name: cloudflare-token-secret
            key: cloudflare-token
      selector:
        dnsZones:
          - "${userDomain}"
EOF
kubectl apply -f /${HOME}/cert-manager/clusterissuer-staging.yaml >>${logFile} 2>&1

echo "[TASK] Setup default namespace certificate staging"
cat >/${HOME}/cert-manager/certificate-staging.yaml<<EOF
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: cert-staging
  namespace: default
spec:
  secretName: staging-tls
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
  commonName: "*.local.${userDomain}"
  dnsNames:
  - "local.${userDomain}"
  - "*.local.${userDomain}"
EOF
kubectl apply -f /${HOME}/cert-manager/certificate-staging.yaml >>${logFile} 2>&1

echo "[TASK] Update /etc/hosts for traefik local DNS entry"
externalIP=$(kubectl -n traefik get svc traefik -o 'jsonpath={.status.loadBalancer.ingress[0].ip}')
if grep -q "${externalIP}" /etc/hosts
then
sed -i "/^${externalIP}/ s/$/ nginx.local.${userDomain}/" /etc/hosts
else
cat >>/etc/hosts<<EOF
${externalIP}   nginx.local.${userDomain}
EOF
fi

echo "[TASK] Test staging certificate for nginx service"
cat >/${HOME}/cert-manager/nginx.yaml<<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: default
  labels:
    app: nginx
spec:
  replicas: 1
  progressDeadlineSeconds: 600
  revisionHistoryLimit: 2
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace: default
spec:
  selector:
    app: nginx
  ports:
  - name: http
    targetPort: 80
    port: 80
---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: nginx
  namespace: default
  annotations:
    kubernetes.io/ingress.class: traefik-external
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(\`nginx.local.${userDomain}\`)
      kind: Rule
      services:
        - name: nginx
          port: 80
    - match: Host(\`www.nginx.local.${userDomain}\`)
      kind: Rule
      services:
        - name: nginx
          port: 80
  tls:
    secretName: staging-tls
EOF
kubectl apply -f /${HOME}/cert-manager/nginx.yaml >>${logFile} 2>&1

read -p "[INPUT] Please verify nginx.local.${userDomain} is using staging certificate then press any key to continue... " -n1 -s
echo ""

echo "[TASK] Setup cluster issuer production"
cat >/${HOME}/cert-manager/clusterissuer-production.yaml<<EOF
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
  namespace: default
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${userEmail}
    privateKeySecretRef:
      name: letsencrypt-production
    solvers:
#    - http01:
#        ingress:
#          class: traefik-ingress
    - dns01:
        cloudflare:
          email: ${userEmail}
          apiTokenSecretRef:
            name: cloudflare-token-secret
            key: cloudflare-token
      selector:
        dnsZones:
          - "${userDomain}"
EOF
kubectl apply -f /${HOME}/cert-manager/clusterissuer-production.yaml >>${logFile} 2>&1

echo "[TASK] Setup default local certificate production"
cat >/${HOME}/cert-manager/certificate-production.yaml<<EOF
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: cert-production
  namespace: default
spec:
  secretName: production-tls
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
  commonName: "*.local.${userDomain}"
  dnsNames:
  - "local.${userDomain}"
  - "*.local.${userDomain}"
EOF
kubectl apply -f /${HOME}/cert-manager/certificate-production.yaml >>${logFile} 2>&1

echo "[TASK] Test production certificate for nginx service"
cp /${HOME}/cert-manager/nginx.yaml /${HOME}/cert-manager/nginx-ingressroute.yaml
yq -i 'select(documentIndex == 2)' /${HOME}/cert-manager/nginx-ingressroute.yaml
yq -i '.spec.tls.secretName="production-tls"' /${HOME}/cert-manager/nginx-ingressroute.yaml
kubectl apply -f /${HOME}/cert-manager/nginx-ingressroute.yaml >>${logFile} 2>&1

read -p "[INPUT] Please verify nginx.local.${userDomain} is using production certificate then press any key to continue... " -n1 -s
echo ""

echo "[TASK] Removing nginx test service"
kubectl delete -f /${HOME}/cert-manager/nginx.yaml >>${logFile} 2>&1
sed -i 's/nginx.local[^ ]*//g' /etc/hosts

echo "[TASK] Update /etc/hosts for traefik local DNS entry"
if grep -q "${externalIP}" /etc/hosts
then
if grep -q "traefik.local" /etc/hosts
then
sed -i "s/traefik.local/traefik.local.${userDomain}/g" /etc/hosts
else
sed -i "/^${externalIP}/ s/$/ traefik.local.${userDomain}/" /etc/hosts
fi
else
cat >>/etc/hosts<<EOF
${externalIP}   traefik.local.${userDomain}
EOF
fi

echo "[TASK] Setup traefik dashboard certificate staging"
cat >/${HOME}/cert-manager/traefik-certificate-staging.yaml<<EOF
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: traefik-cert-staging
  namespace: traefik
spec:
  secretName: traefik-staging-tls
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
  commonName: traefik.local.${userDomain}
  dnsNames:
  - traefik.local.${userDomain}
EOF
kubectl apply -f /${HOME}/cert-manager/traefik-certificate-staging.yaml >>${logFile} 2>&1

echo "[TASK] Update traefik dashboard with tls"
cp /${HOME}/traefik/traefik-dashboard.yaml /${HOME}/cert-manager/ >>${logFile} 2>&1
yq -i 'select(documentIndex == 2)' /${HOME}/cert-manager/traefik-dashboard.yaml
yq -i '.spec.routes[0].match="Host(`traefik.local.'${userDomain}'`) && (PathPrefix(`/dashboard`) || PathPrefix(`/api`))"' /${HOME}/cert-manager/traefik-dashboard.yaml
yq -i '.spec.tls.secretName="traefik-staging-tls"' /${HOME}/cert-manager/traefik-dashboard.yaml
#yq -s '"traefik-dashboard-" + $index' /${HOME}/cert-manager/traefik-dashboard.yaml
#yq -i '.spec.tls.secretName="traefik-dashboard-staging-tls"' /${HOME}/cert-manager/traefik-dashboard-2.yml
#yq m -x -d'*' /${HOME}/cert-manager/traefik-dashboard-0.yml /${HOME}/cert-manager/traefik-dashboard-1.yml
kubectl apply -f /${HOME}/cert-manager/traefik-dashboard.yaml >>${logFile} 2>&1

read -p "[INPUT] Please verify traefik.local.${userDomain} is using staging certificate then press any key to continue... " -n1 -s
echo ""

echo "[TASK] Setup traefik dashbaord certificate production"
cat >/${HOME}/cert-manager/traefik-certificate-production.yaml<<EOF
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: traefik-cert-production
  namespace: traefik
spec:
  secretName: traefik-production-tls
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
  commonName: traefik.local.${userDomain}
  dnsNames:
  - traefik.local.${userDomain}

EOF
kubectl apply -f /${HOME}/cert-manager/traefik-certificate-production.yaml >>${logFile} 2>&1

echo "[TASK] Update traefik dashboard with production tls"
yq -i '.spec.tls.secretName="traefik-production-tls"' /${HOME}/cert-manager/traefik-dashboard.yaml
kubectl apply -f /${HOME}/cert-manager/traefik-dashboard.yaml >>${logFile} 2>&1

echo "COMPLETE"
