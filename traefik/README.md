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
