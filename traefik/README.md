# Traefik
[Traefik](https://doc.traefik.io/traefik/) is a ingress controller for kubernetes.

Traefik needs a dynamic persistant storage volume provision. To allow traefik to integrate and manage certificates it will need a volume to store them on. Without this setup, traefik will store the certificate on a temporary volume and it will lose access to them on server reboot.

Traefik default entry ports
- 9000: traefik
- 8080: web
- 8443: websecure
- 9100: metrics

### Tutorial One
[Traefik v2.9.6](https://github.com/traefik/traefik/releases/tag/v2.9.6) by [Just me and OpenSource](https://github.com/justmeandopensource/kubernetes)

#### [Requirements](https://doc.traefik.io/traefik/getting-started/install-traefik/)
- Kubernetes v1.16+ cluster
- Storage provisioning for SSL certificates
- Entrypoint load balancer (MetalLB or cloud provider load balancer)

### [Installation](https://doc.traefik.io/traefik/getting-started/install-traefik/)
- Helm chart
- Docker image
- Binary release

1. **Helm installation**

    ```
    helm repo add traefik https://traefik.github.io/charts
    helm repo update
    helm search repo traefik/traefik --versions
    helm show values traefik/traefik --version 20.8.0 > /root/traefik-values.yaml
    nano /root/traefik-values.yaml
    ```
    Update the values to include a persisent volume. Also if your storage class is not default then specify the name of the storage class as well.
    ```
    ...
    persistence:
      enabled: true
      ...
      storageClass: managed-nfs-storage
    ...
    Deploy traefik with helm
    ```
    helm install traefik traefik/traefik --version 20.8.0 --values /root/traefik-values.yaml -n traefik --create-namespace
    helm list -n traefik
    kubectl -n traefik get all
    ```
    Traefik should be deployed on the first IP address handed out from metalLB.

### Accessing deployments

#### Port forwarding

You may access a deployment pod by forwaring the port locally:
```
kubectl -n traefik get all
kubectl -n traefik port-forward pod/traefik-f984cb844-4sp22 9000:9000
localhost:9000/dashboard/
```

#### Ingress Routes

1. **Deploy nginx**

    ```
    kubectl deploy nginx --image nginx
    ```

2. **Expose nginx**

    Shall expose these deployments as cluster ip services. Not necessary to expose as load balancer or nodeport as we are not going to access these services directly, we are going to access them via the ingress. Traefik ingress controller will route our requests to this service inside the cluster.
    ```
    kubectl get all
    kubectl expose deploy nignx --port 80
    kubect get pods
    ```

3. **Create ingress route**

    ```
    kubectl get svc
    ```
    Create your ingress route as a http web entrypoint that matches the host `nginx.example.com` as a [rule](https://doc.traefik.io/traefik/v2.9/routing/routers/#rule) to the service `nginx`.
    ```
    cat >/root/ingress-route.yaml<<EOF
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
        - match: Host(\`nginx.example.com\`) || (Host(\`nginx.example.org\`) && Headers(\`From\`, \`test@example.com\`)) || (Host(\`nginx.example.io\`) && HeadersRegexp(\`From\`, \`.*example.*\`))
          kind: Rule
          services:
            - name: nginx
              port: 80
        # uncomment following to add another rule to a DIFFERENT service
        #- match: 
        #  kind: Rule
        #  services:
        #    - name: nginx1
        #      port: 80
    EOF
    kubectl apply -f ingress-route.yaml
    kubectl get ingressroutes
    kubectl describe ingressroute nginx
    ```

4. **Add DNS entry**

    ```
    kubectl -n traefik get all
    ```
    Note the traefik load balancer service running on an external ip. Add an entry to your DNS to resolve the traffic of a web address to the external IP address. This can be done two ways:
    - Locally via etc/hosts
      ```
      nano /etc/hosts
      ```
    - Publically via domain DNS provider

5. **Test access**

    ```
    curl nginx.example.com
    curl -H "From: test@example.com" nginx.example.org
    ```
#### [Middlewares](https://doc.traefik.io/traefik/middlewares/overview/)

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

#### [Traefik dashboard](https://doc.traefik.io/traefik/getting-started/install-traefik/#exposing-the-traefik-dashboard) ingress route

1. **Create ingressrote**

    ```
    cat >traefik-dashboard.yaml<<EOF
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
    kind: Middleware
    metadata:
      name: nginx-basic-auth
    spec:
      basicAuth:
        secret: authsecret

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
        - match: Host(\`traefik.local\`) && (PathPrefix(\`/dashboard\`) || PathPrefix(\`/api\`))
          kind: Rule
          middlewares:
            - name: nginx-redirect-scheme
          services:
            - name: api@internal
              kind: TraefikService

    ---
    apiVersion: traefik.containo.us/v1alpha1
    kind: IngressRoute
    metadata:
      name: dashboard
    spec:
      entryPoints:
        - websecure
      routes:
        - match: Host(\`traefik.local\`) && (PathPrefix(\`/dashboard\`) || PathPrefix(\`/api\`))
          kind: Rule
          middlewares:
            - name: nginx-basic-auth
          services:
            - name: api@internal
              kind: TraefikService
      tls:
        certResolver: pebble
    EOF
    nano traefik-dashboard.yaml
    htpasswd -nb yourusername yourpassword | base64
    kubectl apply -f traefik-dashboard.yaml
    kubectl get ingressroute
    kubectl get secret
    kubectl get middleware
    kubectl describe ingressroute dashboard
    ```

2. **Dashboard DNS entry**

    ```
    kubectl -n traefik get svc
    nano /etc/hosts
    ```
    ```
    ...
    traefik-external-ip   traefik.local
    ...
    ```

#### Traefik round robbin

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
    