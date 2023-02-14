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