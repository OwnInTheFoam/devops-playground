# Multiapp kubernetes

To test kubernetes deployment on local machine, use docker desktop and ensure `Enable kubernetes` is checked in the settings.

Check you can run `kubectl`
```
kubectl get nodes
```

If not, then delete `~/.kube` directory and reset the kubernetes cluster within docker desktop settings.
```
kubectl config get-contexts
kubectl config use-context docker-desktop
```

Note this deployment will use nginx ingress controller to route traffic.

## Resources
- [Video](https://www.youtube.com/watch?v=OVVGwc90guo&ab_channel=Codeching)

## Steps

1. Create client-deployment.yml

```
kubectl apply -f client-deployment.yml
kubectl get pods
kubectl logs -f client-deployment-xxxxxxx-xx
kubectl port-forward client-deployment-xxxxxxx-xx 30001:30001
curl localhost:30001
```

2. Create client-cluster-ip-service.yml

```
kubectl apply -f client-cluster-ip-service.yml
kubectl get service
kubectl port-forward svc/my-service 30001
```
Note the service should be running to the client port.

3. Create secret
```
kubectl create secret generic pgpassword --from-literal PGPASSWORD=12345test
kubectl get secrets
```

4. Create database-persistent-volume-claim.yml
```
kubectl apply -f database-persistent-volume-claim.yml
kubectl get pv,pvc
```

5. Create postgres-deployment.yml
```
kubectl apply -f postgres-deployment.yml
kubectl get pods
kubectl exec -it postgres-deployment-xxxxx-xx -- psql -U postgres
\l
\c postgres
\dt
\q
```

6. Create postgres-cluster-ip-service.yml
```
kubectl apply -f postgres-cluster-ip-service.yml
kubectl get services
```

7. Create server-deployment.yml
```
kubectl apply -f server-deployment.yml
kubectl get pods
kubectl port-forward server-deployment-xxxxxxx-xx 30002:30002
```

8. Create server-cluster-ip-service.yml
```
kubectl apply -f server-cluster-ip-service.yml
kubectl get services
kubectl port-forward svc/my-service 30002
```

9. Install [NGINX ingress controller](https://kubernetes.github.io/ingress-nginx/deploy/#quick-start)
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.4.0/deploy/static/provider/cloud/deploy.yaml
kubectl get all -n ingress-nginx
```

10. Create ingress-service.yml
Configure ingress service redirects https:// traffic to the nginx pod and the https://api to the server pod
```
kubectl apply -f ingress-service.yml
```

11. Test application
Navigate to `localhost` and nginx ingress controller will route the traffic to correct service.

12. Delete application
```
cd ../
kubectl delete -f manifests
```