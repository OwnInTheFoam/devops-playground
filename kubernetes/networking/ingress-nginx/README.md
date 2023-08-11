# Ingress nginx

Note this is not to get confused with nginx ingress controller.

## Resources
- [Github](https://github.com/kubernetes/ingress-nginx)
- 

## Installation

### Helm

### Flux
Get the latest helm chart version
```bash
helm search hub --max-col-width 80 ingress-nginx | grep "ingress-nginx/ingress-nginx"
export IN_VER="4.5.2"
export CLUSTER_REPO=gitops
```

Create the helm source
```bash
flux create source helm ingress-nginx \
  --url=https://kubernetes.github.io/ingress-nginx \
  --interval=1h \
  --export > "${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources/ingress-nginx.yaml"
```
Regenerate the kustomize manifest
```bash
cd ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/sources
rm -f kustomization.yaml
kustomize create --namespace="flux-system" --autodetect --recursive
```
Update the git repository
```bash
cd ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git commit -am "ingress-nginx create source helm"
git push
```
Reconcile flux system
```bash
flux reconcile source git "flux-system"
```

Configure values file
```bash
cat>${HOME}/tigase/${K8S_CONTEXT}/envs/nginx_values.yaml<<EOF
controller:
  service:
    annotations:
      service.beta.kubernetes.io/oci-load-balancer-shape: flexible
      service.beta.kubernetes.io/oci-load-balancer-shape-flex-min: 10
      service.beta.kubernetes.io/oci-load-balancer-shape-flex-max: 10
  config:
    use-proxy-protocol: "false"
    server-tokens: "false"
    enable-brotli: "true"
    use-forwarded-headers: "true"
  admissionWebhooks:
    timeoutSeconds: 30
  publishService:
    enabled: true
  extraArgs:
    update-status-on-shutdown: "false"
  updateStrategy:
    rollingUpdate:
      maxUnavailable: 1
    type: RollingUpdate
  ingressClassResource:
    enabled: true
    default: true
  replicaCount: 2
  metrics:
    enabled: false
    serviceMonitor:
      enabled: true
      additionalLabels:
        release: prometheus
    prometheusRule:
      enabled: true
      additionalLabels:
        release: prometheus
      rules:
        - alert: Ingress-NGINXConfigFailed
          expr: count(nginx_ingress_controller_config_last_reload_successful == 0) > 0
          for: 1s
          labels:
            severity: critical
          annotations:
            description: bad ingress config - nginx config test failed
            summary: uninstall the latest ingress changes to allow config reloads to resume
  resources:
    limits:
      cpu: 1
      memory: 1024Mi
    requests:
      cpu: 100m
      memory: 128Mi
EOF
```

Create helmrelease
```bash
mkdir -p ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/ingress-nginx
flux create helmrelease ingress-nginx \
	--interval=2h \
	--release-name=ingress-nginx \
	--source=HelmRepository/ingress-nginx \
	--chart-version=${IN_VER} \
	--chart=ingress-nginx \
	--namespace=flux-system \
	--target-namespace=ingress-nginx \
  --create-target-namespace \
  --values=${HOME}/tigase/${K8S_CONTEXT}/envs/nginx_values.yaml \
  --crds=CreateReplace \
  --export > ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/ingress-nginx/ingress-nginx/ingress-nginx.yaml
```
Update kustomize
```bash
cd ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/ingress-nginx/ingress-nginx
rm -f kustomization.yaml
kustomize create --autodetect --recursive

cd ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/ingress-nginx
rm -f kustomization.yaml
kustomize create --autodetect --recursive

cd ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}/infra/common/
rm -f kustomization.yaml
kustomize create --autodetect --recursive
```
Update git repository
```bash
cd ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git commit -am "ingress-nginx deployment"
git push
```
Flux reconcile
```bash
flux reconcile source git "flux-system"
```

Update git repository
```bash
cd ${HOME}/tigase/${K8S_CONTEXT}/projects/${CLUSTER_REPO}
git add -A
git commit -am "public-key deployment"
git push
```
Flux reconcile
```bash
flux reconcile source git "flux-system"
```

## Uninstall
```bash
rm -rf infra/common/ingress-nginx/
git commit -am "Removing ingress-nginx"
git push
flux reconcile source git flux-system
```

## Accessing deployments

### Port forwarding

_Below is for traefik. Is there a solution for ingress-nginx?_

You may access a deployment pod by forwaring the port locally:
```bash
kubectl -n traefik get all
kubectl port-forward -n traefik $(kubectl get pods -n traefik --selector "app.kubernetes.io/name=traefik" --output=name) 9000:9000
curl localhost:9000/dashboard/
```

### Ingress Routes

1. **Deploy nginx**

    ```bash
    sudo kubectl create deploy nginx --image nginx -n default
    ```

    Warning:
     would violate PodSecurity "restricted:latest":
      allowPrivilegeEscalation != false
      (container "nginx" must set securityContext.allowPrivilegeEscalation=false),
      unrestricted capabilities
      (container "nginx" must set securityContext.capabilities.drop=["ALL"]),
      runAsNonRoot != true
      (pod or container "nginx" must set securityContext.runAsNonRoot=true),
      seccompProfile
      (pod or container "nginx" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")

2. **Expose nginx**

    Shall expose these deployments as cluster ip services. Not necessary to expose as load balancer or nodeport as we are not going to access these services directly, we are going to access them via the ingress. Traefik ingress controller will route our requests to this service inside the cluster.
    ```bash
    kubectl get all
    sudo kubectl expose deploy nginx --port 80 -n default
    kubect get pods
    ```

3. **Create ingress route**

    ```bash
    sudo kubectl get svc -A
    ```
    Create your ingress route as a http web entrypoint that matches the host `nginx.example.com` as a rule to the service `nginx`.
    ```bash
    cat>$HOME/ingress.yaml<<EOF
    ---
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: nginx
      namespace: default
    spec:
      rules:
      - host: nginx.example.com
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx
                port:
                  number: 80
      ingressClassName: nginx
    EOF
    sudo kubectl apply -f $HOME/ingress.yaml
    sudo kubectl get Ingress -A
    sudo kubectl describe Ingress nginx
    ```

4. **Add DNS entry**

    ```bash
    sudo kubectl -n ingress-nginx get all
    ```
    Note the load balancer service running on an external ip. Add an entry to your DNS to resolve the traffic of a web address to the external IP address. This can be done two ways:
    - Locally via etc/hosts
      ```
      sudo nano /etc/hosts
      ```
    - Publically via domain DNS provider

5. **Test access**

    ```
    curl nginx.example.com
    curl -H "From: test@example.com" nginx.example.org
    ```

6. **Delete test deployment**

    ```bash
    sudo nano /etc/hosts
    sudo kubectl delete -f $HOME/ingress.yaml
    rm $HOME/ingress.yaml
    sudo kubectl delete deploy nginx -n default
    sudo kubectl delete svc nginx -n default
    ```

### [Middlewares](https://doc.traefik.io/traefik/middlewares/overview/)

_Below is for traefik. Is there a solution for ingress-nginx?_

1. **Add Prefix example**

    ```
    cat >middleware-addprefix.yaml<<EOF
    ---
    apiVersion: traefik.containo.us/v1alpha1
    kind: Middleware
    metadata:
      name: nginx-add-prefix
    spec:
      addPrefix:
        prefix: /hello

    ---
    apiVersion: traefik.containo.us/v1alpha1
    kind: IngressRoute
    metadata:
      name: nginx
      namespace: default
    spec:
      entryPoints:
        - web
      routes:
        - match: Host(\`nginx.example.com\`)
          kind: Rule
          services:
            - name: nginx-deploy-main
              port: 80
        - match: Host(\`nginx.example.org\`)
          kind: Rule
          middlewares:
            - name: nginx-add-prefix
          services:
            - name: nginx-deploy-main
              port: 80
    EOF
    kubectl apply -f middleware-addprefix.yaml
    kubectl get ingressroute
    kubectl get middleware
    kubectl describe ingressroute nginx
    kubectl logs -f nginx-deploy-main-xxxxxx-xxxx
    ```
    Notice the logs will indicate middleware applied the /hello path were applicable.
    ```
    curl nginx.example.com
    curl nginx.example.org
    ```

2. **Add strip prefix example**

    ```
    cat >middleware-stripprefix.yaml<<EOF
    ---
    apiVersion: traefik.containo.us/v1alpha1
    kind: Middleware
    metadata:
      name: nginx-strip-path-prefix
    spec:
      stripPrefix:
        prefixes:
          - /blue
          - /green

    ---
    apiVersion: traefik.containo.us/v1alpha1
    kind: IngressRoute
    metadata:
      name: nginx
      namespace: default
    spec:
      entryPoints:
        - web
      routes:
        - match: Host(\`nginx.example.com\`)
          kind: Rule
          services:
            - name: nginx-deploy-main
              port: 80
        - match: Host(\`nginx.example.com\`) && Path(\`/blue\`)
          kind: Rule
          middlewares:
            - name: nginx-strip-path-prefix
          services:
            - name: nginx-deploy-blue
              port: 80
        - match: Host(\`nginx.example.com\`) && Path(\`/green\`)
          kind: Rule
          middlewares:
            - name: nginx-strip-path-prefix
          services:
            - name: nginx-deploy-green
              port: 80
    EOF
    kubectl apply -f middleware-stripprefix.yaml
    kubectl get ingressroute
    kubectl get middleware
    kubectl describe ingressroute nginx
    ```
    Notice navigating to the prefix will drop the prefix and navigate to the correct pod.
    ```
    curl nginx.example.com/green
    curl nginx.example.com/blue
    ```

3. **Add redirect example**

    To use a redirect from web to websecure ensure tls certificates have been setup and update the certificate resolver to your acme server.
    ```
    cat >middleware-redirect.yaml<<EOF
    ---
    apiVersion: traefik.containo.us/v1alpha1
    kind: Middleware
    metadata:
      name: nginx-redirect-scheme
    spec:
      redirectScheme:
        scheme: https
        permanent: true
        port: "443"

    ---
    apiVersion: traefik.containo.us/v1alpha1
    kind: IngressRoute
    metadata:
      name: nginx-http
      namespace: default
    spec:
      entryPoints:
        - web
      routes:
        - match: Host(\`nginx.example.com\`)
          kind: Rule
          middlewares:
            - name: nginx-redirect-scheme
          services:
            - name: nginx-deploy-main
              port: 80

    ---
    apiVersion: traefik.containo.us/v1alpha1
    kind: IngressRoute
    metadata:
      name: nginx-https
      namespace: default
    spec:
      entryPoints:
        - websecure
      routes:
        - match: Host(\`nginx.example.com\`)
          kind: Rule
          services:
            - name: nginx-deploy-main
              port: 80
      tls:
        certResolver: letsencrypt
    EOF
    kubectl apply -f middleware-redirect.yaml
    kubectl get ingressroute
    kubectl get middleware
    kubectl describe ingressroute nginx
    curl http://nginx.example.com
    ```

3. **Add basic auth example**

    This shall encode a username and password with base64. Then add a secret with the encoded password. Then http request with the middleware wil ensure a correct username and password is supplied before routing to the deployment.
    ```
    cat >middleware-basicauth.yaml<<EOF
    ---
    apiVersion: traefik.containo.us/v1alpha1
    kind: Middleware
    metadata:
      name: nginx-basic-auth
    spec:
      basicAuth:
        secret: authsecret

    ---
    # Example:
    # apt install htpasswd
    #   htpasswd -nb yourusername yourpassword | base64
    #   eW91cnVzZXJuYW1lOiRhcHIxJE5qcmM3TU5mJElQQVgzVzNudTYucXBtRmd6ZXFvOC8KCg==

    apiVersion: v1
    kind: Secret
    metadata:
      name: authsecret

    data:
      users: |
        eW91cnVzZXJuYW1lOiRhcHIxJE5qcmM3TU5mJElQQVgzVzNudTYucXBtRmd6ZXFvOC8KCg==
    ---
    apiVersion: traefik.containo.us/v1alpha1
    kind: IngressRoute
    metadata:
      name: nginx
      namespace: default
    spec:
      entryPoints:
        - web
      routes:
        - match: Host(\`nginx.example.com\`)
          kind: Rule
          middlewares:
            - name: nginx-basic-auth
          services:
            - name: nginx-deploy-main
              port: 80
    EOF
    ```
    Create your base64 encrypted username and password:
    ```
    htpasswd -nb yourusername yourpassword | base64
    ```
    Then add the encryption key to the secret, before applying the configuration:
    ```
    nano middleware-basicauth.yaml
    kubectl apply -f middleware-basicauth.yaml
    kubectl get ingressroute
    kubectl get middleware
    kubectl describe ingressroute nginx
    kubectl logs -f nginx-deploy-main-xxxxxx-xxxx
    ```

### Round robbin?

  _Below is for traefik. Is there a solution for ingress-nginx?_

1. **Configuration**

    ```
    cat >traefik-roundrobbin.yaml<<EOF
    ---
    apiVersion: traefik.containo.us/v1alpha1
    kind: TraefikService
    metadata:
      name: nginx-wrr
      namespace: default
    spec:
      weighted:
        services:
          - name: nginx-deploy-main
            port: 80
            weight: 1
          - name: nginx-deploy-blue
            port: 80
            weight: 1
          - name: nginx-deploy-green
            port: 80
            weight: 1

    ---
    apiVersion: traefik.containo.us/v1alpha1
    kind: IngressRoute
    metadata:
      name: nginx
      namespace: default
    spec:
      entryPoints:
        - web
      routes:
      - match: Host(\`nginx.example.com\`)
        kind: Rule
        services:
        - name: nginx-wrr
          kind: TraefikService
    EOF
    kubectl apply -f traefik-roundrobbin.yaml
    ```

2. **Test round robbin**

    Continually navigate to the url and the weighted round robbin should direct to the best available service.
    ```
    curl http://nginx.example.com
    ```
    