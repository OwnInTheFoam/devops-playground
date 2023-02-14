# Cert Manager
[cert-manager](https://cert-manager.io/docs/) adds certificates and certificate issuers as resource types in Kubernetes clusters, and simplifies the process of obtaining, renewing and using those certificates.

## Helpful resources
- [Just me and OpenSource](https://github.com/justmeandopensource/kubernetes)
- [metin-karakus](https://github.com/m-karakus/kubernetes/tree/master/yamls/certmanager/templates)
- [Cloud Versity](https://gitlab.com/cloud-versity/rancher-k3s-first-steps/-/tree/main/Certificate%20Manager%20(TLS%20Demo))
- [Techo Tim](https://github.com/techno-tim/launchpad/tree/master/kubernetes/traefik-cert-manager)
- [Alex Guedes](https://medium.com/@alexgued3s/how-to-easily-ish-471307f276a9)

[cer-manager v1.10.0](https://github.com/cert-manager/cert-manager/releases/tag/v1.10.1)

## cmctl [command line tool](https://cert-manager.io/docs/reference/cmctl/)

### Installation
```bash
curl -fsSL -o cmctl.tar.gz https://github.com/cert-manager/cert-manager/releases/latest/download/cmctl-linux-amd64.tar.gz
tar xzf cmctl.tar.gz
sudo mv cmctl /usr/local/bin
rm -r cmctl.tar.gz
rm -r LICENSE
cmctl version --short
```

## [Installation](https://cert-manager.io/docs/installation/)
- Helm chart
- Manifest

### Manifest
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.10.1/cert-manager.yaml
```

### [Helm](https://cert-manager.io/docs/installation/helm/)
```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm search repo jetstack/cert-manager --versions
helm show values jetstack/cert-manager --version 1.10.1 > /root/certmanager-values.yaml
nano /root/certmanager-values.yaml
```

YOU may need to specify the dns01-recursive-nameservers, podDnsPolicy, podDnsConfig & nameservers... see https://www.youtube.com/watch?v=G4CmbYL9UPg&ab_channel=TechnoTim

Ensure `installCRDs` is set to `true` then install cert-manager:
```bash
helm install cert-manager jetstack/cert-manager --version 1.10.1 --values /root/certmanager-values.yaml --namespace cert-manager --create-namespace
```
Check the changes
```bash
kubectl get namespace
kubectl -n cert-manager get all
kubectl get certificate
cmctl check api
```

## Configuration

1. **Ensure traefik values correct**

    ```bash
    nano traefik-values.yaml
    ```
    To configure traefik to connect to a acme server add `additionalArguments` to the install values file. Ensure you update the url with the peddle url and the certificate resolver to letsencrypt.
    ```bash
    ...
    additionalArguments:
      - --certificatesresolvers.letsencrypt.acme.tlschallenge=true
      - --certificatesresolvers.letsencrypt.acme.email=test@hello.com
      - --certificatesresolvers.letsencrypt.acme.storage=/data/acme.json
      - --certificatesresolvers.letsencrypt.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory


    # Lets Encrypt servers

    # Staging
    # https://acme-staging-v02.api.letsencrypt.org/directory

    # Production Lets Encrypt
    # https://acme-v02.api.letsencrypt.org/directory
    ...
    ```

2. **Create a cluster issuer for ssl.**

    ```bash
    kubectl get crds | grep cert-manager
    ```

    Note if you want to use wildcard certificates then you will need to use a [dns01](https://cert-manager.io/docs/configuration/acme/dns01/) challenge. However [http01](https://cert-manager.io/docs/configuration/acme/http01/) challenges are easier to setup.

    **Staging:**
    ```bash
    cat >certmanager-clusterissuer-staging.yaml<<EOF
    ---
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-staging
    spec:
      acme:
        email: youremail@example.com
        server: https://acme-staging-v02.api.letsencrypt.org/directory
        privateKeySecretRef:
          name: letsencrypt-staging
        solvers:
        - http01:
            ingress:
              class: traefik
    #    - dns01: to use a public dns ie cloudflare
    EOF
    kubectl apply -f certmanager-clusterissuer-staging.yaml
    ```

    **Production:**
    ```bash
    cat >certmanager-clusterissuer-production.yaml<<EOF
    ---
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-production
    spec:
      acme:
        email: youremail@example.com
        server: https://acme-v02.api.letsencrypt.org/directory
        privateKeySecretRef:
          name: letsencrypt-production
        solvers:
    #    -dns01: to use a public dns ie cloudflare
        - http01:
            ingress:
              class: traefik
    EOF
    kubectl apply -f certmanager-clusterissuer-production.yaml
    ```

3. **Create certificates??**

    https://www.youtube.com/watch?v=G4CmbYL9UPg&ab_channel=TechnoTim
    https://gitlab.com/cloud-versity/rancher-k3s-first-steps/-/blob/main/Certificate%20Manager%20(TLS%20Demo)/certificate-staging.yaml

    Note the namespace must match the namespace that the service is within!

    ```bash
    kubectl get challenges
    ```

4. **Create ingress**

    If you have `traefik` installed then may setup the IngressRoute so traefik routes to the service.
    ```bash
    kubectl get endpoints
    kubectl get svc
    kubectl get ingressclass
    ```
    
    **Staging:**
    Example ingress for nginx controller.
    ```bash
    cat >certmanager-ingress-staging.yaml<<EOF
    ---
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: ingress-resource
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-staging
    spec:
      ingressClassName: nginx
      tls:
      - hosts:
        - nginx.example.com
        secretName: letsencrypt-staging
      rules:
      - host: nginx.example.com
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-deploy-main
                port:
                  number: 80
    EOF
    kubectl apply -f certmanager-ingress-staging.yaml
    kubectl get ingress
    kubectl describe ingress nginx
    ```
    
    Example ingress for traefik.
    ```bash
    cat >certmanager-ingressroute-staging.yaml<<EOF
    ---
    apiVersion: traefik.containo.us/v1alpha1
    kind: IngressRoute
    metadata:
      name: nginx
      namespace: default
      annotations:
        kubernetes.io/ingress-class: traefik
    #    cert-manager.io/cluster-issuer: letsencrypt-staging
    spec:
      entryPoints:
        - websecure
      routes:
        - match: Host(\`nginx.example.com\`) || (Host(\`nginx.example.org\`) && Headers(\`From\`, \`test@example.com\`)) || (Host(\`nginx.example.io\`) && HeadersRegexp(\`From\`, \`.*example.*\`))
          kind: Rule
          services:
            - name: nginx-deploy-main
              port: 80
      tls:
        certResolver: letsencrypt-staging
    EOF
    kubectl apply -f certmanager-ingressroute-staging.yaml
    kubectl get ingressroute
    kubectl describe ingressroute nginx
    ```

    **Production:**
    Example ingress for nginx controller.
    ```bash
    cat >certmanager-ingress-production.yaml<<EOF
    ---
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: ingress-resource
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-production
    spec:
      ingressClassName: nginx
      tls:
      - hosts:
        - nginx.example.com
        secretName: letsencrypt-production
      rules:
      - host: nginx.example.com
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-deploy-main
                port:
                  number: 80
    EOF
    kubectl apply -f certmanager-ingress-production.yaml
    kubectl get ingress
    kubectl describe ingress nginx
    ```
    
    Example ingress for traefik.
    ```bash
    cat >certmanager-ingressroute-production.yaml<<EOF
    ---
    apiVersion: traefik.containo.us/v1alpha1
    kind: IngressRoute
    metadata:
      name: nginx
      namespace: default
      annotations:
        kubernetes.io/ingress-class: traefik
    #    cert-manager.io/cluster-issuer: letsencrypt-production
    spec:
      entryPoints:
        - websecure
      routes:
        - match: Host(\`nginx.example.com\`) || (Host(\`nginx.example.org\`) && Headers(\`From\`, \`test@example.com\`)) || (Host(\`nginx.example.io\`) && HeadersRegexp(\`From\`, \`.*example.*\`))
          kind: Rule
          services:
            - name: nginx-deploy-main
              port: 80
      tls:
        certResolver: letsencrypt-production
    EOF
    kubectl apply -f certmanager-ingressroute-production.yaml
    kubectl get ingressroute
    kubectl describe ingressroute nginx
    ```

5. **DNS host entry**

    Ensure your domain resolves to your ingress controller external IP address
    ```bash
    kubectl -n traefik get all
    ```

    **Local DNS**
    ```bash
    nano /etc/hosts
    ```

    **Public DNS**
    Create an A custom resource in DNS provider.

6. **Test**

    ```bash
    curl -Lk nginx.example.com
    ```

## FluxCD
See [Tigase](https://github.com/tigase/k8s-scripts)
Note altered to use cloudflare dns01 challenge

Create helm repository manifest file and update the repository.
```bash
flux create source helm cert-manager \
  --url="https://charts.jetstack.io" \
  --interval=2h \
  --export > "/${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/sources/cert-manager.yaml"

cd /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/sources/
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

cd /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops
git add -A
git commit -am "cert-manager deployment"
git push
flux reconcile source git "flux-system"
```

Create helm release
```bash
mkdir -p /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/cert-manager
mkdir -p /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/cert-manager/cert-manager

cat >/${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/cert-manager/namespace.yaml<<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
EOF

flux create helmrelease cert-manager \
	--interval=2h \
	--release-name=cert-manager \
	--source=HelmRepository/cert-manager \
	--chart-version=1.4.0 \
	--chart=cert-manager \
	--namespace=flux-system \
	--target-namespace=cert-manager \
  --values=/${HOME}/tigase/${K8S_CONTEXT}/envs/cert-man_values.yaml \
  --create-target-namespace \
  --crds=CreateReplace \
  --export > /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/cert-manager/cert-manager/cert-manager.yaml
```

Update kustomize manifests
```bash
cd /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/cert-manager/cert-manager/
rm -f kustomization.yaml
kustomize create --autodetect --recursive

cd /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/cert-manager/
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive

cd /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/
rm -f kustomization.yaml
kustomize create --autodetect --recursive
```

Update repository
```bash
yq e -i '.spec.chart.spec.sourceRef.namespace = "flux-system"' /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/cert-manager/cert-manager/cert-manager.yaml

git add -A
git commit -am "cert-manager deployment"
git push
flux reconcile source git "flux-system"
```

Create http01 issuer's
```bash
SSL_EMAIL=yourEmail;
CLOUDFLARE_DOMAIN=yourDomain;
CLOUDFLARE_SECRET_KEY=yourCloudflareToken;

cat > "/${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/cert-manager/cert-manager/issuer-staging.yaml" <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
  namespace: default
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ${SSL_EMAIL}
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
      - http01:
          ingress:
            class: nginx
EOF

cat > "/${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/cert-manager/cert-manager/issuer-production.yaml" <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
  namespace: default
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${SSL_EMAIL}
    privateKeySecretRef:
      name: letsencrypt
    solvers:
      - http01:
          ingress:
            class: nginx
EOF
```

Create dns01 issuer's
```bash
cat > "/${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/cert-manager/cert-manager/issuer-staging-dns.yaml" <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging-dns
  namespace: default
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ${SSL_EMAIL}
    privateKeySecretRef:
      name: letsencrypt-staging-dns
    solvers:
      - dns01:
          cloudflare:
            email: ${SSL_EMAIL}
            apiTokenSecretRef:
              name: cloudflare-token-secret
              key: cloudflare-token
        selector:
          dnsZones:
            - "${CLOUDFLARE_DOMAIN}"
EOF

cat > "/${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/cert-manager/cert-manager/issuer-production-dns.yaml" <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns
  namespace: default
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${SSL_EMAIL}
    privateKeySecretRef:
      name: letsencrypt-dns
    solvers:
      - dns01:
          cloudflare:
            email: ${SSL_EMAIL}
            apiTokenSecretRef:
              name: cloudflare-token-secret
              key: cloudflare-token
        selector:
          dnsZones:
            - "${CLOUDFLARE_DOMAIN}"
EOF
```

Setup dns solver secrets
```bash
#cat >/${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/cert-manager/cert-manager/cloudflare-token-secret.yaml<<EOF
#---
#apiVersion: v1
#kind: Secret
#metadata:
#  name: cloudflare-token-secret
#  namespace: cert-manager
#type: Opaque
#stringData:
#  # Generate an API token and NOT a global API key https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/#api-tokens
#  cloudflare-token: ${CLOUDFLARE_SECRET_KEY}
#EOF

kubectl create secret generic "cloudflare-token-secret" \
  --namespace "cert-manager" \
  --from-literal=cloudflare-token="${CLOUDFLARE_SECRET_KEY}" \
  --dry-run=client -o yaml | kubeseal --cert="pub-sealed-secrets-cluster0.pem" \
  --format=yaml > "/${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/cert-manager/cert-manager/cloudflare-solver-secret.yaml"

kubectl apply -f "/${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/cert-manager/cert-manager/cloudflare-token-secret.yaml"
```

```bash
cd /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/cert-manager/cert-manager
rm -f kustomization.yaml
kustomize create --autodetect --recursive

git add -A
git commit -am "cert-manager deployment"
git push
flux reconcile source git "flux-system"

cmctl check api
kubectl get clusterissuer -A
kubectl logs pod/cert-manager-cc4b776cf-zbljp -n cert-manager -f
```

**Adding domain certificates**
Staging
```bash
cat >/${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/cert-manager/cert-manager/certificate-staging-${CLOUDFLARE_DOMAIN}.yaml<<EOF
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: certificate-staging-${CLOUDFLARE_DOMAIN}
  namespace: default
spec:
  secretName: ${CLOUDFLARE_DOMAIN}-staging-tls
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
  commonName: "*.local.${CLOUDFLARE_DOMAIN}"
  dnsNames:
  - "local.${CLOUDFLARE_DOMAIN}"
  - "*.local.${CLOUDFLARE_DOMAIN}"
EOF

#kubectl apply -f /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/cert-manager/cert-manager/certificate-staging-${CLOUDFLARE_DOMAIN}.yaml
```

Production
```bash
cat >/${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/cert-manager/cert-manager/certificate-${CLOUDFLARE_DOMAIN}.yaml<<EOF
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: certificate-${CLOUDFLARE_DOMAIN}
  namespace: default
spec:
  secretName: ${CLOUDFLARE_DOMAIN}-tls
  issuerRef:
    name: letsencrypt-dns
    kind: ClusterIssuer
  commonName: "*.${CLOUDFLARE_DOMAIN}"
  dnsNames:
  - "${CLOUDFLARE_DOMAIN}"
  - "*.${CLOUDFLARE_DOMAIN}"
EOF

#kubectl apply -f /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/cert-manager/cert-manager/certificate-${CLOUDFLARE_DOMAIN}.yaml
```

Update repository
```bash
cd /${HOME}/tigase/${K8S_CONTEXT}/projects/gitops/infra/common/cert-manager/cert-manager
rm -f kustomization.yaml
kustomize create --autodetect --recursive

git add -A
git commit -am "cert-manager deployment"
git push
flux reconcile source git "flux-system"

cmctl check api
kubectl get clusterissuer -A
kubectl logs pod/cert-manager-cc4b776cf-zbljp -n cert-manager -f
```

To watch the certificate status
```bash
kubectl get certificates -A -w
kubectl get order -A -w
kubectl describe order ${CLOUDFLARE_DOMAIN}-kjcrg-1627368428
kubectl get pods -n cert-manager
kubectl logs cert-manager-xxxxxxx -n cert-manager
```

**Testing**
Update /etc/hosts for local DNS entry
```bash
kubectl get svc -n ingress-nginx -o wide
cat >>/etc/hosts<<EOF
${externalIP}   nginx.local.${userDomain}
EOF
```
Test staging certificate for nginx service
```bash
cat >/${HOME}/tigase/${K8S_CONTEXT}/tmp/nginx.yaml<<EOF
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
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx
  namespace: default
  annotations:
    kubernetes.io/ingress.class: "nginx"
spec:
  rules:
  - host: nginx.local.${DOMAIN}
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: nginx
            port:
              number: 80
  tls:
    secretName: ${DOMAIN}-tls
EOF
kubectl apply -f /${HOME}/tigase/${K8S_CONTEXT}/tmp/nginx.yaml
```

**Uninstallation**

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
Delete secret
```bash
kubectl delete secret "route53-secret"
```
