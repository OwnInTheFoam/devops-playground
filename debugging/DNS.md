# CoreDNS
https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/

```
mkdir -p ${HOME}/debugging
```

Create test pod
```
cat >> ${HOME}/debugging/dnsutils.yaml<<EOF
apiVersion: v1
kind: Pod
metadata:
  name: dnsutils
  namespace: default
spec:
  containers:
  - name: dnsutils
    image: registry.k8s.io/e2e-test-images/jessie-dnsutils:1.3
    command:
      - sleep
      - "infinity"
    imagePullPolicy: IfNotPresent
  restartPolicy: Always
EOF

kubectl apply -f ${HOME}/debugging/dnsutils.yaml
```

Verify pod status
```
kubectl get pods dnsutils
```

Execute a nslookup
```
kubectl exec -i -t dnsutils -- nslookup kubernetes.default
```
Should output similar:
```
Server:    10.0.0.10
Address 1: 10.0.0.10

Name:      kubernetes.default
Address 1: 10.0.0.1
```

If it fails the check local DNS configuration:
```
kubectl exec -ti dnsutils -- cat /etc/resolv.conf
```
Should output similar:
```
search default.svc.cluster.local svc.cluster.local cluster.local google.internal c.gce_project_id.internal
nameserver 10.0.0.10
options ndots:5
```

Ensure dns pod is running:
```
kubectl get pods --namespace=kube-system -l k8s-app=kube-dns
```
Should output similar:
```
NAME                       READY     STATUS    RESTARTS   AGE
...
coredns-7b96bf9f76-5hsxb   1/1       Running   0           1h
coredns-7b96bf9f76-mvmmt   1/1       Running   0           1h
...
```

Check errors in dns pod
```
kubectl get svc --namespace=kube-system
kubectl logs --namespace=kube-system -l k8s-app=kube-dns
```


[ERROR] plugin/errors: 2 acme-staging-v02.api.letsencrypt.org. A: read udp 192.168.9.91:45394->192.168.0.1:53: i/o timeout
[ERROR] plugin/errors: 2 acme-staging-v02.api.letsencrypt.org. AAAA: read udp 192.168.9.91:38382->192.168.0.1:53: i/o timeout
[ERROR] plugin/errors: 2 acme-staging-v02.api.letsencrypt.org.gateway. A: read udp 192.168.9.91:51120->192.168.0.1:53: i/o timeout
[ERROR] plugin/errors: 2 acme-staging-v02.api.letsencrypt.org. A: dial udp [ff88::ee33:ddff:ccc5:b79e%2]:53: connect: network is unreachable

Are DNS endpoints exposed:
```
kubectl get endpoints kube-dns --namespace=kube-system
```

```
kubectl -n kube-system edit configmap coredns
```

Delete test dns pod:
```
kubectl delete -f ${HOME}/debugging/dnsutils.yaml
```

# Certificates

```
kubectl -n cert-manager get clusterissuer
kubectl get challenges
kubectl logs -n cert-manager -f $(kubectl -n cert-manager get pods --selector "app.kubernetes.io/name=cert-manager" --output=name)
kubectl describe challenge tls-production
```

