# Pebbles
[Pebbles](https://github.com/letsencrypt/pebble) is a small ACME test server not suited for use as a production CA.


## Tutorial One
[Pebble v2.3.1](https://github.com/letsencrypt/pebble/releases/tag/v2.3.1) by [Just me and OpenSource](https://github.com/justmeandopensource/kubernetes)

### Installation
To install pebble, use a helm chart created by [jupyterhub](https://github.com/jupyterhub/pebble-helm-chart)
```
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo update
helm search repo jupyterhub/pebble --versions
helm show values jupyterhub/pebble --version 1.0.1 > /root/pebble-values.yaml
nano /root/pebble-values.yaml
```
Ensure `PEBBLE_VA_ALWAYS_VALID` is set to `"1"` and `coredns` is `false`. This will able pebble to skip the identity validation when retrieving the certificates.
```
helm install pebble jupyterhub/pebble --version 1.0.1 --values /root/pebble-values.yaml -n traefik
```
Note you ACME server url I.e `https://pebble.traefik/dir` and `configMap` command I.e `kubectl get configmap/pebble -o jsonpath="{.data['root-cert\.pem']}"`
```
kubectl -n traefik get pods
kubectl -n traefik get svc
kubectl -n traefik get cm
kubectl -n traefik get cm pebble -o yaml
```

### Configuration
Add volume storage to traefik with the pebble configmap and configure traefik to use the certificates when connecting to the pebble acme server.

1. **Update traefik values**

    ```
    nano traefik-values.yaml
    ```
    To configure traefik to connect to a acme server add `additionalArguments` to the install values file. Ensure you update the url with the peddle url and the certificate resolver to pebble.
    ```
    ...
    additionalArguments:
      - --certificatesresolvers.pebble.acme.tlschallenge=true
      - --certificatesresolvers.pebble.acme.email=test@hello.com
      - --certificatesresolvers.pebble.acme.storage=/data/acme.json
      - --certificatesresolvers.pebble.acme.caserver=https://pebble.traefik/dir


    # Lets Encrypt servers

    # Staging
    # https://acme-staging-v02.api.letsencrypt.org/directory

    # Production Lets Encrypt
    # https://acme-v02.api.letsencrypt.org/directory
    ...
    ```
    To configure traefik to store the certificates in the persistant volume:
    ```
    ...
    volumes:
      - name: pebble
        mountPath: "/certs"
        type: configMap
    ...
    ```
    To configue traefik to use the certificates server, add to the environment variables:
    ```
    ...
    env:
      - name: LEGO_CA_CERTIFICATES
        value: "/certs/root-cert.pem"
    ...
    ```

2. **Upgrade helm repositories**

    ```
    helm repo update
    helm list -n traefik
    helm upgrade --install traefik traefik/traefik --version 20.8.0 --values /root/traefik-values.yaml -n traefik
    kubectl -n traefik get pods
    ```

3. **Create ingress route**

    ```
    kubectl get all
    ```
    ```
    cat >tls-ingress-route.yaml<<EOF
    ---
    apiVersion: traefik.containo.us/v1alpha1
    kind: IngressRoute
    metadata:
      name: nginx
      namespace: default
    spec:
      entryPoints:
        - websecure
      routes:
        - match: Host(\`nginx.example.com\`, \`nginx.example.org\`)
          kind: Rule
          services:
            - name: nginx-deploy-main
              port: 80
      tls:
        certResolver: pebble
    EOF
    kubectl apply -f tls-ingress-route.yaml
    kubectl get ingressroute
    ```
    Ensure your DNS is setup to resolve to your domain
    ```
    kubectl -n traefik get svc
    kubectl nano /etc/hosts
    ```

4. **Test mount volume**

    ```
    kubectl -n traefik get cm pebble -o yaml
    kubectl -n traefik exec -it traefik-xxxxxxxx-xxxx -- sh
    cd certs/
    ls
    ```