# Cert Manager
[cert-manager](https://cert-manager.io/docs/) adds certificates and certificate issuers as resource types in Kubernetes clusters, and simplifies the process of obtaining, renewing and using those certificates.

## Helpful resources
- [Just me and OpenSource](https://github.com/justmeandopensource/kubernetes)
- [metin-karakus](https://github.com/m-karakus/kubernetes/tree/master/yamls/certmanager/templates)
- [Cloud Versity](https://gitlab.com/cloud-versity/rancher-k3s-first-steps/-/tree/main/Certificate%20Manager%20(TLS%20Demo))
- [Techo Tim](https://github.com/techno-tim/launchpad/tree/master/kubernetes/traefik-cert-manager)
- [Alex Guedes](https://medium.com/@alexgued3s/how-to-easily-ish-471307f276a9)

[cer-manager v1.10.0](https://github.com/cert-manager/cert-manager/releases/tag/v1.10.1)
### [Installation](https://cert-manager.io/docs/installation/)
- Helm chart
- Manifest

#### Manifest
```
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.10.1/cert-manager.yaml
```

#### [Helm](https://cert-manager.io/docs/installation/helm/)
```
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm search repo jetstack/cert-manager --versions
helm show values jetstack/cert-manager --version 1.10.1 > /root/certmanager-values.yaml
nano /root/certmanager-values.yaml
```

YOU may need to specify the dns01-recursive-nameservers, podDnsPolicy, podDnsConfig & nameservers... see https://www.youtube.com/watch?v=G4CmbYL9UPg&ab_channel=TechnoTim

Ensure `installCRDs` is set to `true` then install cert-manager:
```
helm install cert-manager jetstack/cert-manager --version 1.10.1 --values /root/certmanager-values.yaml --namespace cert-manager --create-namespace
```
Check the changes
```
kubectl get namespace
kubectl -n cert-manager get all
kubectl get certificate
```

### Configuration

1. **Ensure traefik values correct**

    ```
    nano traefik-values.yaml
    ```
    To configure traefik to connect to a acme server add `additionalArguments` to the install values file. Ensure you update the url with the peddle url and the certificate resolver to letsencrypt.
    ```
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

    ```
    kubectl get crds | grep cert-manager
    ```

    Note if you want to use wildcard certificates then you will need to use a [dns01](https://cert-manager.io/docs/configuration/acme/dns01/) challenge. However [http01](https://cert-manager.io/docs/configuration/acme/http01/) challenges are easier to setup.

    **Staging:**
    ```
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
    ```
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

    ```
    kubectl get challenges
    ```

4. **Create ingress**

    If you have `traefik` installed then may setup the IngressRoute so traefik routes to the service.
    ```
    kubectl get endpoints
    kubectl get svc
    kubectl get ingressclass
    ```
    
    **Staging:**
    Example ingress for nginx controller.
    ```
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
    ```
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
    ```
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
    ```
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
    ```
    kubectl -n traefik get all
    ```

    **Local DNS**
    ```
    nano /etc/hosts
    ```

    **Public DNS**
    Create an A custom resource in DNS provider.

6. **Test**

    ```
    curl -Lk nginx.example.com
    ```
