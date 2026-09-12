Dev ops playground for tutorials, guides and exercises.

# Recommended install order from fresh machine
- [ssh](https://github.com/OwnInTheFoam/devops-playground/blob/master/security/ssh/README.md)
- [Linux setup](https://github.com/OwnInTheFoam/devops-playground/tree/master/tools/linux)
- [Wake on lan](https://github.com/OwnInTheFoam/devops-playground/tree/master/tools/wakeonlan)
- [Git](https://github.com/OwnInTheFoam/devops-playground/blob/master/tools/git/README.md)
- [yq](https://github.com/OwnInTheFoam/devops-playground/tree/master/tools/yq)
- [Kubernetes k8s](https://github.com/OwnInTheFoam/devops-playground/tree/master/kubernetes/distributions/k8s)
- [Kustomize](https://github.com/OwnInTheFoam/devops-playground/blob/master/tools/kustomize/README.md)
- [Flux](https://github.com/OwnInTheFoam/devops-playground/tree/master/kubernetes/management/fluxcd)
- [Helm](https://github.com/OwnInTheFoam/devops-playground/tree/master/tools/helm)
- [Kubeseal](https://github.com/OwnInTheFoam/devops-playground/tree/master/kubernetes/management/kubeseal)
- [MetalLB](https://github.com/OwnInTheFoam/devops-playground/tree/master/kubernetes/networking/metalLB)
- ~~[Ingress nginx](https://github.com/OwnInTheFoam/devops-playground/blob/master/kubernetes/networking/ingress-nginx/README.md)~~
- [Traefik](https://github.com/OwnInTheFoam/devops-playground/blob/master/kubernetes/networking/traefik/README.md)
- [Storage Common](https://github.com/OwnInTheFoam/devops-playground/tree/master/kubernetes/storage/common)
- [Cert manager](https://github.com/OwnInTheFoam/devops-playground/blob/master/kubernetes/networking/cert-manager/README.md)
- [Longhorn](https://github.com/OwnInTheFoam/devops-playground/tree/master/kubernetes/storage/longhorn)
- ~~[Dashboard](https://github.com/OwnInTheFoam/devops-playground/blob/master/kubernetes/management/dashboard/README.md)~~
- [Headlamp](https://github.com/OwnInTheFoam/devops-playground/blob/master/kubernetes/management/headlamp)
- [Kube prometheus stack](https://github.com/OwnInTheFoam/devops-playground/tree/master/kubernetes/monitoring/kube-prometheus-stack)
- [Loki + Promtail](https://github.com/OwnInTheFoam/devops-playground/tree/master/kubernetes/monitoring/loki)
- [Tempo](https://github.com/OwnInTheFoam/devops-playground/tree/master/kubernetes/monitoring/tempo)

# Extras
- [Tailscape]()
- ~~[Beyla](https://github.com/OwnInTheFoam/devops-playground/tree/master/kubernetes/monitoring/beyla)~~ removed: kernel panics on 7.0, see its README
- [Mailu](https://github.com/OwnInTheFoam/devops-playground/tree/master/containers/mailu)
- TODO Media server (photoprism, Piwigo, Immich)
- 

# Network Ports
- 30000 proxy
- 30001 longhorn
- 30002 dashboard
- 30003 grafana (superseded by ingress: grafana.<REDACTED>)
- 30004 prometheus
- 30005 alert manager

