# [Prometheus](https://prometheus.io/docs/introduction/overview/)

## Resources
[Prometheus v2.40.7](https://github.com/prometheus/prometheus/releases/tag/v2.40.7)
[Techno Tim](https://github.com/techno-tim/launchpad/tree/master/kubernetes/kube-prometheus-stack)

### Requirememts
- K8s cluster
- persistent storage

### Installation
- Docker image
- Precompiled binaries
- Building from source
- helm

#### Helm

```
kubectl get storageclass
helm search prometheus
helm inspect values stable/prometheus > /prometheus-values.yaml
nano 
```

### Usage
1. **Ensure root user is created and logged in**

    To log into root: