# Rancher demo

This will install a docker hub [image](https://hub.docker.com/r/monachus/rancher-demo) application for deployment on kubernetes.

## Steps
Create a rancher-demo manifest.
```
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rancher-demo
  namespace: default
  labels:
    app: rancher-demo
spec:
  replicas: 3
  progressDeadlineSeconds: 600
  revisionHistoryLimit: 2
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: rancher-demo
  template:
    metadata:
      labels:
        app: rancher-demo
    spec:
      containers:
      - name: rancher-demo
        image: monachus/rancher-demo:latest
---
apiVersion: v1
kind: Service
metadata:
  name: rancher-demo
  namespace: default
spec:
  selector:
    app: rancher-demo
  ports:
  - name: http
    targetPort: 8080
    port: 8080
---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: rancher-demo
  namespace: default
  annotations:
    kubernetes.io/ingress.class: traefik-external
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`demo.local.${userDomain}`)
      kind: Rule
      services:
        - name: rancher-demo
          port: 8080
  tls:
    secretName: production-tls
```

Apply the application
```
kubectl apply -f /${HOME}/rancher-demo/rancher-demo.yaml
```

Update the DNS
```
nano /etc/hosts
```
Add an entry to the metalLB external port for the domain
```
xxx.xxx.xx.xxx     demo.local.${userDomain}
```

Test the application
```
demo.local.${userDomain}
```

Delete the demo application
```
kubectl delete -f /${HOME}/rancher-demo/rancher-demo.yaml
```