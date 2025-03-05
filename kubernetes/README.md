# Kubernetes

## Commands
[Cheatsheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

- **Get Resource**

```
kubectl get namespaces
kubectl get pods -A -w
kubectl get svc -A
```

- **Resource creation**

```
kubectl apply -f manifest.yaml
kubectl run nginx --image nginx --restart=Never --dry-run=client -o yaml >nginx-pod.yaml
kubectl run nginx --image nginx --dry-run=client -o yaml >nginx-deploy.yaml
kubectl create deploy nginx --image nginx
kubectl expose deploy nginx --port 80 --type NodePort
```

- **Resource Deletion**

```
kubectl delete -f manifest.yaml
kubectl delete deploy nginx
kubectl delete service nginx
```

- **Monitor resources**

```
kubectl describe pods/nginx-xxxxxx-xx
kubectl describe svc/nginx-xxxxxx-xx
kubectl logs pods/nginx-xxxxx-xx
kubectl logs -f pods/nginx-xxxxx-xx
```

- **Exec into deployments**

```
kubectl exec --stdin --tty nginx-xxxxx-xx -- /bin/bash
kubectl exec nginx -- ls /
kubectl exec -i -t nginx --container my-container -- /bin/bash
```

## Troubleshoot
You may get the following after some time:
```sh
E0228 13:56:05.869708   97475 memcache.go:265] couldn't get current server API group list: Get "https://cluster-endpoint:6443/api?timeout=32s": tls: failed to verify certificate: x509: certificate has expired or is not yet valid: current time 2025-02-28T13:56:05+10:00 is after 2025-02-25T06:15:06Z
```
The solution is to renew the certificates:
```sh
sudo kubeadm certs renew all
sudo kubeadm certs check-expiration
```