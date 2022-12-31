#!/bin/bash
# chmod u+x install.sh

# REQUIREMENTS
# - helm (curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && chmod 700 get_helm.sh && ./get_helm.sh)
# - yq (wget https://github.com/mikefarah/yq/releases/download/v4.30.6/yq_linux_amd64.tar.gz -O - | tar xz && mv yq_linux_amd64 /usr/bin/yq)

# DEFINES - versions
traefikVer=2.9.6
traefikChartVer=20.8.0
# VARIABLE DEFINES
logFile="${HOME}/traefik/install.log"
#logFile="/dev/null"

mkdir -p /${HOME}/traefik

echo "[TASK] Add traefik helm repo"
helm repo add traefik https://traefik.github.io/charts >>${logFile} 2>&1
helm repo update >>${logFile} 2>&1

echo "[TASK] Get traefik values and alter"
#helm search repo traefik/traefik --versions
helm show values traefik/traefik --version ${traefikChartVer} > /${HOME}/traefik/traefik-values.yaml
yq -i '.globalArguments[0]="--global.checknewversion=false" | .globalArguments.[] style="double"' /${HOME}/traefik/traefik-values.yaml
yq -i '.globalArguments[1]="--global.sendanonymoususage=false" | .globalArguments.[] style="double"' /${HOME}/traefik/traefik-values.yaml
yq -i '.ingressRoute.dashboard.enabled=false' /${HOME}/traefik/traefik-values.yaml
yq -i '.additionalArguments += "--serversTransport.insecureSkipVerify=true" | .additionalArguments.[] style="double"' /${HOME}/traefik/traefik-values.yaml
yq -i '.additionalArguments += "--log.level=INFO" | .additionalArguments.[] style="double"' /${HOME}/traefik/traefik-values.yaml
yq -i '.ports.web.redirectTo="websecure"' /${HOME}/traefik/traefik-values.yaml
#yq -i '.service.spec.loadBalancerIP="192.168.0.240"' /${HOME}/traefik/traefik-values.yaml

echo "[TASK] Install traefik with helm"
helm install traefik traefik/traefik --version ${traefikChartVer} --values /${HOME}/traefik/traefik-values.yaml -n traefik --create-namespace >>${logFile} 2>&1

echo "[TASK] Update /etc/hosts for traefik DNS entry"
externalIP=$(kubectl -n traefik get svc traefik -o 'jsonpath={.status.loadBalancer.ingress[0].ip}')
cat >>/etc/hosts<<EOF
${externalIP}   traefik.local
EOF

echo "[TASK] Setup traefik dashboard ingress route"
echo "[INPUT] Please enter a dashboard username..."
read username
echo "[INPUT] Please enter a dashboard password..."
read password
secret=$(htpasswd -nb ${username} ${password} | base64 2>&1)
cat >/${HOME}/traefik/traefik-dashboard.yaml<<EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: traefik-dashboard-auth
  namespace: traefik
type: Opaque
data:
  users: ${secret}

---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: traefik-dashboard-basicauth
  namespace: traefik
spec:
  basicAuth:
    secret: traefik-dashboard-auth

---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: traefik-dashboard
  namespace: traefik
  annotations:
    kubernetes.io/ingress.class: traefik-external
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(\`traefik.local\`) && (PathPrefix(\`/dashboard\`) || PathPrefix(\`/api\`))
      kind: Rule
      middlewares:
        - name: traefik-dashboard-basicauth
          namespace: traefik
      services:
        - name: api@internal
          kind: TraefikService
EOF

echo "[TASK] Apply traefik dashboard ingress route"
kubectl apply -f /${HOME}/traefik/traefik-dashboard.yaml >>${logFile} 2>&1

echo "COMPLETE"
