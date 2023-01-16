# Multiapp

In this example we will deploy multiple containers from docker images hosted on hub.docker.com. The containers integrate together to form a single app. There is a client, server and database.

```
mkdir -p /${HOME}/multiapp
```

## Steps

1. **Client deployment**

Create the client deployment manifest
```
cat >/${HOME}/multiapp/client-deployment.yaml<<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multiapp-client
  namespace: default
spec:
  replicas: 1
  progressDeadlineSeconds: 600
  revisionHistoryLimit: 2
  strategy:
    type: Recreate
  selector:
    matchLabels:
      component: web
  template:
    metadata:
      labels:
        component: web
    spec:
      containers:
      - name: multiapp-client
        image: drdre08/multi-client
        ports:
          - containerPort: 30001
EOF
```
Apply the client deployment
```
kubectl apply -f /${HOME}/multiapp/client-deployment.yaml
```
Test the client deployment
```
kubectl get pods
kubectl describe pod client-deployment-xxxxxxx-xx
kubectl logs -f client-deployment-xxxxxxx-xx
kubectl port-forward client-deployment-xxxxxxx-xx 30001:30001
curl localhost:30001
```

2. **Client service**

Create client service manifest
```
cat >/${HOME}/multiapp/client-service.yaml<<EOF
---
apiVersion: v1
kind: Service
metadata:
  name: multiapp-client
  namespace: default
spec:
  type: ClusterIP
  selector:
    component: web
  ports:
  - port: 30001
    targetPort: 30001
EOF
```
Apply the client service
```
kubectl apply -f /${HOME}/multiapp/client-service.yaml
```
Test the client service
```
kubectl get svc
kubectl describe svc multiapp-client
kubectl port-forward svc/multiapp-client 30001
curl localhost:30001
```

3. **Create secret**
```
cat >/${HOME}/multiapp/postgres-secret.yaml<<EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: pgpassword
  namespace: default
type: Opaque
stringData:
  # Check how to add postgres secret manifest
  PGPASSWORD: 12345test
EOF
```
Apply the postgres secret
```
kubectl apply -f /${HOME}/multiapp/postgres-secret.yaml
kubectl get secrets
```

4. **Persistent volume**

```
cat >/${HOME}/multiapp/postgres-pvc.yaml<<EOF
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
```
Apply the postgres secret
```
kubectl apply -f /${HOME}/multiapp/postgres-pvc.yaml
kubectl get pv,pvc
```

5. **Postgres deployment**

```
cat >/${HOME}/multiapp/postgres-deployment.yaml<<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multiapp-postgres
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      component: multiapp-postgres
  template:
    metadata:
      labels:
        component: multiapp-postgres
    spec:
      volumes:
        - name: postgres-storage
          persistentVolumeClaim:
            claimName: postgres-pvc
      containers:
        - name: multiapp-postgres
          image: postgres
          ports:
            - containerPort: 5432
          volumeMounts:
            - name: postgres-storage
              mountPath: /var/lib/postgresql/data
              subPath: postgres
          env:
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: pgpassword
                  key: PGPASSWORD
EOF
```
Apply the postgres deployment
```
kubectl apply -f /${HOME}/multiapp/postgres-deployment.yaml
```
Test the deployment
```
kubectl get pods
kubectl describe pod postgres-deployment-xxxxx-xx
kubectl exec -it postgres-deployment-xxxxx-xx -- psql -U postgres
\l
\c postgres
\dt
\q
```

6. **Postgres service**

Create the service
```
cat >/${HOME}/multiapp/postgres-service.yaml<<EOF
---
apiVersion: v1
kind: Service
metadata:
  name: multiapp-postgres
spec:
  type: ClusterIP
  selector:
    component: multiapp-postgres
  ports:
    - port: 5432
      targetPort: 5432
EOF
```
Apply the service
```
kubectl apply -f /${HOME}/multiapp/postgres-service.yaml
kubectl get svc
```

7. **Server deployment**

Create the server deployment
```
cat >/${HOME}/multiapp/server-deployment.yaml<<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multiapp-server
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      component: server
  template:
    metadata:
      labels:
        component: server
    spec:
      containers:
        - name: multiapp-server
          image: drdre08/multi-server
          ports:
            - containerPort: 30002
          env:
            - name: PGUSER
              value: postgres
            - name: PGHOST
              value: multiapp-postgres
            - name: PGPORT
              value: "5432"
            - name: PGDATABASE
              value: postgres
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: pgpassword
                  key: PGPASSWORD
EOF
```
Apply the service
```
kubectl apply -f /${HOME}/multiapp/server-deployment.yaml
```
Test the server
```
kubectl get pods
kubectl port-forward server-deployment-xxxxxxx-xx 30002:30002
```

8. **Server service**
```
cat >/${HOME}/multiapp/server-service.yaml<<EOF
---
apiVersion: v1
kind: Service
metadata:
  name: multiapp-server
  namespace: default
spec:
  type: ClusterIP
  selector:
    component: server
  ports:
    - port: 30002
      targetPort: 30002
EOF
```
Apply the service
```
kubectl apply -f /${HOME}/multiapp/server-service.yaml
```
Test the service
```
kubectl get svc
kubectl port-forward svc/multiapp-server 30002
```

9. **Ingress route**

```
cat >/${HOME}/multiapp/ingressroute.yaml<<EOF
---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: multiapp-strip-prefix
  namespace: default
spec:
  stripPrefix:
    prefixes:
      - /api

---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: multiapp
  namespace: default
  annotations:
    kubernetes.io/ingress.class: traefik-external
    #traefik.ingress.kubernetes.io/router.entrypoints: websecure
    #traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(\`multiapp.local.${userDomain}\`)
      kind: Rule
      services:
        - name: multiapp-client
          port: 30001
    - match: Host(\`multiapp.local.${userDomain}\`) && PathPrefix(\`/api\`)
      kind: Rule
      middlewares:
        - name: multiapp-strip-prefix
      services:
        - name: multiapp-server
          port: 30002
  tls:
    secretName: production-tls
EOF
```
Apply the ingress route
```
kubectl apply -f /${HOME}/multiapp/ingressroute.yaml
kubectl get middleware
kubectl get ingressroute
```

10. **Setup DNS**

**Locally**
```
nano /etc/hosts
curl multiapp.local.${userDomain}
```

**Externally**
Add a DNS record
```
CNAME    multiapp     ${userDomain}
```

Wait for it to propigate, then
```
curl multiapp.${userDomain}
```

## Deletion
```
kubectl delete -f /${HOME}/multiapp/ingressroute.yaml
kubectl delete -f /${HOME}/multiapp/server-service.yaml
kubectl delete -f /${HOME}/multiapp/server-deployment.yaml
kubectl delete -f /${HOME}/multiapp/postgres-service.yaml
kubectl delete -f /${HOME}/multiapp/postgres-deployment.yaml
kubectl delete -f /${HOME}/multiapp/postgres-pvc.yaml
kubectl delete -f /${HOME}/multiapp/postgres-secret.yaml
kubectl delete -f /${HOME}/multiapp/client-service.yaml
kubectl delete -f /${HOME}/multiapp/client-deployment.yaml
```


Manual ingress
```
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: whoami
  namespace: whoami
  annotations:
    kubernetes.io/ingress.class: "traefik"
    cert-manager.io/issuer: le-clusterissuer-prod
spec:
  tls:
  - hosts:
    - whoami.mydomain.com
    secretName: whoami-cert-prod
  rules:
  - host: whoami.mydomain.com
    http:
      paths:
      - path: /
        backend:
          serviceName: whoami
          servicePort: 80
```